require "bundler/gem_tasks"

desc "Run test"
task :test do
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

if RUBY_ENGINE == "ruby"
  require 'rake/extensiontask'
  Rake::ExtensionTask.new("fiddle")
  Rake::ExtensionTask.new("-test-/memory_view")
  task test: :compile
else
  task :compile
end

task default: :test
