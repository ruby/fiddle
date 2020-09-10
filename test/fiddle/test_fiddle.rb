# frozen_string_literal: true
begin
  require_relative 'helper'
rescue LoadError
end

class TestFiddle < Fiddle::TestCase
  def test_windows_constant
    require 'rbconfig'
    if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
      assert Fiddle::WINDOWS, "Fiddle::WINDOWS should be 'true' on Windows platforms"
    else
      refute Fiddle::WINDOWS, "Fiddle::WINDOWS should be 'false' on non-Windows platforms"
    end
  end

  def test_memcpy_pointer
    src     = Fiddle::Pointer[Marshal.load(Marshal.dump("hello world"))]
    smaller = Fiddle::Pointer[Marshal.load(Marshal.dump("1234567890"))]
    same    = Fiddle::Pointer[Marshal.load(Marshal.dump("12345678901"))]
    larger  = Fiddle::Pointer[Marshal.load(Marshal.dump("123456789012"))]

    assert_equal(src.size - 1, Fiddle.memcpy(smaller, src))
    assert_equal(src.size    , Fiddle.memcpy(same, src))
    assert_equal(src.size    , Fiddle.memcpy(larger, src))
    assert_equal("hello worl",   smaller.to_s)
    assert_equal("hello world",  same.to_s)
    assert_equal("hello world2", larger.to_s)
  end

  def test_memcpy_address
    src  = Fiddle::Pointer[Marshal.load(Marshal.dump("hello world"))]
    dest = Fiddle::Pointer[Marshal.load(Marshal.dump("12345678901"))]

    assert_equal(src.size - 1,
                 Fiddle.memcpy(dest.to_i, src.to_i, src.size - 1))
    assert_equal("hello worl1", dest.to_s)
  end
end if defined?(Fiddle)
