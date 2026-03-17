require "bundler/gem_tasks"

# Bundler hardcodes a "v" prefix in version_tag — override to use bare version.
Bundler::GemHelper.instance.define_singleton_method(:version_tag) { version.to_s }
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.warning = true
  t.test_files = FileList["test/**/test_*.rb"]
end

task default: :test

if ENV["CI"]
  # version.rb is written at CI which prevents guard_clean from passing.
  # Redefine guard_clean to make it a noop.
  Rake::Task["release:guard_clean"].clear
  task "release:guard_clean"

  # As a release is triggered by a tag, nothing should be pushed.
  Rake::Task["release:source_control_push"].clear
  task "release:source_control_push"
end
