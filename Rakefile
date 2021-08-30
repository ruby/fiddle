require "bundler/gem_tasks"

desc "Run test"
task :test do
  ENV["RUBYOPT"] = "-Ilib -Itest/lib -rbundler/setup -rhelper"
  ruby("test/run.rb")
end

namespace :version do
  desc "Bump version"
  task :bump do
    version_rb_path = "lib/fiddle/version.rb"
    version_rb = File.read(version_rb_path).gsub(/VERSION = "(.+?)"/) do
      version = $1
      "VERSION = \"#{version.succ}\""
    end
    File.write(version_rb_path, version_rb)
  end
end

require 'rake/extensiontask'
Rake::ExtensionTask.new("fiddle")
Rake::ExtensionTask.new("-test-/memory_view")

task :default => [:compile, :test]

task :sync_tool do
  require 'fileutils'
  FileUtils.cp "../ruby/tool/lib/core_assertions.rb", "./test/lib"
  FileUtils.cp "../ruby/tool/lib/envutil.rb", "./test/lib"
  FileUtils.cp "../ruby/tool/lib/find_executable.rb", "./test/lib"
end
