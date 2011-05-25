# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "nagios-dashboard/version"

Gem::Specification.new do |s|
  s.name        = "nagios-dashboard"
  s.version     = Nagios::Dashboard::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Sean Porter"]
  s.email       = ["portertech@gmail.com"]
  s.homepage    = "https://github.com/portertech/nagios-dashboard"
  s.summary     = %q{A Nagios dashboard with OpsCode Chef integration.}
  s.description = %q{A Nagios dashboard with OpsCode Chef integration.}

  s.rubyforge_project = "nagios-dashboard"

  s.add_development_dependency('bundler')

  s.add_dependency('mixlib-cli')
  s.add_dependency('mixlib-log')
  s.add_dependency('json')
  s.add_dependency('thin', '1.2.11')
  s.add_dependency('eventmachine')
  s.add_dependency('em-websocket')
  s.add_dependency('directory_watcher')
  s.add_dependency('nagios_analyzer')
  s.add_dependency('async_sinatra')
  s.add_dependency('haml')
  s.add_dependency('spice', '0.5.0')

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
