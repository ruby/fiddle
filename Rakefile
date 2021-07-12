require "bundler/gem_tasks"

desc "Run test"
task :test do
  ENV["RUBYOPT"] = "-Ilib -Itest/lib -rbundler/setup -rhelper"
  ruby("test/run.rb")
end

require 'rake/extensiontask'
Rake::ExtensionTask.new("fiddle")
Rake::ExtensionTask.new("-test-/memory_view")

task :default => [:compile, :test]

task :sync_tool do
  require 'fileutils'
  FileUtils.cp "../ruby/tool/lib/test/unit/core_assertions.rb", "./test/lib"
  FileUtils.cp "../ruby/tool/lib/envutil.rb", "./test/lib"
  FileUtils.cp "../ruby/tool/lib/find_executable.rb", "./test/lib"
end
