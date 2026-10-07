# frozen_string_literal: true

module RubyLsp
  module Slim
    # Action View builds most of FormBuilder's field helpers (`text_field`, `number_field`, `textarea`...) at load time
    # with `class_eval`, from the names in `field_helpers`, so the indexer never sees a definition for them and
    # `f.number_field` cannot be resolved however well its receiver is typed. While Action View is being indexed, this
    # reads that literal list and adds an entry per generated helper, with the signature Action View gives them.
    class FormBuilderFields < RubyIndexer::Enhancement
      BUILDER = "ActionView::Helpers::FormBuilder"
      # The helpers Action View defines by hand instead, right next to the list
      DEFINED_BY_HAND = [
        "label", "checkbox", "check_box", "radio_button", "fields_for", "fields", "hidden_field", "file_field",
      ].freeze
      SIGNATURES = [
        RubyIndexer::Entry::Signature.new([
          RubyIndexer::Entry::RequiredParameter.new(name: :method),
          RubyIndexer::Entry::OptionalParameter.new(name: :options),
        ]),
      ].freeze

      def on_call_node_enter(node)
        return unless @listener.current_owner&.name == BUILDER

        list = field_helpers_list(node)
        return unless list

        list.elements.each do |element|
          next unless element.is_a?(Prism::SymbolNode)

          name = element.value.to_s
          next if DEFINED_BY_HAND.include?(name)

          @listener.add_method(
            name,
            element.location,
            SIGNATURES,
            comments: "Field helper that Action View generates for the form builder from `field_helpers`: " \
                      "`#{ name }` of `ActionView::Helpers::FormHelper`, with this builder's object and options.",
          )
        end
      end

      private

      # `class_attribute :field_helpers, default: [...]` (Rails 7+) or `self.field_helpers = [...]` (earlier)
      def field_helpers_list(node)
        arguments = node.arguments&.arguments
        return unless arguments

        case node.name
        when :class_attribute
          return unless arguments.first.is_a?(Prism::SymbolNode) && arguments.first.value == "field_helpers"

          keywords = arguments.find { |argument| argument.is_a?(Prism::KeywordHashNode) }
          default = keywords&.elements&.find do |pair|
            pair.is_a?(Prism::AssocNode) && pair.key.is_a?(Prism::SymbolNode) && pair.key.value == "default"
          end
          default&.value if default&.value.is_a?(Prism::ArrayNode)
        when :field_helpers=
          arguments.first if arguments.first.is_a?(Prism::ArrayNode)
        end
      end
    end
  end
end
