# frozen_string_literal: true

module RubyLsp
  module Slim
    # Hover for a call without a receiver inside a template. The Ruby LSP infers the receiver of such a call as
    # `Object`, finds no method there and shows nothing; this offers the index's candidates instead, as go to
    # definition already does for the same call. Calls with a receiver are left to the Ruby LSP.
    class Hover
      include Requests::Support::Common

      MAX_CANDIDATES = Listeners::Definition::MAX_NUMBER_OF_DEFINITION_CANDIDATES_WITHOUT_RECEIVER

      def initialize(response_builder, global_state, dispatcher)
        @response_builder = response_builder
        @index = global_state.index
        dispatcher.register(self, :on_call_node_enter)
      end

      def on_call_node_enter(node)
        return if node.receiver || !@response_builder.empty?

        message = node.message
        return unless message

        entries = @index[message]&.grep(RubyIndexer::Entry::Member)
        return if entries.nil? || entries.empty?

        first = entries.first
        title = "#{ message }#{ first.decorated_parameters }#{ first.formatted_signatures }"
        categorized_markdown_from_index_entries(title, entries, MAX_CANDIDATES).each do |category, content|
          @response_builder.push(content, category: category)
        end
      end
    end
  end
end
