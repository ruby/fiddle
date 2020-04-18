#!/usr/bin/env ruby

$VERBOSE = true

base_dir = "#{__dir__}/.."
$LOAD_PATH.unshift("#{base_dir}/test")
$LOAD_PATH.unshift("#{base_dir}/test/lib")
$LOAD_PATH.unshift("#{base_dir}/lib")

Dir.glob("#{base_dir}/test/fiddle/test_*.rb") do |test_rb|
  require File.expand_path(test_rb)
end
