# frozen_string_literal: true

module RubyLsp
  module Slim
    # A Slim template as the Ruby LSP sees it. It is an ERBDocument so that every request the server allows for ERB
    # (definition, hover, completion, semantic highlighting, document highlight...) runs on it, and so that the
    # definition listener's "no receiver inside a template" fallback applies; only the parse differs, taking the Ruby
    # out of Slim instead of out of `<% %>` tags.
    #
    # Slim omits `end`, so the Ruby handed to Prism is never complete; Prism's error-tolerant parse carries it. Blocks
    # nest wrongly past a dedent, but every node stays in place, which is what navigation needs.
    class Document < ERBDocument
      # @override
      def parse!
        return false unless @needs_parsing

        @needs_parsing = false
        scanner = Scanner.new(@source)
        begin
          scanner.scan
        rescue StandardError => e
          # A scanner bug must not take the document down with it: fall back to a template with no Ruby in it
          $stderr.puts("ruby-lsp-slim could not scan #{ @uri }: #{ e.class }: #{ e.message }")
          scanner = Scanner.new(@source.gsub(/[^\r\n]/, " ")).scan
        end
        @host_language_source = scanner.host_language
        @parse_result = Prism.parse_lex(scanner.ruby, partial_script: true)
        @code_units_cache = @parse_result.code_units_cache(@encoding)
        true
      end
    end
  end
end
