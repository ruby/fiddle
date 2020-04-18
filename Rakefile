require "bundler/gem_tasks"

desc "Run test"
task :test do
  ruby("test/run.rb")
end

require 'rake/extensiontask'
Rake::ExtensionTask.new("fiddle")

task :default => [:compile, :test]
