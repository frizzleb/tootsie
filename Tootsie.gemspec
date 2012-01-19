# -*- encoding: utf-8 -*-

$:.push File.expand_path("../lib", __FILE__)
require "tootsie"

Gem::Specification.new do |s|
  s.name        = "tootsie"
  s.version     = Tootsie::VERSION
  s.authors     = ["Alexander Staubo"]
  s.email       = ["alex@origo.no"]
  s.homepage    = ""
  s.summary     = s.description = %{Tootsie is a simple audio/video/image transcoding/modification application.}

  s.rubyforge_project = "tootsie"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
end
