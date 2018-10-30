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
    StructNestedStruct = struct [
      {
        "vertices[2]" => {
          position: [ "float x", "float y", "float z" ],
          texcoord: [ "float u", "float v" ]
        },
        object:  [ "int id" ]
      },
      "int id"
    ]
    UnionNestedStruct = union [
      {
        keyboard: [
          'unsigned int state',
          'char key'
        ],
        mouse: [
          'unsigned int button',
          'unsigned short x',
          'unsigned short y'
        ]
      }
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

    def test_struct_memory_access
      my_struct = Fiddle::Importer.struct(['int id']).malloc
      my_struct['id'] = 1
      my_struct[0, Fiddle::SIZEOF_INT] = "\x01".b * Fiddle::SIZEOF_INT
      refute_equal 0, my_struct.id

      my_struct.id = 0
      assert_equal "\x00".b * Fiddle::SIZEOF_INT, my_struct[0, Fiddle::SIZEOF_INT]
    end

    def test_malloc()
      s1 = LIBC::Timeval.malloc()
      s2 = LIBC::Timeval.malloc()
      refute_equal(s1.to_ptr.to_i, s2.to_ptr.to_i)
    end

    def test_sizeof()
      assert_equal(SIZEOF_VOIDP, LIBC.sizeof("FILE*"))
      assert_equal(LIBC::MyStruct.size(), LIBC.sizeof(LIBC::MyStruct))
      assert_equal(LIBC::MyStruct.size(), LIBC.sizeof(LIBC::MyStruct.malloc()))
      assert_equal(SIZEOF_LONG_LONG, LIBC.sizeof("long long")) if defined?(SIZEOF_LONG_LONG)
      assert_equal(LIBC::StructNestedStruct.size(), LIBC.sizeof(LIBC::StructNestedStruct))
    end

    Fiddle.constants.grep(/\ATYPE_(?!VOID\z)(.*)/) do
      type = $&
      size = Fiddle.const_get("SIZEOF_#{$1}")
      name = $1.sub(/P\z/,"*").gsub(/_(?!T\z)/, " ").downcase
      define_method("test_sizeof_#{name}") do
        assert_equal(size, Fiddle::Importer.sizeof(name), type)
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

    def test_struct_array_subscript_multiarg()
      struct = Fiddle::Importer.struct([ 'int x' ]).malloc
      assert_equal("\x00".b * Fiddle::SIZEOF_INT, struct.to_ptr[0, Fiddle::SIZEOF_INT])

      struct.to_ptr[0, Fiddle::SIZEOF_INT] = "\x01".b * Fiddle::SIZEOF_INT
      assert_equal 16843009, struct.x
    end

    def test_nested_struct_reusing_other_structs()
      position_struct = Fiddle::Importer.struct([ 'float x', 'float y', 'float z' ])
      texcoord_struct = Fiddle::Importer.struct([ 'float u', 'float v' ])
      vertex_struct   = Fiddle::Importer.struct(position: position_struct, texcoord: texcoord_struct)
      mesh_struct     = Fiddle::Importer.struct([{"vertices[2]" => vertex_struct, object: [ "int id" ]}, "int id"])
      assert_equal LIBC::StructNestedStruct.size, mesh_struct.size


      keyboard_event_struct = Fiddle::Importer.struct([ 'unsigned int state', 'char key' ])
      mouse_event_struct    = Fiddle::Importer.struct([ 'unsigned int button', 'unsigned short x', 'unsigned short y' ])
      event_union           = Fiddle::Importer.union([{ keboard: keyboard_event_struct, mouse: mouse_event_struct}])
      assert_equal LIBC::UnionNestedStruct.size, event_union.size
    end

    def test_struct_nested_struct_members()
      s = LIBC::StructNestedStruct.malloc
      s.vertices[0].position.x = 1
      s.vertices[0].position.y = 2
      s.vertices[0].position.z = 3
      s.vertices[0].texcoord.u = 4
      s.vertices[0].texcoord.v = 5
      s.vertices[1].position.x = 6
      s.vertices[1].position.y = 7
      s.vertices[1].position.z = 8
      s.vertices[1].texcoord.u = 9
      s.vertices[1].texcoord.v = 10
      s.object.id              = 100
      s.id                     = 101
      assert_equal(1,   s.vertices[0].position.x)
      assert_equal(2,   s.vertices[0].position.y)
      assert_equal(3,   s.vertices[0].position.z)
      assert_equal(4,   s.vertices[0].texcoord.u)
      assert_equal(5,   s.vertices[0].texcoord.v)
      assert_equal(6,   s.vertices[1].position.x)
      assert_equal(7,   s.vertices[1].position.y)
      assert_equal(8,   s.vertices[1].position.z)
      assert_equal(9,   s.vertices[1].texcoord.u)
      assert_equal(10,  s.vertices[1].texcoord.v)
      assert_equal(100, s.object.id)
      assert_equal(101, s.id)
    end

    def test_union_nested_struct_members()
      s = LIBC::UnionNestedStruct.malloc
      s.keyboard.state = 100
      s.keyboard.key   = 101
      assert_equal(100, s.mouse.button)
      refute_equal(  0, s.mouse.x)
    end

    def test_struct_nested_struct_replace_array_element()
      s = LIBC::StructNestedStruct.malloc
      s.vertices[0].position.x = 5

      vertex_struct = Fiddle::Importer.struct [{
        position: [ "float x", "float y", "float z" ],
        texcoord: [ "float u", "float v" ]
      }]
      vertex = vertex_struct.malloc
      vertex.position.x = 100
      s.vertices[0] = vertex

      # make sure element was copied by value, but things like memory address
      # should not be changed
      assert_equal(100,              s.vertices[0].position.x)
      refute_equal(vertex.object_id, s.vertices[0].object_id)
      refute_equal(vertex.to_ptr,    s.vertices[0].to_ptr)
    end

    def test_struct_nested_struct_replace_entire_array()
      s = LIBC::StructNestedStruct.malloc
      vertex_struct = Fiddle::Importer.struct [{
        position: [ "float x", "float y", "float z" ],
        texcoord: [ "float u", "float v" ]
      }]

      different_struct_same_size = Fiddle::Importer.struct [{
        a: [ 'float i', 'float j', 'float k' ],
        b: [ 'float l', 'float m' ]
      }]

      same = [vertex_struct.malloc, vertex_struct.malloc]
      same[0].position.x = 1; same[1].position.x = 6
      same[0].position.y = 2; same[1].position.y = 7
      same[0].position.z = 3; same[1].position.z = 8
      same[0].texcoord.u = 4; same[1].texcoord.u = 9
      same[0].texcoord.v = 5; same[1].texcoord.v = 10
      s.vertices = same
      assert_equal(1, s.vertices[0].position.x); assert_equal(6,  s.vertices[1].position.x)
      assert_equal(2, s.vertices[0].position.y); assert_equal(7,  s.vertices[1].position.y)
      assert_equal(3, s.vertices[0].position.z); assert_equal(8,  s.vertices[1].position.z)
      assert_equal(4, s.vertices[0].texcoord.u); assert_equal(9,  s.vertices[1].texcoord.u)
      assert_equal(5, s.vertices[0].texcoord.v); assert_equal(10, s.vertices[1].texcoord.v)

      different = [different_struct_same_size.malloc, different_struct_same_size.malloc]
      different[0].a.i = 11; different[1].a.i = 16
      different[0].a.j = 12; different[1].a.j = 17
      different[0].a.k = 13; different[1].a.k = 18
      different[0].b.l = 14; different[1].b.l = 19
      different[0].b.m = 15; different[1].b.m = 20
      s.vertices = different
      assert_equal(11, s.vertices[0].position.x); assert_equal(16, s.vertices[1].position.x)
      assert_equal(12, s.vertices[0].position.y); assert_equal(17, s.vertices[1].position.y)
      assert_equal(13, s.vertices[0].position.z); assert_equal(18, s.vertices[1].position.z)
      assert_equal(14, s.vertices[0].texcoord.u); assert_equal(19, s.vertices[1].texcoord.u)
      assert_equal(15, s.vertices[0].texcoord.v); assert_equal(20, s.vertices[1].texcoord.v)
    end

    def test_struct()
      s = LIBC::MyStruct.malloc()
      s.num = [0,1,2,3,4]
      s.c = ?a.ord
      s.buff = "012345\377"
      assert_equal([0,1,2,3,4], s.num)
      assert_equal(?a.ord, s.c)
      assert_equal([?0.ord,?1.ord,?2.ord,?3.ord,?4.ord,?5.ord,?\377.ord], s.buff)
    end

    def test_gettimeofday()
      if( defined?(LIBC.gettimeofday) )
        timeval = LIBC::Timeval.malloc()
        timezone = LIBC::Timezone.malloc()
        LIBC.gettimeofday(timeval, timezone)
        cur = Time.now()
        assert(cur.to_i - 2 <= timeval.tv_sec && timeval.tv_sec <= cur.to_i)
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
      assert_in_out_err(%w[--debug --disable=gems -rfiddle/import], 'p Fiddle::Importer', ['Fiddle::Importer'])
    end
  end
end if defined?(Fiddle)
