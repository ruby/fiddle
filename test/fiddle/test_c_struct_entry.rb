# frozen_string_literal: true
begin
  require_relative 'helper'
  require 'fiddle/struct'
rescue LoadError
end

module Fiddle
  class TestCStructEntity < TestCase
    def test_class_size
      types = [TYPE_DOUBLE, TYPE_CHAR]

      size = CStructEntity.size types

      alignments = types.map { |type| PackInfo::ALIGN_MAP[type] }

      expected = PackInfo.align 0, alignments[0]
      expected += PackInfo::SIZE_MAP[TYPE_DOUBLE]

      expected = PackInfo.align expected, alignments[1]
      expected += PackInfo::SIZE_MAP[TYPE_CHAR]

      expected = PackInfo.align expected, alignments.max

      assert_equal expected, size
    end

    def test_class_size_with_count
      size = CStructEntity.size([[TYPE_DOUBLE, 2], [TYPE_CHAR, 20]])

      types = [TYPE_DOUBLE, TYPE_CHAR]
      alignments = types.map { |type| PackInfo::ALIGN_MAP[type] }

      expected = PackInfo.align 0, alignments[0]
      expected += PackInfo::SIZE_MAP[TYPE_DOUBLE] * 2

      expected = PackInfo.align expected, alignments[1]
      expected += PackInfo::SIZE_MAP[TYPE_CHAR] * 20

      expected = PackInfo.align expected, alignments.max

      assert_equal expected, size
    end

    def test_set_ctypes
      struct = CStructEntity.malloc [TYPE_INT, TYPE_LONG], Fiddle::RUBY_FREE
      struct.assign_names %w[int long]

      # this test is roundabout because the stored ctypes are not accessible
      struct['long'] = 1
      struct['int'] = 2

      assert_equal 1, struct['long']
      assert_equal 2, struct['int']
    end

    def test_aref_pointer_array
      team = CStructEntity.malloc([[TYPE_VOIDP, 2]], Fiddle::RUBY_FREE)
      team.assign_names(["names"])
      Fiddle::Pointer.malloc(6, Fiddle::RUBY_FREE) do |alice|
        alice[0, 6] = "Alice\0"
        Fiddle::Pointer.malloc(4, Fiddle::RUBY_FREE) do |bob|
          bob[0, 4] = "Bob\0"
          team["names"] = [alice, bob]
          assert_equal(["Alice", "Bob"], team["names"].map(&:to_s))
        end
      end
    end

    def test_aref_pointer
      user = CStructEntity.malloc([TYPE_VOIDP], Fiddle::RUBY_FREE)
      user.assign_names(["name"])
      Fiddle::Pointer.malloc(6, Fiddle::RUBY_FREE) do |alice|
        alice[0, 6] = "Alice\0"
        user["name"] = alice
        assert_equal("Alice", user["name"].to_s)
      end
    end
  end
end if defined?(Fiddle)
