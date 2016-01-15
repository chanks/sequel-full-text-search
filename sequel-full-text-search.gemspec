# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sequel/extensions/full_text_search/version'

Gem::Specification.new do |spec|
  spec.name          = 'sequel-full-text-search'
  spec.version       = Sequel::FullTextSearch::VERSION
  spec.authors       = ["Chris Hanks"]
  spec.email         = ["christopher.m.hanks@gmail.com"]

  spec.summary       = %q{Sequel extension for full-text-search tooling on PostgreSQL.}
  spec.description   = %q{A Sequel extension that provides full-text-search querying on Postgres.}
  spec.homepage      = 'https://github.com/chanks/sequel-full-text-search'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'sequel', '~> 4.0'

  spec.add_development_dependency 'bundler',        '~> 1.11'
  spec.add_development_dependency 'rake',           '~> 10.0'
  spec.add_development_dependency 'minitest',       '~> 5.0'
  spec.add_development_dependency 'minitest-hooks', '~> 1.4'
  spec.add_development_dependency 'faker',          '~> 1.6.1'
  spec.add_development_dependency 'pg'
  spec.add_development_dependency 'pry'
end
