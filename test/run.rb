#!/usr/bin/env ruby

$VERBOSE = true

source_dir = "#{__dir__}/.."
if File.exist?("#{source_dir}/lib")
  # Test against Fiddle in source directory
  $LOAD_PATH.unshift("#{source_dir}/lib")

  build_dir = Dir.pwd
  if File.exist?("#{build_dir}/fiddle.so")
    $LOAD_PATH.unshift(build_dir)
  end
else
  # Test against Fiddle installed as gem
  gem "fiddle"
end

require "test/unit"

exit Test::Unit::AutoRunner.run(true, "#{source_dir}/test/fiddle")
