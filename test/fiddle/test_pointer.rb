# frozen_string_literal: true
begin
  require_relative 'helper'
rescue LoadError
end

module Fiddle
  class TestPointer < TestCase
    def dlwrap arg
      Fiddle.dlwrap arg
    end

    def test_can_read_write_memory
      # Allocate some memory
      Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP, Fiddle::RUBY_FREE) do |pointer|
        address = pointer.to_i
        bytes_to_write = Fiddle::SIZEOF_VOIDP.times.to_a.pack("C*")

        # Write to the memory
        Fiddle::Pointer.write(address, bytes_to_write)

        # Read the bytes out again
        bytes = Fiddle::Pointer.read(address, Fiddle::SIZEOF_VOIDP)
        assert_equal bytes_to_write, bytes
      end
    end

    def test_cptr_to_int
      null = Fiddle::NULL
      assert_equal(null.to_i, null.to_int)
    end

    def test_malloc_free_func_int
      free = Fiddle::Function.new(Fiddle::RUBY_FREE, [TYPE_VOIDP], TYPE_VOID)
      assert_equal free.to_i, Fiddle::RUBY_FREE.to_i

      ptr  = Pointer.malloc(10, free.to_i)
      assert_equal 10, ptr.size
      assert_equal free.to_i, ptr.free.to_i
    end

    def test_malloc_free_func
      free = Fiddle::Function.new(Fiddle::RUBY_FREE, [TYPE_VOIDP], TYPE_VOID)

      ptr  = Pointer.malloc(10, free)
      assert_equal 10, ptr.size
      assert_equal free.to_i, ptr.free.to_i
    end

    def test_malloc_block
      escaped_ptr = nil
      returned = Pointer.malloc(10, Fiddle::RUBY_FREE) do |ptr|
        assert_equal 10, ptr.size
        assert_equal Fiddle::RUBY_FREE, ptr.free.to_i
        escaped_ptr = ptr
        :returned
      end
      assert_equal :returned, returned
      assert escaped_ptr.freed?
    end

    def test_malloc_block_no_free
      assert_raise ArgumentError do
        Pointer.malloc(10) { |ptr| }
      end
    end

    def test_malloc_subclass
      subclass = Class.new(Pointer)
      subclass.malloc(10, Fiddle::RUBY_FREE) do |ptr|
        assert ptr.is_a?(subclass)
      end
    end

    def test_to_str
      str = Marshal.load(Marshal.dump("hello world"))
      ptr = Pointer[str]

      assert_equal 3, ptr.to_str(3).length
      assert_equal str, ptr.to_str

      ptr[5] = 0
      assert_equal "hello\0world", ptr.to_str

      ptr.size = 0
      assert_equal "", ptr.to_str
      assert_equal "ello\0", (ptr + 1).to_str(5)
      assert_raise(ArgumentError) do
        (ptr + 1).to_str
      end
    end

    def test_to_s
      str = Marshal.load(Marshal.dump("hello world"))
      ptr = Pointer[str]

      assert_equal 3, ptr.to_s(3).length
      assert_equal str, ptr.to_s

      ptr[5] = 0
      assert_equal 'hello', ptr.to_s
      assert_equal "hello\0", ptr.to_s(6)

      ptr.size = 0
      assert_equal "hello", ptr.to_s
      assert_equal "ello\0", (ptr + 1).to_s(5)
      assert_equal "ello", (ptr + 1).to_s
    end

    def test_minus
      str = "hello world"
      ptr = Pointer[str]
      assert_equal ptr.to_s, (ptr + 3 - 3).to_s
    end

    # TODO: what if the pointer size is 0?  raise an exception? do we care?
    def test_plus
      str = "hello world"
      ptr = Pointer[str]
      new_str = ptr + 3
      assert_equal 'lo world', new_str.to_s
    end

    def test_inspect
      ptr = Pointer.new(0)
      inspect = ptr.inspect
      assert_match(/size=#{ptr.size}/, inspect)
      assert_match(/free=#{sprintf("%#x", ptr.free.to_i)}/, inspect)
      assert_match(/ptr=#{sprintf("%#x", ptr.to_i)}/, inspect)
    end

    def test_to_ptr_string
      str = "hello world"
      ptr = Pointer[str]
      assert_equal str.length, ptr.size
      assert_equal 'hello', ptr[0,5]
      assert_equal 0, Fiddle::Pointer.to_ptr("abc")[3]
      assert_equal "world", Fiddle::Pointer.to_ptr("hello\0world")[6,5]
    end

    def test_to_ptr_io
      if ffi_backend?
        omit("Fiddle::Pointer.to_ptr(IO) isn't supported with FFI backend")
      end

      Pointer.malloc(10, Fiddle::RUBY_FREE) do |buf|
        File.open(__FILE__, 'r') do |f|
          ptr = Pointer.to_ptr f
          fread = Function.new(@libc['fread'],
                              [TYPE_VOIDP, TYPE_INT, TYPE_INT, TYPE_VOIDP],
                              TYPE_INT)
          fread.call(buf.to_i, Fiddle::SIZEOF_CHAR, buf.size - 1, ptr.to_i)
        end

        File.open(__FILE__, 'r') do |f|
          assert_equal f.read(9), buf.to_s
        end
      end
    end

    def test_to_ptr_with_ptr
      ptr = Pointer.new 0
      ptr2 = Pointer.to_ptr Struct.new(:to_ptr).new(ptr)
      assert_equal ptr, ptr2

      assert_raise(Fiddle::DLError) do
        Pointer.to_ptr Struct.new(:to_ptr).new(nil)
      end
    end

    def test_to_ptr_with_int
      ptr = Pointer.new 0
      assert_equal ptr, Pointer[0]
    end

    MimicInteger = Struct.new(:to_int)
    def test_to_ptr_with_to_int
      ptr = Pointer.new 0
      assert_equal ptr, Pointer[MimicInteger.new(0)]
    end

    def test_equals
      ptr   = Pointer.new 0
      ptr2  = Pointer.new 0
      assert_equal ptr2, ptr
    end

    def test_not_equals
      ptr = Pointer.new 0
      refute_equal 10, ptr, '10 should not equal the pointer'
    end

    def test_cmp
      ptr = Pointer.new 0
      assert_nil(ptr <=> 10, '10 should not be comparable')
    end

    def test_ref
      ptr = Fiddle::Pointer["hello"]
      ref = ptr.ref
      assert_equal(0, ref.size)
      assert_nil(ref.free)
      assert_equal(ptr, ref.ptr)

      ptr2 = Fiddle::Pointer["world"]
      ptr.ref[0, Fiddle::SIZEOF_VOIDP] = ptr2.ref
      assert_equal("world", ptr.to_s)
      assert_equal(ptr.to_i, ptr2.to_i)
    end

    def test_ref_ptr
      if ffi_backend?
        omit("Fiddle.dlwrap([]) isn't supported with FFI backend")
      end

      ary = [0,1,2,4,5]
      addr = Pointer.new(dlwrap(ary))
      assert_equal addr.to_i, addr.ref.ptr.to_i

      assert_equal addr.to_i, (+ (- addr)).to_i
    end

    def test_to_value
      if ffi_backend?
        omit("Fiddle.dlwrap([]) isn't supported with FFI backend")
      end

      ary = [0,1,2,4,5]
      addr = Pointer.new(dlwrap(ary))
      assert_equal ary, addr.to_value
    end

    def test_free
      ptr = Pointer.malloc(4)
      begin
        assert_nil ptr.free
      ensure
        Fiddle.free ptr
      end
    end

    def test_free=
      free = Function.new(Fiddle::RUBY_FREE, [TYPE_VOIDP], TYPE_VOID)
      ptr = Pointer.malloc(4)
      ptr.free = free

      assert_equal free.ptr, ptr.free.ptr
    end

    def test_free_with_func
      ptr = Pointer.malloc(4, Fiddle::RUBY_FREE)
      refute ptr.freed?
      ptr.call_free
      assert ptr.freed?
      ptr.call_free                 # you can safely run it again
      assert ptr.freed?
      GC.start                      # you can safely run the GC routine
      assert ptr.freed?
    end

    def test_free_with_no_func
      ptr = Pointer.malloc(4)
      refute ptr.freed?
      ptr.call_free
      refute ptr.freed?
      ptr.call_free                 # you can safely run it again
      refute ptr.freed?
    end

    def test_freed?
      ptr = Pointer.malloc(4, Fiddle::RUBY_FREE)
      refute ptr.freed?
      ptr.call_free
      assert ptr.freed?
    end

    def test_null?
      ptr = Pointer.new(0)
      assert ptr.null?
    end

    def test_size
      Pointer.malloc(4, Fiddle::RUBY_FREE) do |ptr|
        assert_equal(4, ptr.size)
      end
      assert_equal(0, Pointer.new(0).size)
      assert_equal(0, Pointer.new(0).ref.size)
      assert_equal(-1, (Pointer.new(0) + 1).size)
    end

    def test_size=
      Pointer.malloc(4, Fiddle::RUBY_FREE) do |ptr|
        ptr.size = 10
        assert_equal 10, ptr.size
      end
    end

    def test_aref_aset
      check = Proc.new{|str,ptr|
        assert_equal(str.size(), ptr.size())
        assert_equal(str, ptr.to_s())
        assert_equal(str[0,2], ptr.to_s(2))
        assert_equal(str[0,2], ptr[0,2])
        assert_equal(str[1,2], ptr[1,2])
        assert_equal(str[1,0], ptr[1,0])
        assert_equal(str[0].ord, ptr[0])
        assert_equal(str[1].ord, ptr[1])
      }
      str = Marshal.load(Marshal.dump('abc'))
      ptr = Pointer[str]
      check.call(str, ptr)

      str[0] = "c"
      assert_equal 'c'.ord, ptr[0] = "c".ord
      check.call(str, ptr)

      str[0,2] = "aa"
      assert_equal 'aa', ptr[0,2] = "aa"
      check.call(str, ptr)

      ptr2 = Pointer['cdeeee']
      str[0,2] = "cd"
      assert_equal ptr2, ptr[0,2] = ptr2
      check.call(str, ptr)

      ptr3 = Pointer['vvvv']
      str[0,2] = "vv"
      assert_equal ptr3.to_i, ptr[0,2] = ptr3.to_i
      check.call(str, ptr)
    end

    def test_null_pointer
      nullpo = Pointer.new(0)
      assert_raise(DLError) {nullpo[0]}
      assert_raise(DLError) {nullpo[0] = 1}
    end

    def test_ractor_shareable
      omit("Need Ractor") unless defined?(Ractor)
      assert_ractor_shareable(Fiddle::NULL)
      ary = [0, 1, 2, 4, 5]
      addr = Pointer.new(dlwrap(ary))
      assert_ractor_shareable(addr)
    end
  end
end if defined?(Fiddle)
