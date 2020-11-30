# frozen_string_literal: true
begin
  require_relative 'helper'
rescue LoadError
end

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
  end
end
