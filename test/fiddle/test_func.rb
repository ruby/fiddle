# frozen_string_literal: true
begin
  require_relative 'helper'
rescue LoadError
end

module Fiddle
  class TestFunc < TestCase
    def test_random
      f = Function.new(@libc['srand'], [-TYPE_LONG], TYPE_VOID)
      assert_nil f.call(10)
    end

    def test_sinf
      begin
        f = Function.new(@libm['sinf'], [TYPE_FLOAT], TYPE_FLOAT)
      rescue Fiddle::DLError
        omit "libm may not have sinf()"
      end
      assert_in_delta 1.0, f.call(90 * Math::PI / 180), 0.0001
    end

    def test_sin
      f = Function.new(@libm['sin'], [TYPE_DOUBLE], TYPE_DOUBLE)
      assert_in_delta 1.0, f.call(90 * Math::PI / 180), 0.0001
    end

    def test_string
      if RUBY_ENGINE == "jruby"
        omit("Function that returns string doesn't work with JRuby")
      end

      under_gc_stress do
        f = Function.new(@libc['strcpy'], [TYPE_VOIDP, TYPE_VOIDP], TYPE_VOIDP)
        buff = +"000"
        str = f.call(buff, "123")
        assert_equal("123", buff)
        assert_equal("123", str.to_s)
      end
    end

    def test_isdigit
      f = Function.new(@libc['isdigit'], [TYPE_INT], TYPE_INT)
      r1 = f.call(?1.ord)
      r2 = f.call(?2.ord)
      rr = f.call(?r.ord)
      assert_operator r1, :>, 0
      assert_operator r2, :>, 0
      assert_equal 0, rr
    end

    def test_atof
      f = Function.new(@libc['atof'], [TYPE_VOIDP], TYPE_DOUBLE)
      r = f.call("12.34")
      assert_includes(12.00..13.00, r)
    end

    def test_strtod
      f = Function.new(@libc['strtod'], [TYPE_VOIDP, TYPE_VOIDP], TYPE_DOUBLE)
      buff1 = Pointer["12.34"]
      buff2 = buff1 + 4
      r = f.call(buff1, - buff2)
      assert_in_delta(12.34, r, 0.001)
    end

    def test_qsort1
      if RUBY_ENGINE == "jruby"
        omit("The untouched sanity check is broken on JRuby: https://github.com/jruby/jruby/issues/8365")
      end

      closure_class = Class.new(Closure) do
        def call(x, y)
          Pointer.new(x)[0] <=> Pointer.new(y)[0]
        end
      end

      closure_class.create(TYPE_INT, [TYPE_VOIDP, TYPE_VOIDP]) do |callback|
        qsort = Function.new(@libc['qsort'],
                             [TYPE_VOIDP, TYPE_SIZE_T, TYPE_SIZE_T, TYPE_VOIDP],
                             TYPE_VOID)
        untouched = "9341"
        buff = +"9341"
        qsort.call(buff, buff.size, 1, callback)
        assert_equal("1349", buff)

        bug4929 = '[ruby-core:37395]'
        buff = +"9341"
        under_gc_stress do
          qsort.call(buff, buff.size, 1, callback)
        end
        assert_equal("1349", buff, bug4929)

        # Ensure the test didn't mutate String literals
        assert_equal("93" + "41", untouched)
      end
    ensure
      # We can't use ObjectSpace with JRuby.
      unless RUBY_ENGINE == "jruby"
        # Ensure freeing all closures.
        # See https://github.com/ruby/fiddle/issues/102#issuecomment-1241763091 .
        not_freed_closures = []
        ObjectSpace.each_object(Fiddle::Closure) do |closure|
          not_freed_closures << closure unless closure.freed?
        end
        assert_equal([], not_freed_closures)
      end
    end

    def test_snprintf
      unless Fiddle.const_defined?("TYPE_VARIADIC")
        omit "libffi doesn't support variadic arguments"
      end
      if Fiddle::WINDOWS
        snprintf_name = "_snprintf"
      else
        snprintf_name = "snprintf"
      end
      begin
        snprintf_pointer = @libc[snprintf_name]
      rescue Fiddle::DLError
        omit "Can't find #{snprintf_name}: #{$!.message}"
      end
      snprintf = Function.new(snprintf_pointer,
                              [
                                :voidp,
                                :size_t,
                                :const_string,
                                :variadic,
                              ],
                              :int)
      Pointer.malloc(1024, Fiddle::RUBY_FREE) do |output|
        written = snprintf.call(output,
                                output.size,
                                "int: %d, string: %.*s, const string: %s\n",
                                :int, -29,
                                :int, 4,
                                :voidp, "Hello",
                                :const_string, "World")
        assert_equal("int: -29, string: Hell, const string: World\n",
                     output[0, written])

        string_like_class = Class.new do
          def initialize(string)
            @string = string
          end

          def to_str
            @string
          end
        end
        written = snprintf.call(output,
                                output.size,
                                "string: %.*s, const string: %s, uint: %u\n",
                                :int, 2,
                                :voidp, "Hello",
                                :const_string, string_like_class.new("World"),
                                :int, 29)
        assert_equal("string: He, const string: World, uint: 29\n",
                     output[0, written])
      end
    end

    def test_rb_memory_view_available_p
      omit "MemoryView is unavailable" unless defined? Fiddle::MemoryView
      libruby = Fiddle.dlopen(nil)
      case Fiddle::SIZEOF_VOIDP
      when Fiddle::SIZEOF_LONG_LONG
        value_type = -Fiddle::TYPE_LONG_LONG
      else
        value_type = -Fiddle::TYPE_LONG
      end
      rb_memory_view_available_p =
        Function.new(libruby["rb_memory_view_available_p"],
                     [value_type],
                     :bool,
                     need_gvl: true)
      assert_equal(false, rb_memory_view_available_p.call(Fiddle::Qnil))
    end
  end
end if defined?(Fiddle)
