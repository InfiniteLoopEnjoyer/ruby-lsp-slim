# frozen_string_literal: true

require "ruby_lsp/internal"
require_relative "version"
require_relative "scanner"
require_relative "document"
require_relative "hover"
require_relative "completion"
require_relative "editor_registration"

module RubyLsp
  module Slim
    # Store#set is the one place the server builds a document, choosing the class from the language id the client
    # sent. A Slim file may arrive as `slim`, `plaintext` or `erb` depending on the editor, so the `.slim` extension
    # is the signal here; it also covers the store reading a file off disk, where there is no language id at all.
    module StoreExtension
      def set(uri:, source:, version:, language_id:)
        return super unless uri.to_s.end_with?(".slim")

        @state[uri.to_s] = Document.new(source: source, version: version, uri: uri, global_state: @global_state)
      end
    end

    Store.prepend(StoreExtension)

    # The hover request hands add-ons a node context but not the document, so the document is kept for the add-on's
    # listener while the request is being built (add-on listeners are created inside this constructor).
    module HoverRequestExtension
      def initialize(document, *)
        Thread.current[:ruby_lsp_slim_hover_document] = document
        super
      ensure
        Thread.current[:ruby_lsp_slim_hover_document] = nil
      end
    end

    Requests::Hover.prepend(HoverRequestExtension)

    class Addon < ::RubyLsp::Addon
      def activate(global_state, outgoing_queue)
        @global_state = global_state
        outgoing_queue << EditorRegistration.request
        outgoing_queue << Notification.window_log_message(
          "ruby-lsp-slim #{ VERSION }: Slim documents registered with the editor",
          type: Constant::MessageType::INFO,
        )
      end

      def deactivate; end

      def name
        "Slim"
      end

      def version
        VERSION
      end

      def create_hover_listener(response_builder, _node_context, dispatcher)
        return unless Thread.current[:ruby_lsp_slim_hover_document].is_a?(Document)

        Hover.new(response_builder, @global_state, dispatcher)
      end

      def create_completion_listener(response_builder, _node_context, dispatcher, uri)
        return unless uri.to_s.end_with?(".slim")

        Completion.new(response_builder, @global_state, dispatcher)
      end
    end
  end
end
