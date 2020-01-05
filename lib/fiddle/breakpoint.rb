require "fiddle"

module Fiddle
  @ruby_debug_breakpoint = Function.new(Handle.sym("ruby_debug_breakpoint"),
                                        [], Fiddle::TYPE_VOID)

  def self.ruby_debug_breakpoint
    @ruby_debug_breakpoint.()
  end
end
