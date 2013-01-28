# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "code_statistics"
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jon Frisby", "Dan Mayer"]
  s.date = "2013-01-28"
  s.description = "This is a port of the rails 'rake stats' method so it can be made more robust and work for non rails projects. New features may eventually be added as well."
  s.email = "engineering@cloudability.com"
  s.executables = ["code_statistics"]
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md"
  ]
  s.files = [
    "LICENSE",
    "README.md",
    "bin/code_statistics",
    "code_statistics.gemspec",
    "lib/code_statistics.rb",
    "lib/code_statistics/code_statistics.rb",
    "lib/tasks/code_stats.rb"
  ]
  s.homepage = "http://github.com/cloudability/code_statistics"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")
  s.rubygems_version = "1.8.24"
  s.summary = "Making a gem of the normal rails rake stats method, to make it more robust and work on non rails projects"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

