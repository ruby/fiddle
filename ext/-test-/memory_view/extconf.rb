# frozen_string_literal: false
require "mkmf"

if have_header("ruby/memory_view.h")
  have_type("rb_memory_view_t", ["ruby/memory_view.h"])
end

require_relative "../auto_ext.rb"
auto_ext(inc: true)
