﻿# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "version_info"
require "delphivm/version"

Gem::Specification.new do |s|
	s.name        = "delphivm"
	s.version     = Delphivm::VERSION
	s.platform    = Gem::Platform::RUBY
	s.authors     = ["Jorge L. Cangas"]
	s.email       = ["jorge.cangas@gmail.com"]
	s.homepage    = "http://github.com/jcangas/delphivm"
	s.summary     = %q{A Ruby gem to manage your multi-IDE delphi projects: build, genenrate docs, and any custom task you want}
	s.description = %q{Easy way to invoke tasks for all your IDE versions from the command line}

	s.rubyforge_project = "delphivm"

	s.files         = `git ls-files`.split("\n")
	s.test_files    = `git ls-files -- {test, spec, features}/*`.split("\n")
	s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
	s.require_paths = ["lib"]
	
	s.add_development_dependency "bundler"  
	s.add_development_dependency "rake"  
end