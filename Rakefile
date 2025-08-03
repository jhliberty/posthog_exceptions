require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['spec/**/*_spec.rb']
end

task default: :test

desc 'Open an IRB session with the gem loaded'
task :console do
  sh 'bin/console'
end
