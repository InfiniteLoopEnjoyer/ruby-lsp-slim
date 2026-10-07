# frozen_string_literal: true

require_relative "test_helper"

class ScannerTest < Minitest::Test
  def test_ruby_and_host_keep_every_character_in_place
    source = <<~SLIM
      .card id=dom_id(model) class="row \#{ cycle("a", "b") } wide" data-x='1'
        p.note = greeting(user)
        | Hello \#{ user.name }!
    SLIM
    scanner = RubyLsp::Slim::Scanner.new(source).scan

    assert_equal source.length, scanner.ruby.length
    assert_equal source.length, scanner.host_language.length
    source.each_char.with_index do |char, index|
      ruby, host = scanner.ruby[index], scanner.host_language[index]
      if char == "\n"
        assert_equal [char, char], [ruby, host]
      else
        assert_includes [[char, " "], [" ", char]], [ruby, host], "character #{ index } is in neither or both sources"
      end
    end
  end

  def test_every_construct
    source = <<~SLIM
      doctype html
      / comment
        with more
      /! html comment
      .card id=dom_id(model) class="row \#{ cycle("a", "b") } wide" data-x='1'
        | Hello \#{ user.name }!
          and \#{ more }
        p = greeting(user),
            formal: true
        - if user.admin?
          span #
          span.badge Admin
        ruby:
          total = 1 +
            2
        a(href=url_for(model)
          class="link") = model.name
        html lang='en' *theme_html_attributes(current_user)
        footer.flex.md:flex-row style="url('\#{ asset_path 'x.png' }');"
        li: a href=root_path Home
        input type="checkbox" checked=item.done?
        javascript:
          console.log("not ruby")
        == raw_html
        =< spaced
    SLIM
    expected = [
      "",
      "", "",
      "",
      'dom_id(model) cycle("a", "b")',
      "user.name",
      "more",
      "greeting(user),",
      "formal: true",
      "if user.admin?",
      "",
      "",
      "",
      "total = 1 +",
      "2",
      "url_for(model)",
      "model.name",
      "theme_html_attributes(current_user)",
      "asset_path 'x.png'",
      "root_path",
      "item.done?",
      "",
      "",
      "raw_html",
      "spaced",
    ]

    assert_equal expected, ruby_lines(source)
  end

  def test_host_keeps_what_ruby_drops
    source = "div class=classes(:x) data-a='1' Text\n"
    scanner = RubyLsp::Slim::Scanner.new(source).scan

    assert_equal "          classes(:x)", scanner.ruby.lines.first.rstrip
    assert_equal "div class=            data-a='1' Text", scanner.host_language.lines.first.rstrip
  end

  def test_wrapped_attributes_over_several_lines
    source = <<~SLIM
      div(
        id=dom_id(model)
        class="x"
        data-value={ a: 1,
                     b: 2 }
        disabled
      ) = body
    SLIM

    assert_equal ["", "dom_id(model)", "", "{ a: 1,", "b: 2 }", "", "body"], ruby_lines(source)
  end

  def test_a_broken_scan_degrades_to_no_ruby
    document = RubyLsp::Slim::Document.new(
      source: "- 1 +\n",
      version: 1,
      uri: URI::Generic.from_path(path: "/fake/x.html.slim"),
      global_state: RubyLsp::GlobalState.new,
    )

    assert_equal "  1 +\n", document.parse_result.source.source
  end

  private

  def ruby_lines(source)
    RubyLsp::Slim::Scanner.new(source).scan.ruby.lines.map { |line| line.strip.squeeze(" ") }
  end
end
