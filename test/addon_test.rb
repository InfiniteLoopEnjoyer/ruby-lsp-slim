# frozen_string_literal: true

require_relative "test_helper"

class AddonTest < Minitest::Test
  include RubyLsp::TestHelper

  HELPER = <<~RUBY
    module TableHelper
      # The classes of one part of the table
      def table_classes(part)
        "table-\#{ part }"
      end
    end
  RUBY

  TEMPLATE = <<~SLIM
    / A table
    - rows = fetch_rows
    div class=table_classes(:scroll)
      p.title = title_for(rows)
      = f.number_field :volume
      = form_with do |form|
        = form.number_field :weight
  SLIM

  FORM_BUILDER = <<~RUBY
    module ActionView
      module Helpers
        class FormBuilder
          # A number input for the attribute
          def number_field(method, options = {}); end
        end
      end
    end
  RUBY

  def test_the_server_discovers_the_addon_through_the_gem
    with_server(load_addons: true) do
      assert_includes RubyLsp::Addon.addons.map(&:name), "Slim"
    end
  end

  def test_a_slim_uri_gets_a_slim_document_whatever_the_language_id
    with_slim_server do |server, uri|
      assert_kind_of RubyLsp::Slim::Document, server.instance_variable_get(:@store).get(uri)
    end
  end

  def test_go_to_definition_on_a_helper_call_in_an_attribute
    with_slim_server do |server, uri|
      server.process_message({
        id: 1,
        method: "textDocument/definition",
        params: { textDocument: { uri: uri }, position: { line: 2, character: 12 } },
      })
      locations = pop_result(server).response

      assert_equal 1, locations.length
      assert_equal "file:///fake/table_helper.rb", locations.first.target_uri
      assert_equal 2, locations.first.target_range.start.line
    end
  end

  def test_go_to_definition_on_a_helper_call_in_an_output_line
    with_slim_server do |server, uri|
      server.process_message({
        id: 1,
        method: "textDocument/definition",
        params: { textDocument: { uri: uri }, position: { line: 3, character: 12 } },
      })

      assert_equal ["file:///fake/table_helper.rb"], pop_result(server).response.map(&:target_uri)
    end
  end

  def test_positions_in_the_host_language_find_nothing
    with_slim_server do |server, uri|
      server.process_message({
        id: 1,
        method: "textDocument/definition",
        params: { textDocument: { uri: uri }, position: { line: 2, character: 1 } },
      })

      assert_empty pop_result(server).response
    end
  end

  def test_edits_are_rescanned
    with_slim_server do |server, uri|
      server.process_message({
        method: "textDocument/didChange",
        params: {
          textDocument: { uri: uri, version: 2 },
          # the server syncs incrementally: replace the comment on the first line
          contentChanges: [{
            range: { start: { line: 0, character: 0 }, end: { line: 0, character: 9 } },
            text: "= title_for(nil)",
          }],
        },
      })
      # The server's reader thread parses right after applying a change (BaseServer#start); test mode has no reader
      document = server.instance_variable_get(:@store).get(uri)
      assert document.parse!, "the edit should leave the document needing a parse"
      server.process_message({
        id: 2,
        method: "textDocument/definition",
        params: { textDocument: { uri: uri }, position: { line: 0, character: 4 } },
      })

      assert_equal ["file:///fake/table_helper.rb"], pop_result(server).response.map(&:target_uri)
    end
  end

  def test_hover_on_a_bare_helper_call_offers_the_candidates
    with_slim_server do |server, uri|
      server.process_message({
        id: 1,
        method: "textDocument/hover",
        params: { textDocument: { uri: uri }, position: { line: 2, character: 12 } },
      })
      markdown = pop_result(server).response.contents.value

      assert_includes markdown, "table_classes(part)"
      assert_includes markdown, "The classes of one part of the table"
      assert_includes markdown, "table_helper.rb"
    end
  end

  def test_completion_on_a_bare_helper_call_offers_project_methods
    with_slim_server do |server, uri|
      server.process_message({
        id: 1,
        method: "textDocument/completion",
        params: { textDocument: { uri: uri }, position: { line: 2, character: 14 } },
      })
      items = pop_result(server).response

      assert_equal(1, items.count { |item| item.label == "table_classes" })
      assert_equal "table_classes", items.find { |item| item.label == "table_classes" }.text_edit.new_text
      assert_equal "TableHelper", items.find { |item| item.label == "table_classes" }.data[:owner_name]
    end
  end

  def test_hover_and_completion_in_ruby_files_are_left_to_the_ruby_lsp
    ruby_uri = URI::Generic.from_path(path: "/fake/app/views/table.rb")
    with_server("table_classes(:scroll)\n", ruby_uri, stub_no_typechecker: true, load_addons: true) do |server, uri|
      server.global_state.index.index_single(URI::Generic.from_path(path: "/fake/table_helper.rb"), HELPER)
      server.process_message({
        id: 1,
        method: "textDocument/hover",
        params: { textDocument: { uri: uri }, position: { line: 0, character: 3 } },
      })
      assert_nil pop_result(server).response

      server.process_message({
        id: 2,
        method: "textDocument/completion",
        params: { textDocument: { uri: uri }, position: { line: 0, character: 8 } },
      })
      refute_includes pop_result(server).response.map(&:label), "table_classes"
    end
  end

  def test_requests_at_host_positions_are_not_delegated_to_the_html_service
    with_slim_server do |server, uri|
      # The VS Code client advertises request delegation; for ERB that sends host-language positions to the editor's
      # HTML service, which cannot serve a Slim file
      server.global_state.client_capabilities.instance_variable_set(:@supports_request_delegation, true)
      server.process_message({
        id: 1,
        method: "textDocument/hover",
        params: { textDocument: { uri: uri }, position: { line: 2, character: 1 } },
      })

      assert_nil pop_result(server).response
    end
  end

  def test_activation_registers_slim_documents_with_the_editor
    with_server(load_addons: true) do |server, _uri|
      queue = server.instance_variable_get(:@outgoing_queue)
      messages = []
      messages << server.pop_response until queue.empty?

      registration = messages.find { |m| m.is_a?(RubyLsp::Request) && m.method == "client/registerCapability" }
      refute_nil registration, "no client/registerCapability request was sent"
      registrations = registration.params.registrations
      by_method = registrations.to_h { |r| [r.method, r.register_options] }

      ["textDocument/didOpen", "textDocument/didChange", "textDocument/definition", "textDocument/hover",
       "textDocument/completion", "textDocument/semanticTokens", "textDocument/documentSymbol",].each do |method|
        assert_includes by_method.keys, method
      end
      selector = RubyLsp::Slim::EditorRegistration::SELECTOR
      assert(by_method.values.all? { |options| options[:documentSelector] == selector })
      assert_equal RubyLsp::Constant::TextDocumentSyncKind::INCREMENTAL, by_method["textDocument/didChange"][:syncKind]
      assert_includes by_method["textDocument/completion"][:triggerCharacters], "."
      assert_includes by_method["textDocument/semanticTokens"][:legend].to_hash[:tokenTypes].map(&:to_s), "method"
      assert registrations.map(&:id).uniq.length == registrations.length, "registration ids must be unique"

      log = messages.find { |m| m.is_a?(RubyLsp::Notification) && m.method == "window/logMessage" }
      assert_match(/ruby-lsp-slim #{ RubyLsp::Slim::VERSION }/, log.params.message)
    end
  end

  def test_a_builder_named_local_the_template_only_declares_is_a_form_builder
    with_slim_server do |server, uri|
      server.process_message({
        id: 1,
        method: "textDocument/hover",
        params: { textDocument: { uri: uri }, position: { line: 4, character: 8 } },
      })
      markdown = pop_result(server).response.contents.value

      assert_includes markdown, "number_field(method, options = <default>)"
      assert_includes markdown, "A number input for the attribute"
      assert_includes markdown, "Guessed receiver: ActionView::Helpers::FormBuilder"
    end
  end

  def test_a_block_parameter_named_like_a_builder_resolves_too
    with_slim_server do |server, uri|
      server.process_message({
        id: 1,
        method: "textDocument/definition",
        params: { textDocument: { uri: uri }, position: { line: 6, character: 12 } },
      })

      assert_equal ["file:///fake/form_builder.rb"], pop_result(server).response.map(&:target_uri)
    end
  end

  def test_simple_form_builder_wins_when_indexed
    with_slim_server do |server, uri|
      simple_form = "module SimpleForm\n  class FormBuilder < ActionView::Helpers::FormBuilder\n  end\nend\n"
      server.global_state.index.index_single(URI::Generic.from_path(path: "/fake/simple_form.rb"), simple_form)
      server.process_message({
        id: 1,
        method: "textDocument/hover",
        params: { textDocument: { uri: uri }, position: { line: 4, character: 8 } },
      })

      assert_includes pop_result(server).response.contents.value, "Guessed receiver: SimpleForm::FormBuilder"
    end
  end

  def test_builder_names_in_ruby_files_are_left_to_the_ruby_lsp
    ruby_uri = URI::Generic.from_path(path: "/fake/app/views/table.rb")
    with_server("f.number_field(:volume)\n", ruby_uri, stub_no_typechecker: true, load_addons: true) do |server, uri|
      server.global_state.index.index_single(URI::Generic.from_path(path: "/fake/form_builder.rb"), FORM_BUILDER)
      server.process_message({
        id: 1,
        method: "textDocument/hover",
        params: { textDocument: { uri: uri }, position: { line: 0, character: 4 } },
      })

      assert_nil pop_result(server).response
    end
  end

  private

  def with_slim_server(&block)
    uri = URI::Generic.from_path(path: "/fake/app/views/table.html.slim")
    with_server(nil, uri, stub_no_typechecker: true, load_addons: true) do |server, _uri|
      helper = <<~RUBY
        #{ HELPER }
        module TitleHelper
          def title_for(rows) = rows.size.to_s
        end
      RUBY
      server.global_state.index.index_single(URI::Generic.from_path(path: "/fake/table_helper.rb"), helper)
      server.global_state.index.index_single(URI::Generic.from_path(path: "/fake/form_builder.rb"), FORM_BUILDER)
      server.process_message({
        method: "textDocument/didOpen",
        # mutable, as a document arrives from JSON: the server applies edits to the source in place
        params: { textDocument: { uri: uri, text: TEMPLATE.dup, version: 1, languageId: "erb" } },
      })
      block.call(server, uri)
    end
  end
end
