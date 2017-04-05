require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "test/lib"
  t.libs << "lib"
  t.test_files = FileList['test/**/test_*.rb']
end

require 'rake/extensiontask'
Rake::ExtensionTask.new("fiddle")

task :default => :test
