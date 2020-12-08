# frozen_string_literal: true
begin
  require_relative 'helper'
rescue LoadError
end

require '-test-/memory_view'

module Fiddle
  class TestMemoryView < TestCase
    def test_null_ptr
      assert_raise(ArgumentError) do
        MemoryView.new(Fiddle::NULL)
      end
    end

    def test_memory_view_from_unsupported_obj
      obj = Object.new
      assert_raise(ArgumentError) do
        MemoryView.new(obj)
      end
    end

    def test_memory_view_from_pointer
      str = Marshal.load(Marshal.dump("hello world"))
      ptr = Pointer[str]
      mview = MemoryView.new(ptr)
      assert_same(ptr, mview.obj)
      assert_equal(str.length, mview.length)
      assert_equal(true, mview.readonly?)
      assert_equal(nil, mview.format)
      assert_equal(1, mview.item_size)
      assert_equal(1, mview.ndim)
      assert_equal(nil, mview.shape)
      assert_equal(nil, mview.strides)
      assert_equal(nil, mview.sub_offsets)

      codes = str.codepoints
      assert_equal(codes, (0...str.length).map {|i| mview[i] })
    end

    def test_memory_view_multi_dimensional
      m = MemoryViewTestUtils
      buf = [ 1, 2, 3, 4,
              5, 6, 7, 8,
              9, 10, 11, 12 ].pack("l!*")
      shape = [3, 4]
      md = MemoryViewTestUtils::MultiDimensionalView.new(buf, shape, nil)
      mview = Fiddle::MemoryView.new(md)
      assert_equal(1, mview[0, 0])
      assert_equal(4, mview[0, 3])
      assert_equal(6, mview[1, 1])
      assert_equal(10, mview[2, 1])
    end

    def test_memory_view_multi_dimensional_with_strides
      buf = [ 1, 2,  3,  4,  5,  6,  7,  8,
              9, 10, 11, 12, 13, 14, 15, 16 ].pack("l!*")
      shape = [2, 8]
      strides = [4*Fiddle::SIZEOF_LONG*2, Fiddle::SIZEOF_LONG*2]
      md = MemoryViewTestUtils::MultiDimensionalView.new(buf, shape, strides)
      mview = Fiddle::MemoryView.new(md)
      assert_equal(1, mview[0, 0])
      assert_equal(5, mview[0, 2])
      assert_equal(9, mview[1, 0])
      assert_equal(15, mview[1, 3])
    end
  end
end
