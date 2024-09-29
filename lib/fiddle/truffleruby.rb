# frozen_string_literal: true
# truffleruby_primitives: true

# Copyright (c) 2019, 2024 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 2.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

module Truffle::FiddleBackend

  SIZEOF_CHAR   = Primitive.pointer_find_type_size(:char)
  SIZEOF_SHORT  = Primitive.pointer_find_type_size(:short)
  SIZEOF_INT    = Primitive.pointer_find_type_size(:int)
  SIZEOF_LONG   = Primitive.pointer_find_type_size(:long)

  CHAR_NFI_TYPE  = "SINT#{SIZEOF_CHAR * 8}"
  UCHAR_NFI_TYPE  = "UINT#{SIZEOF_CHAR * 8}"
  SHORT_NFI_TYPE  = "SINT#{SIZEOF_SHORT * 8}"
  USHORT_NFI_TYPE  = "UINT#{SIZEOF_SHORT * 8}"
  INT_NFI_TYPE  = "SINT#{SIZEOF_INT * 8}"
  UINT_NFI_TYPE  = "UINT#{SIZEOF_INT * 8}"
  LONG_NFI_TYPE = "SINT#{SIZEOF_LONG * 8}"
  ULONG_NFI_TYPE = "UINT#{SIZEOF_LONG * 8}"

  SIZE_T_TYPEDEF = Truffle::Config.lookup('platform.typedef.size_t')

  case SIZE_T_TYPEDEF
  when 'ulong'
    SIGNEDNESS_OF_SIZE_T = 1
  else
    raise NotImplementedError, "#{SIZE_T_TYPEDEF} not recognised"
  end

  def self.type_to_nfi(type)
    if type.is_a?(Symbol)
      type = Fiddle::Types.const_get(type.to_s.upcase)
    end
    if !type.is_a?(Integer) and type.respond_to?(:to_int)
      type = type.to_int
    end
    case type
    when Fiddle::TYPE_VOID
      'VOID'
    when Fiddle::TYPE_VOIDP, Fiddle::TYPE_CONST_STRING
      'POINTER'
    when Fiddle::TYPE_CHAR
      CHAR_NFI_TYPE
    when -Fiddle::TYPE_CHAR
      UCHAR_NFI_TYPE
    when Fiddle::TYPE_SHORT
      SHORT_NFI_TYPE
    when -Fiddle::TYPE_SHORT
      USHORT_NFI_TYPE
    when Fiddle::TYPE_INT
      INT_NFI_TYPE
    when -Fiddle::TYPE_INT
      UINT_NFI_TYPE
    when Fiddle::TYPE_LONG, Fiddle::TYPE_LONG_LONG
      LONG_NFI_TYPE
    when -Fiddle::TYPE_LONG, -Fiddle::TYPE_LONG_LONG
      ULONG_NFI_TYPE
    when Fiddle::TYPE_FLOAT
      'FLOAT'
    when Fiddle::TYPE_DOUBLE
      'DOUBLE'
    when Fiddle::TYPE_BOOL
      'BOOL'
    else
      raise TypeError, "#{type} not implemented"
    end
  end

  def self.type_from_config(type)
    case type
    when 'long'
      Fiddle::Types::LONG
    else
      raise NotImplementedError, "integer #{type} not known"
    end
  end

  def self.convert_ruby_to_native(type, val)
    case type
    when Fiddle::TYPE_CHAR
      Integer(val)
    when Fiddle::TYPE_VOIDP
      get_pointer_value(val)
    when Fiddle::TYPE_INT
      Integer(val)
    when -Fiddle::TYPE_LONG
      Integer(val)
    when Fiddle::TYPE_FLOAT, Fiddle::TYPE_DOUBLE
      Float(val)
    else
      raise NotImplementedError, "#{val.inspect} to type #{type}"
    end
  end

  def self.get_pointer_value(val)
    if Primitive.is_a?(val, String)
      # NOTE: Fiddle::TYPE_CONST_STRING wouldn't need inplace, but not defined yet by this file
      Truffle::CExt.string_to_ffi_pointer_inplace(val)
    elsif Primitive.is_a?(val, Fiddle::Pointer)
      val.to_i
    elsif val.respond_to?(:to_ptr)
      val.to_ptr.to_i
    elsif Primitive.nil?(val)
      0
    elsif Primitive.is_a?(val, Integer)
      val
    else
      raise NotImplementedError, "#{val.inspect} to pointer"
    end
  end

  def self.convert_native_to_ruby(type, val)
    case type
    when Fiddle::TYPE_VOID
      nil
    when Fiddle::TYPE_VOIDP
      Fiddle::Pointer.new(Truffle::Interop.as_pointer(val))
    when Fiddle::TYPE_INT,
         Fiddle::TYPE_ULONG,
         Fiddle::TYPE_FLOAT,
         Fiddle::TYPE_DOUBLE
      val
    else
      raise NotImplementedError, "#{val.inspect} from type #{type}"
    end
  end

  RTLD_NEXT    = Truffle::Config['platform.dlopen.RTLD_NEXT']
  RTLD_DEFAULT = Truffle::Config['platform.dlopen.RTLD_DEFAULT']

