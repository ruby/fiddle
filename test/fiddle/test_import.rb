# coding: US-ASCII
# frozen_string_literal: true
begin
  require_relative 'helper'
  require 'fiddle/import'
rescue LoadError
end

module Fiddle
  module LIBC
    extend Importer
    dlload LIBC_SO, LIBM_SO

    typealias 'string', 'char*'
    typealias 'FILE*', 'void*'

    extern "void *strcpy(char*, char*)"
    extern "int isdigit(int)"
    extern "double atof(string)"
    extern "unsigned long strtoul(char*, char **, int)"
    extern "int qsort(void*, unsigned long, unsigned long, void*)"
    extern "int fprintf(FILE*, char*)" rescue nil
    extern "int gettimeofday(timeval*, timezone*)" rescue nil

    BoundQsortCallback = bind("void *bound_qsort_callback(void*, void*)"){|ptr1,ptr2| ptr1[0] <=> ptr2[0]}
    Timeval = struct [
      "long tv_sec",
      "long tv_usec",
    ]
    Timezone = struct [
      "int tz_minuteswest",
      "int tz_dsttime",
    ]
    MyStruct = struct [
      "short num[5]",
      "char c",
      "unsigned char buff[7]",
    ]

    CallCallback = bind("void call_callback(void*, void*)"){ | ptr1, ptr2|
      f = Function.new(ptr1.to_i, [TYPE_VOIDP], TYPE_VOID)
      f.call(ptr2)
    }
  end

  class TestImport < TestCase
    def test_ensure_call_dlload
      err = assert_raise(RuntimeError) do
        Class.new do
          extend Importer
          extern "void *strcpy(char*, char*)"
        end
      end
      assert_match(/call dlload before/, err.message)
    end

    def test_struct_memory_access()
      # check memory operations performed directly on struct
      Fiddle::Importer.struct(['int id']).malloc(Fiddle::RUBY_FREE) do |my_struct|
        my_struct['id'] = 1
        assert_equal 1, my_struct.id

        my_struct[0, Fiddle::SIZEOF_INT] = "\x01".b * Fiddle::SIZEOF_INT
        assert_equal 0x01010101, my_struct.id

        my_struct.id = 0
        assert_equal "\x00".b * Fiddle::SIZEOF_INT, my_struct[0, Fiddle::SIZEOF_INT]
      end
    end

    def test_struct_ptr_array_subscript_multiarg()
      # check memory operations performed on struct#to_ptr
      Fiddle::Importer.struct([ 'int x' ]).malloc(Fiddle::RUBY_FREE) do |struct|
        ptr = struct.to_ptr

        struct.x = 0x02020202
        assert_equal("\x02".b * Fiddle::SIZEOF_INT, ptr[0, Fiddle::SIZEOF_INT])

        ptr[0, Fiddle::SIZEOF_INT] = "\x01".b * Fiddle::SIZEOF_INT
        assert_equal 0x01010101, struct.x
      end
    end

    def test_struct_ptr_array_subscript_multiarg()
      # check memory operations performed on struct#to_ptr
      struct = Fiddle::Importer.struct([ 'int x' ]).malloc
      ptr = struct.to_ptr

      struct.x = 0x02020202
      assert_equal("\x02".b * Fiddle::SIZEOF_INT, ptr[0, Fiddle::SIZEOF_INT])

      ptr[0, Fiddle::SIZEOF_INT] = "\x01".b * Fiddle::SIZEOF_INT
      assert_equal 0x01010101, struct.x
    end

    def test_malloc()
      LIBC::Timeval.malloc(Fiddle::RUBY_FREE) do |s1|
        LIBC::Timeval.malloc(Fiddle::RUBY_FREE) do |s2|
          refute_equal(s1.to_ptr.to_i, s2.to_ptr.to_i)
        end
      end
    end

    def test_sizeof()
      assert_equal(SIZEOF_VOIDP, LIBC.sizeof("FILE*"))
      assert_equal(LIBC::MyStruct.size(), LIBC.sizeof(LIBC::MyStruct))
      LIBC::MyStruct.malloc(Fiddle::RUBY_FREE) do |my_struct|
        assert_equal(LIBC::MyStruct.size(), LIBC.sizeof(my_struct))
      end
      assert_equal(SIZEOF_LONG_LONG, LIBC.sizeof("long long")) if defined?(SIZEOF_LONG_LONG)
    end

    Fiddle.constants.grep(/\ATYPE_(?!VOID|VARIADIC\z)(.*)/) do
      type = $&
      const_type_name = $1
      size = Fiddle.const_get("SIZEOF_#{const_type_name}")
      if const_type_name == "CONST_STRING"
        name = "const_string"
        type_name = "const char*"
      else
        name = $1.sub(/P\z/,"*").gsub(/_(?!T\z)/, " ").downcase
        type_name = name
      end
      define_method("test_sizeof_#{name}") do
        assert_equal(size, Fiddle::Importer.sizeof(type_name), type)
      end
    end

    def test_unsigned_result()
      d = (2 ** 31) + 1

      r = LIBC.strtoul(d.to_s, 0, 0)
      assert_equal(d, r)
    end

    def test_io()
      if( RUBY_PLATFORM != BUILD_RUBY_PLATFORM ) || !defined?(LIBC.fprintf)
        return
      end
      io_in,io_out = IO.pipe()
      LIBC.fprintf(io_out, "hello")
      io_out.flush()
      io_out.close()
      str = io_in.read()
      io_in.close()
      assert_equal("hello", str)
    end

    def test_value()
      i = LIBC.value('int', 2)
      assert_equal(2, i.value)

      d = LIBC.value('double', 2.0)
      assert_equal(2.0, d.value)

      ary = LIBC.value('int[3]', [0,1,2])
      assert_equal([0,1,2], ary.value)
    end

    def test_struct_array_assignment()
      Fiddle::Importer.struct(["unsigned int stages[3]"]).malloc(Fiddle::RUBY_FREE) do |instance|
        instance.stages[0] = 1024
        instance.stages[1] = 10
        instance.stages[2] = 100
        assert_equal 1024, instance.stages[0]
        assert_equal 10, instance.stages[1]
        assert_equal 100, instance.stages[2]
        assert_equal [1024, 10, 100].pack(Fiddle::PackInfo::PACK_MAP[-Fiddle::TYPE_INT] * 3),
                    instance.to_ptr[0, 3 * Fiddle::SIZEOF_INT]
        assert_raise(IndexError) { instance.stages[-1] = 5 }
        assert_raise(IndexError) { instance.stages[3] = 5 }
      end
    end

    def test_struct_array_subscript_multiarg()
      Fiddle::Importer.struct([ 'int x' ]).malloc do |struct|
        assert_equal("\x00".b * Fiddle::SIZEOF_INT, struct.to_ptr[0, Fiddle::SIZEOF_INT])

        struct.to_ptr[0, Fiddle::SIZEOF_INT] = "\x01".b * Fiddle::SIZEOF_INT
        assert_equal 16843009, struct.x
      end
    end

    def test_struct()
      LIBC::MyStruct.malloc(Fiddle::RUBY_FREE) do |s|
        s.num = [0,1,2,3,4]
        s.c = ?a.ord
        s.buff = "012345\377"
        assert_equal([0,1,2,3,4], s.num)
        assert_equal(?a.ord, s.c)
        assert_equal([?0.ord,?1.ord,?2.ord,?3.ord,?4.ord,?5.ord,?\377.ord], s.buff)
      end
    end

    def test_gettimeofday()
      if( defined?(LIBC.gettimeofday) )
        LIBC::Timeval.malloc(Fiddle::RUBY_FREE) do |timeval|
          LIBC::Timezone.malloc(Fiddle::RUBY_FREE) do |timezone|
            LIBC.gettimeofday(timeval, timezone)
          end
          cur = Time.now()
          assert(cur.to_i - 2 <= timeval.tv_sec && timeval.tv_sec <= cur.to_i)
        end
      end
    end

    def test_strcpy()
      buff = +"000"
      str = LIBC.strcpy(buff, "123")
      assert_equal("123", buff)
      assert_equal("123", str.to_s)
    end

    def test_isdigit
      r1 = LIBC.isdigit(?1.ord)
      r2 = LIBC.isdigit(?2.ord)
      rr = LIBC.isdigit(?r.ord)
      assert_operator(r1, :>, 0)
      assert_operator(r2, :>, 0)
      assert_equal(0, rr)
    end

    def test_atof
      r = LIBC.atof("12.34")
      assert_includes(12.00..13.00, r)
    end

    def test_no_message_with_debug
      # disable all Ruby environment variables
      orig_RUBYOPT, ENV['RUBYOPT'] = ENV['RUBYOPT'], nil
      orig_RUBYLIB, ENV['RUBYLIB'] = ENV['RUBYLIB'], nil

      # load development fiddle instead of bundled one
      libdir = File.expand_path('../../../lib', __FILE__)
      ENV['RUBYLIB'] = libdir if File.file?(File.join(libdir, "fiddle/import.rb"))

      assert_in_out_err(%w[--debug --disable=gems -rfiddle/import], 'p Fiddle::Importer', ['Fiddle::Importer'])
    ensure
      ENV['RUBYLIB'] = orig_RUBYLIB
      ENV['RUBYOPT'] = orig_RUBYOPT
    end
  end
end if defined?(Fiddle)
