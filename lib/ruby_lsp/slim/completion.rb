# frozen_string_literal: true

module RubyLsp
  module Slim
    # Completion for a call without a receiver inside a template: every public method in the index whose name starts
    # with what was typed. The Ruby LSP already offers locals, keywords and the methods of `Object` (the receiver it
    # infers in a template), so those are left out to avoid duplicates.
    class Completion
      include Requests::Support::Common

      def initialize(response_builder, global_state, dispatcher)
        @response_builder = response_builder
        @index = global_state.index
        dispatcher.register(self, :on_call_node_enter)
      end

      def on_call_node_enter(node)
        return if node.receiver

        name = node.message
        location = node.message_loc
        return unless name && location

        range = range_from_location(location)
        object_ancestors = begin
          @index.linearized_ancestors_of("Object")
        rescue RubyIndexer::Index::NonExistingNamespaceError
          [] # core RBS not indexed yet: nothing to leave out
        end
        seen = {}

        @index.prefix_search(name).flatten.each do |entry|
          next unless entry.is_a?(RubyIndexer::Entry::Member) && entry.visibility == :public

          owner_name = entry.owner&.name
          next if object_ancestors.include?(owner_name)
          next if seen[[entry.name, owner_name]]

          seen[[entry.name, owner_name]] = true
          @response_builder << Interface::CompletionItem.new(
            label: entry.name,
            filter_text: entry.name,
            label_details: Interface::CompletionItemLabelDetails.new(
              description: entry.file_name,
              detail: entry.decorated_parameters,
            ),
            text_edit: Interface::TextEdit.new(range: range, new_text: entry.name),
            kind: Constant::CompletionItemKind::METHOD,
            data: { owner_name: owner_name, guessed_type: nil },
          )
        end
      end
    end
  end
end
