#!/usr/bin/env ruby

$VERBOSE = true

source_dir = File.dirname(__dir__)
$LOAD_PATH.unshift("#{source_dir}/test")
$LOAD_PATH.unshift("#{source_dir}/lib")

build_dir = Dir.pwd
if File.exist?("#{build_dir}/fiddle.so")
  $LOAD_PATH.unshift(build_dir)
end

Dir.glob("#{source_dir}/test/fiddle/test_*.rb") do |test_rb|
  require File.expand_path(test_rb)
end
