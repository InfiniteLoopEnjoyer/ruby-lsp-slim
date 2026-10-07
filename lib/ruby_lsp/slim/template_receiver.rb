# frozen_string_literal: true

module RubyLsp
  module Slim
    # Receivers a template reader knows but the type inferrer cannot. The inferrer guesses a receiver's type from its
    # name (`user` → `User`); `f`, `form` and friends mean a form builder in a template, which that rule never finds.
    # Keyed on the document in flight (see RequestDocumentExtension), so Ruby files keep the Ruby LSP's own answers.
    module TemplateReceiver
      BUILDER_NAME = /\A(?:f|ff|form|builder|fields|\w+_(?:form|builder|fields))\z/
      BUILDER_CLASSES = ["SimpleForm::FormBuilder", "ActionView::Helpers::FormBuilder"].freeze

      # The builder comes first: the Ruby LSP's own guess from the variable's name (`f` → `F`) can land on an
      # unrelated constant — `ARGF` in a full index — and a template's `f` is a form builder before anything else.
      module TypeInferrerExtension
        def infer_receiver_type(node_context)
          TemplateReceiver.form_builder(node_context, @index) || super
        end
      end

      def self.form_builder(node_context, index)
        return unless Thread.current[:ruby_lsp_slim_document].is_a?(Document)

        node = node_context.node
        return unless node.is_a?(Prism::CallNode)

        name = receiver_name(node.receiver)
        return unless name&.match?(BUILDER_NAME)

        builder = BUILDER_CLASSES.find { |class_name| index[class_name] }
        TypeInferrer::GuessedType.new(builder) if builder
      end

      # A block parameter or assigned local reads as a local variable; a local the template only declares (Rails'
      # strict `locals:` comment, or one handed in by the renderer) parses as a call with no receiver or arguments
      def self.receiver_name(receiver)
        case receiver
        when Prism::LocalVariableReadNode then receiver.name.to_s
        when Prism::CallNode then receiver.message if receiver.variable_call?
        end
      end
    end

    TypeInferrer.prepend(TemplateReceiver::TypeInferrerExtension)
  end
end
