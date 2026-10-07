# frozen_string_literal: true

# The gem's entry point is deliberately empty: the Ruby LSP discovers the add-on itself through
# lib/ruby_lsp/slim/addon.rb, and the application that bundles this gem must not load language server code.
require_relative "ruby_lsp/slim/version"