end

module Fiddle

  class Error < StandardError
  end
  class DLError < Error
  end
  class ClearedReferenceError < Error
  end

  module Types
    VOID         = 0
    VOIDP        = 1
    CHAR         = 2
    SHORT        = 3
    INT          = 4
    LONG         = 5
    LONG_LONG    = 6
    FLOAT        = 7
    DOUBLE       = 8
    VARIADIC     = 9
    CONST_STRING = 10
    BOOL         = 11

    UCHAR = -CHAR
    USHORT = -SHORT
    UINT = -INT
    ULONG = -LONG
    ULONG_LONG = -LONG_LONG

    INT8_T  = CHAR
    INT16_T = SHORT
    INT32_T = INT
    INT64_T = LONG

    UINT8_T  = -INT8_T
    UINT16_T = -INT16_T
    UINT32_T = -INT32_T
    UINT64_T = -INT64_T

    SSIZE_T      = Truffle::FiddleBackend.type_from_config(Truffle::Config.lookup('platform.typedef.ssize_t'))
    SIZE_T       = -1 * Truffle::FiddleBackend::SIGNEDNESS_OF_SIZE_T * SSIZE_T
    PTRDIFF_T    = Truffle::FiddleBackend.type_from_config(Truffle::Config.lookup('platform.typedef.ptrdiff_t'))
    INTPTR_T     = Truffle::FiddleBackend.type_from_config(Truffle::Config.lookup('platform.typedef.intptr_t'))
    UINTPTR_T    = -INTPTR_T
  end

  SIZEOF_VOIDP      = Primitive.pointer_find_type_size(:pointer)
  SIZEOF_CHAR       = Primitive.pointer_find_type_size(:char)
  SIZEOF_SHORT      = Primitive.pointer_find_type_size(:short)
  SIZEOF_INT        = Truffle::FiddleBackend::SIZEOF_INT
  SIZEOF_LONG       = Truffle::FiddleBackend::SIZEOF_LONG
  SIZEOF_LONG_LONG  = Primitive.pointer_find_type_size(:long_long)
  SIZEOF_FLOAT      = Primitive.pointer_find_type_size(:float)
  SIZEOF_DOUBLE     = Primitive.pointer_find_type_size(:double)
  SIZEOF_BOOL       = SIZEOF_CHAR # TODO: Use sizeof(bool)
  SIZEOF_CONST_STRING = SIZEOF_VOIDP

  SIZEOF_UCHAR = SIZEOF_CHAR
  SIZEOF_USHORT = SIZEOF_SHORT
  SIZEOF_UINT = SIZEOF_INT
  SIZEOF_ULONG = SIZEOF_LONG
  SIZEOF_ULONG_LONG = SIZEOF_LONG_LONG

  SIZEOF_INT8_T  = 1
  SIZEOF_INT16_T = 2
  SIZEOF_INT32_T = 4
  SIZEOF_INT64_T = 8

  SIZEOF_UINT8_T  = 1
  SIZEOF_UINT16_T = 2
  SIZEOF_UINT32_T = 4
  SIZEOF_UINT64_T = 8

  SIZEOF_SSIZE_T    = Primitive.pointer_find_type_size(:ssize_t)
  SIZEOF_SIZE_T     = Primitive.pointer_find_type_size(:size_t)
  SIZEOF_PTRDIFF_T  = Primitive.pointer_find_type_size(:ptrdiff_t)
  SIZEOF_INTPTR_T   = Primitive.pointer_find_type_size(:intptr_t)
  SIZEOF_UINTPTR_T  = Primitive.pointer_find_type_size(:uintptr_t)

  # Alignment assumed to be the same as size

  ALIGN_VOIDP       = SIZEOF_VOIDP
  ALIGN_CHAR        = SIZEOF_CHAR
  ALIGN_SHORT       = SIZEOF_SHORT
  ALIGN_INT         = SIZEOF_INT
  ALIGN_LONG        = SIZEOF_LONG
  ALIGN_LONG_LONG   = SIZEOF_LONG_LONG
  ALIGN_FLOAT       = SIZEOF_FLOAT
  ALIGN_DOUBLE      = SIZEOF_DOUBLE
  ALIGN_BOOL        = SIZEOF_BOOL

  ALIGN_INT8_T      = SIZEOF_INT8_T
  ALIGN_INT16_T     = SIZEOF_INT16_T
  ALIGN_INT32_T     = SIZEOF_INT32_T
  ALIGN_INT64_T     = SIZEOF_INT64_T

  ALIGN_SIZE_T      = SIZEOF_SIZE_T
  ALIGN_SSIZE_T     = SIZEOF_SSIZE_T
  ALIGN_PTRDIFF_T   = SIZEOF_PTRDIFF_T
  ALIGN_INTPTR_T    = SIZEOF_INTPTR_T
  ALIGN_UINTPTR_T   = SIZEOF_UINTPTR_T

  WINDOWS             = Truffle::Platform.windows?
  BUILD_RUBY_PLATFORM = RUBY_PLATFORM

  def self.dlwrap(*args)
    raise NotImplementedError
  end

  def self.dlunwrap(*args)
    raise NotImplementedError
  end

  def self.malloc(size)
    Primitive.pointer_raw_malloc size
  end

  def self.realloc(address, size)
    Primitive.pointer_raw_realloc address, size
  end

  def self.free(address)
    if !address.is_a?(Integer) and address.respond_to?(:to_int)
      address = address.to_int
    end
    Primitive.pointer_raw_free address
  end

  class Function

    DEFAULT = :default_abi

    def initialize(ptr, args, ret_type, abi = DEFAULT, name: nil, need_gvl: false)
      raise TypeError.new "invalid argument types" unless args.is_a?(Array)

      @ptr = ptr
      @arg_types = args
      @ret_type = ret_type
      @abi = abi
      @name = name
      @need_gvl = need_gvl
      args = args.map { |arg| Truffle::FiddleBackend.type_to_nfi(arg) }
      ret_type = Truffle::FiddleBackend.type_to_nfi(ret_type)
      signature = "(#{args.join(',')}):#{ret_type}"

      if Primitive.is_a?(ptr, Closure)
        @function = ptr.method(:call)
      else
        ptr = Truffle::FFI::Pointer.new(ptr)
        @function = Primitive.interop_eval_nfi(signature).bind(ptr)
      end
    end

    def call(*args)
      args = args.zip(@arg_types).map { |arg, type| Truffle::FiddleBackend.convert_ruby_to_native(type, arg) }
      ret = @function.call(*args)
      Truffle::FiddleBackend.convert_native_to_ruby(@ret_type, ret)
    end

  end

  class Closure

    def initialize(ret, args, abi = Function::DEFAULT)
      # does nothing - 'not implemented' when used
    end

    def to_i(*args)
      raise NotImplementedError
    end

  end

  class Handle

    def self.sym(name)
      DEFAULT.sym(name)
    end

    def self.[](name)
      sym(name)
    end

    def self.sym_defined?(name)
      DEFAULT.sym_defined?(name)
    end

    RTLD_LAZY    = Truffle::Config['platform.dlopen.RTLD_LAZY']
    RTLD_NOW     = Truffle::Config['platform.dlopen.RTLD_NOW']
    RTLD_GLOBAL  = Truffle::Config['platform.dlopen.RTLD_GLOBAL']

    def initialize(library = nil, flags = RTLD_LAZY | RTLD_GLOBAL)
      raise DLError, 'unsupported dlopen flags' if flags != (RTLD_LAZY | RTLD_GLOBAL)

      if library == Truffle::FiddleBackend::RTLD_NEXT
        @handle = :rtld_next
      else
        library = nil if library == Truffle::FiddleBackend::RTLD_DEFAULT
        begin
          @handle = Primitive.interop_eval_nfi(library ? "load '#{library}'" : 'default')
        rescue Polyglot::ForeignException => e
          raise DLError, "#{e.message}"
        end
      end
    end

    def to_i(*args)
      raise NotImplementedError
    end

    def close(*args)
      raise NotImplementedError
    end

    def sym(name)
      if :rtld_next == @handle
        raise DLError, 'RTLD_NEXT is not supported'
      else
        begin
          sym = @handle[name]
        rescue NameError
          raise DLError, "unknown symbol \"#{name}\""
        else
          Truffle::Interop.as_pointer(sym)
        end
      end
    end

    alias_method :[], :sym

    def sym_defined?(name)
      if :rtld_next == @handle
        raise DLError, 'RTLD_NEXT is not supported'
      else
        begin
          @handle[name]
        rescue NameError
          false
        else
          true
        end
      end
    end

    def disable_close(*args)
      raise NotImplementedError
    end

    def enable_close(*args)
      raise NotImplementedError
    end

    def close_enabled?(*args)
      raise NotImplementedError
    end

    DEFAULT = Handle.new(Truffle::FiddleBackend::RTLD_DEFAULT)
    NEXT    = Handle.new(Truffle::FiddleBackend::RTLD_NEXT)

  end

  class Pointer

    def self.malloc(size, free=nil)
      if block_given? and free.nil?
        message = "a free function must be supplied to #{self}.malloc " +
                  "when it is called with a block"
        raise ArgumentError, message
      end

      pointer = new(Fiddle.malloc(size), size, free)
      if block_given?
        begin
          yield(pointer)
        ensure
          pointer.call_free
        end
      else
        pointer
      end
    end

    def self.to_ptr(val)
      if Primitive.is_a?(val, IO)
        raise NotImplementedError
      elsif Primitive.is_a?(val, String)
        ptr = Pointer.new(Primitive.string_pointer_to_native(val), val.bytesize)
      elsif val.respond_to?(:to_ptr)
        ptr = val.to_ptr
        case ptr
        when Pointer
          ptr
        else
          raise DLError.new("to_ptr should return a Fiddle::Pointer object, was #{ptr.class}")
        end
      else
        ptr = Pointer.new(Integer(val))
      end
      ptr
    end

    class << self
      alias_method :[], :to_ptr
    end

    def initialize(address, size = 0, free = nil)
      @size = size
      @free = free
      if address.is_a?(Pointer)
        @pointer = Truffle::FFI::Pointer.new(address.to_i)
      else
        @pointer = Truffle::FFI::Pointer.new(address)
      end
      @freed = false
    end

    def free=(free)
      @free = free
    end

    def free
      @free
    end

    def call_free
      return if @free.nil?
      return if @freed
      if @free == RUBY_FREE
        Fiddle.free(@pointer.address)
      else
        @free.call(@pointer.address)
      end
      @freed = true
    end

    def freed?
      @freed
    end

    def to_i
      @pointer.address
    end
    alias_method :to_int, :to_i

    def to_value(*args)
      raise NotImplementedError
    end

    def ptr
      Pointer.new(@pointer.read_pointer)
    end

    def +@
      ptr
    end

    def ref
      reference = Pointer.malloc(SIZEOF_VOIDP, RUBY_FREE)
      reference.instance_variable_get(:@pointer).put_pointer(0, to_i)
      reference
    end

    def -@
      ref
    end

    def null?
      @pointer.null?
    end

    def to_s(len=nil)
      if len
        @pointer.get_string(0, len)
      else
        @pointer.get_string(0)
      end
    end

    def to_str(len=nil)
      if len
        @pointer.get_bytes(0, len)
      else
        @pointer.get_bytes(0, @size)
      end
    end

    def inspect
      "#<#{self.class.name} ptr=#{to_i.to_s(16)} size=#{@size} free=#{@free.inspect}>"
    end

    def <=>(other)
      return nil unless other.is_a?(Pointer)
      diff = to_i - other.to_i
      return 0 if diff == 0
      diff > 0 ? 1 : -1
    end

    def ==(other)
      eql?(other)
    end

    def eql?(other)
      return unless other.is_a?(Pointer)
      to_i == other.to_i
    end

    def +(delta)
      self.class.new(to_i + delta, @size - delta)
    end

    def -(delta)
      self.class.new(to_i - delta, @size + delta)
    end

    def [](start, length = nil)
      if length
        (@pointer + start).read_string(length)
      else
        (@pointer + start).read_int8
      end
    rescue Truffle::FFI::NullPointerError
      raise DLError.new("NULL pointer access")
    end

    def []=(*args, value)
      if args.size == 2
        if value.is_a?(Integer)
          value = self.class.new(value)
        end
        if value.is_a?(Pointer)
          value = value.to_str(args[1])
        end

        @pointer.put_bytes(args[0], value, 0, args[1])
      elsif args.size == 1
        if value.is_a?(Pointer)
          value = value.to_str(args[0] + 1)
        else
          value = value.chr
        end

        @pointer.put_bytes(args[0], value, 0, 1)
      end
    rescue Truffle::FFI::NullPointerError
      raise DLError.new("NULL pointer access")
    end

    def size
      @size
    end

    def size=(size)
      @size = size
    end

    NULL = Pointer.new(0)

  end

  class Pinned
    def initialize(object)
      @object = object
    end

    def ref
      if @object.nil?
        raise ClearedReferenceError, "`ref` called on a cleared object"
      end
      @object
    end

    def clear
      @object = nil
    end

    def cleared?
      @object.nil?
    end
  end

  RUBY_FREE = Handle.sym('free')
  NULL = Pointer.new(0)

end
