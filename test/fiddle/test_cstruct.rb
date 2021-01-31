# frozen_string_literal: true
begin
  require_relative 'helper'
rescue LoadError
end

module Fiddle
  class TestStruct < TestCase
    # https://github.com/ruby/fiddle/issues/66
    def test_clone_gh_66
      s = Fiddle::Importer.struct(["int i"])
      a = s.malloc
      a.i = 10
      b = a.clone
      b.i = 20
      assert_equal({a: 10,  b: 20},
                   {a: a.i, b: b.i})
    end
  end
end
