require_relative "lib/bonchi/version"

Gem::Specification.new do |spec|
  spec.name = "bonchi"
  spec.version = Bonchi::VERSION
  spec.authors = ["Gert Goet"]
  spec.summary = "Git worktree manager"
  spec.description = "Manage git worktrees with automatic port allocation, file copying, and setup commands"
  spec.homepage = "https://github.com/gertgoet/bonchi"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*.rb", "exe/*", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["bonchi"]

  spec.add_dependency "thor", "~> 1.0"
end
