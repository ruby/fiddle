# frozen_string_literal: true
require 'fiddle'
require 'fiddle/value'
require 'fiddle/pack'

module Fiddle
  # C struct shell
  class CStruct
    # accessor to Fiddle::CStructEntity
    def CStruct.entity_class
      CStructEntity
    end
  end

  # C union shell
  class CUnion
    # accessor to Fiddle::CUnionEntity
    def CUnion.entity_class
      CUnionEntity
    end
  end

  # Wrapper for arrays of structs within a struct
  class NestedStructArray < Array
    def []=(index, value)
      self[index].to_ptr.memcpy(value.to_ptr)
    end
  end

  # Used to construct C classes (CUnion, CStruct, etc)
  #
  # Fiddle::Importer#struct and Fiddle::Importer#union wrap this functionality in an
  # easy-to-use manner.
  module CStructBuilder
    # Construct a new class given a C:
    # * class +klass+ (CUnion, CStruct, or other that provide an
    #   #entity_class)
    # * +types+ (Fiddle::TYPE_INT, Fiddle::TYPE_SIZE_T, etc., see the C types
    #   constants)
    # * corresponding +members+
    #
    # Fiddle::Importer#struct and Fiddle::Importer#union wrap this functionality in an
    # easy-to-use manner.
    #
    # Example:
    #
    #   require 'fiddle/struct'
    #   require 'fiddle/cparser'
    #
    #   include Fiddle::CParser
    #
    #   types, members = parse_struct_signature(['int i','char c'])
    #
    #   MyStruct = Fiddle::CStructBuilder.create(Fiddle::CUnion, types, members)
    #
    #   obj = MyStruct.allocate
    #
    def create(klass, types, members)
      new_class = Class.new(klass){
        define_method(:initialize){|addr|
          @entity = klass.entity_class.new(addr, types)
          @entity.assign_names(members)
        }
        define_method(:to_ptr){ @entity }
        define_method(:to_i){ @entity.to_i }
        define_singleton_method(:types) { types }
        define_singleton_method(:members) { members }
        members.each{|name|
          if name.kind_of?(Array) # name is a nested struct
            next if method_defined?(name[0])
            name = name[0]
          end
          define_method(name){ @entity[name] }
          define_method(name + "="){|val| @entity[name] = val }
        }
      }
      size = klass.entity_class.size(types)
      new_class.module_eval(<<-EOS, __FILE__, __LINE__+1)
        def new_class.size()
          #{size}
        end
        def new_class.malloc()
          addr = Fiddle.malloc(#{size})
          new(addr)
        end
      EOS
      return new_class
    end
    module_function :create
  end

  # A C struct wrapper
  class CStructEntity < Fiddle::Pointer
    include PackInfo
    include ValueUtil

    # Allocates a C struct with the +types+ provided.
    #
    # When the instance is garbage collected, the C function +func+ is called.
    def CStructEntity.malloc(types, func = nil)
      addr = Fiddle.malloc(CStructEntity.size(types))
      CStructEntity.new(addr, types, func)
    end

    # Returns the offset for the packed sizes for the given +types+.
    #
    #   Fiddle::CStructEntity.size(
    #     [ Fiddle::TYPE_DOUBLE,
    #       Fiddle::TYPE_INT,
    #       Fiddle::TYPE_CHAR,
    #       Fiddle::TYPE_VOIDP ]) #=> 24
    def CStructEntity.size(types)
      offset = 0

      max_align = types.map { |type, count = 1|
        last_offset = offset

        if type.kind_of?(Array) # type is a nested array representing a nested struct
          align = CStructEntity.size(type)
          offset = PackInfo.align(last_offset, align) +
                  (align * (count || 1))
        else
          align = PackInfo::ALIGN_MAP[type]
          offset = PackInfo.align(last_offset, align) +
                   (PackInfo::SIZE_MAP[type] * count)
        end

        align
      }.max

      PackInfo.align(offset, max_align)
    end

    # Wraps the C pointer +addr+ as a C struct with the given +types+.
    #
    # When the instance is garbage collected, the C function +func+ is called.
    #
    # See also Fiddle::Pointer.new
    def initialize(addr, types, func = nil)
      @addr = addr
      set_ctypes(types)
      super(addr, @size, func)
    end

    # Set the names of the +members+ in this C struct
    def assign_names(members)
      @members = members.map { |member| member.kind_of?(Array) ? member[0] : member }

      @nested_structs = {}
      @ctypes.each_with_index do |ty, idx|
        if ty.kind_of?(Array) && ty[0].kind_of?(Array)
          member = members[idx]
          member = member[0] if member.kind_of?(Array)
          entity_class = CStructBuilder.create(CStruct, ty[0], members[idx][1])
          @nested_structs[member] ||= if ty[1]
            NestedStructArray.new(ty[1].times.map do |i|
              entity_class.new(@addr + @offset[idx] + i * CStructEntity.size(ty[0]))
            end)
          else
            entity_class.new(@addr + @offset[idx])
          end
        end
      end
    end

    # Calculates the offsets and sizes for the given +types+ in the struct.
    def set_ctypes(types)
      @ctypes = types
      @offset = []
      offset = 0

      max_align = types.map { |type, count = 1|
        orig_offset = offset
        if type.kind_of?(Array) # type is a nested array representing a nested struct
          align = CStructEntity.size(type)
          offset = PackInfo.align(orig_offset, align)
          @offset << offset
          offset += (align * (count || 1))
        else
          align = ALIGN_MAP[type]
          offset = PackInfo.align(orig_offset, align)
          @offset << offset
          offset += (SIZE_MAP[type] * (count || 1))
        end

        align
      }.max

      @size = PackInfo.align(offset, max_align)
    end

    # Fetch struct member +name+
    def [](name)
      idx = @members.index(name)
      if( idx.nil? )
        raise(ArgumentError, "no such member: #{name}")
      end
      ty = @ctypes[idx]
      if( ty.is_a?(Array) )
        if ty.first.kind_of?(Array)
          return @nested_structs[name]
        else
          r = super(@offset[idx], SIZE_MAP[ty[0]] * ty[1])
        end
      else
        r = super(@offset[idx], SIZE_MAP[ty.abs])
      end
      packer = Packer.new([ty])
      val = packer.unpack([r])
      case ty
      when Array
        case ty[0]
        when TYPE_VOIDP
          val = val.collect{|v| Pointer.new(v)}
        end
      when TYPE_VOIDP
        val = Pointer.new(val[0])
      else
        val = val[0]
      end
      if( ty.is_a?(Integer) && (ty < 0) )
        return unsigned_value(val, ty)
      elsif( ty.is_a?(Array) && (ty[0] < 0) )
        return val.collect{|v| unsigned_value(v,ty[0])}
      else
        return val
      end
    end

    # Set struct member +name+, to value +val+
    def []=(name, val)
      idx = @members.index(name)
      if( idx.nil? )
        raise(ArgumentError, "no such member: #{name}")
      end
      if @nested_structs[name]
        if @nested_structs[name].kind_of?(Array)
          val.size.times do |i|
            @nested_structs[name][i].to_ptr.memcpy(val[i].to_ptr)
          end
        else
          @nested_structs[name].to_ptr.memcpy(val.to_ptr)
        end
        return
      end
      ty  = @ctypes[idx]
      packer = Packer.new([ty])
      val = wrap_arg(val, ty, [])
      buff = packer.pack([val].flatten())
      super(@offset[idx], buff.size, buff)
      if( ty.is_a?(Integer) && (ty < 0) )
        return unsigned_value(val, ty)
      elsif( ty.is_a?(Array) && (ty[0] < 0) )
        return val.collect{|v| unsigned_value(v,ty[0])}
      else
        return val
      end
    end

    def to_s() # :nodoc:
      super(@size)
    end
  end

  # A C union wrapper
  class CUnionEntity < CStructEntity
    include PackInfo

    # Allocates a C union the +types+ provided.
    #
    # When the instance is garbage collected, the C function +func+ is called.
    def CUnionEntity.malloc(types, func=nil)
      addr = Fiddle.malloc(CUnionEntity.size(types))
      CUnionEntity.new(addr, types, func)
    end

    # Returns the size needed for the union with the given +types+.
    #
    #   Fiddle::CUnionEntity.size(
    #     [ Fiddle::TYPE_DOUBLE,
    #       Fiddle::TYPE_INT,
    #       Fiddle::TYPE_CHAR,
    #       Fiddle::TYPE_VOIDP ]) #=> 8
    def CUnionEntity.size(types)
      types.map { |type, count = 1|
        PackInfo::SIZE_MAP[type] * count
      }.max
    end

    # Calculate the necessary offset and for each union member with the given
    # +types+
    def set_ctypes(types)
      @ctypes = types
      @offset = Array.new(types.length, 0)
      @size   = self.class.size types
    end
  end
end

