# frozen_string_literal: true

require_relative "lib/ruby_lsp/slim/version"

Gem::Specification.new do |spec|
  spec.name = "ruby-lsp-slim"
  spec.version = RubyLsp::Slim::VERSION
  spec.authors = ["Tayden Miller"]
  spec.email = ["tayden007@hotmail.com"]
  spec.summary = "Ruby LSP add-on for Slim templates"
  spec.description = "Go to definition, hover, completion and semantic highlighting for the Ruby inside Slim " \
    "templates, through the Ruby LSP."
  spec.homepage = "https://github.com/InfiniteLoopEnjoyer/ruby-lsp-slim"
  spec.license = "MIT"
  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => "#{ spec.homepage }/issues",
  }
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby-lsp", ">= 0.26.0", "< 0.27.0"
end
