# frozen_string_literal: true

module RubyLsp
  module Slim
    # Asks the editor to send Slim documents to the server. Editors set up their Ruby LSP client for `ruby` and `erb`
    # documents only, so a Slim file never reaches the server by itself; the protocol lets a server extend that at
    # runtime (`client/registerCapability`), and this registers text synchronisation plus every feature the server
    # offers ERB documents, for Slim files — by language id where the editor has a `slim` language, by path otherwise.
    class EditorRegistration
      SELECTOR = [{ language: "slim" }, { scheme: "file", pattern: "**/*.slim" }].freeze
      REQUEST_ID = "ruby-lsp-slim/register-slim-documents"

      # Features and the options they are registered with: a request class's own provider options where it has them
      # (trigger characters, the semantic token legend...), nothing but the selector otherwise.
      FEATURES = {
        "textDocument/didOpen" => {},
        "textDocument/didChange" => { syncKind: Constant::TextDocumentSyncKind::INCREMENTAL },
        "textDocument/didClose" => {},
        "textDocument/definition" => {},
        "textDocument/hover" => Requests::Hover,
        "textDocument/completion" => Requests::Completion,
        "textDocument/signatureHelp" => Requests::SignatureHelp,
        "textDocument/semanticTokens" => Requests::SemanticHighlighting,
        "textDocument/documentSymbol" => Requests::DocumentSymbol,
        "textDocument/documentHighlight" => {},
        "textDocument/documentLink" => Requests::DocumentLink,
        "textDocument/foldingRange" => {},
        "textDocument/selectionRange" => {},
        "textDocument/inlayHint" => Requests::InlayHints,
      }.freeze

      def self.request
        Request.new(
          id: REQUEST_ID,
          method: "client/registerCapability",
          params: Interface::RegistrationParams.new(registrations: new.registrations),
        )
      end

      def registrations
        FEATURES.map do |method, options|
          Interface::Registration.new(
            id: "ruby-lsp-slim/#{ method }",
            method: method,
            register_options: options_for(options).merge(documentSelector: SELECTOR),
          )
        end
      end

      private

      def options_for(options)
        return options unless options.is_a?(Class)

        provider = options.provider
        provider.respond_to?(:to_hash) ? provider.to_hash : {}
      end
    end
  end
end
