# frozen_string_literal: true

module RubyLsp
  module Slim
    # Reads a template line by line, following Slim::Parser's own line indicators, and records which characters are
    # Ruby. The result is two strings the length of the source: `ruby` keeps the Ruby and blanks the rest,
    # `host_language` the reverse. Keeping every character in place is what lets Prism's offsets double as editor
    # positions, exactly as the Ruby LSP's own ERB scanner does.
    class Scanner
      attr_reader :ruby, :host_language

      ENGINES = ["asciidoc", "markdown", "textile", "rdoc", "coffee", "sass", "scss", "javascript", "css", "ruby"]
      EMBEDDED_RE = /\A(#{ Regexp.union(ENGINES) })(?:\s*(?:(.*)))?:(\s*)/
      # A tag name, a `*splat` tag or a `.class`/`#id` shortcut; only the name is consumed (group 1)
      TAG_RE = /\A(?:[.#]|\*(?=\S)|(\p{Word}(?:\p{Word}|:|-)*\p{Word}|\p{Word}+))/
      ATTR_SHORTCUT_RE = /\A([.#]+)((?:\p{Word}|-|\/\d+|:(\w|-)+)*)/
      ATTR_NAME = /[^\0\s"'<>\/=()\[\]{}]+/
      QUOTED_ATTR_RE = /\A\s*(#{ ATTR_NAME })\s*=(=?)\s*("|')/
      CODE_ATTR_RE = /\A\s*(#{ ATTR_NAME })\s*=(=?)\s*/
      SPLAT_RE = /\A\s*\*(?=\S)/
      DELIMS = { "(" => ")", "[" => "]", "{" => "}" }

      def initialize(source)
        @source = source
        @ruby = +""
        @host_language = +""
        @mask = Array.new(source.length, false)
        # An indented block owned by one line: its deeper lines are text, a comment or (`ruby:`) Ruby
        @block = nil
        # How the next line carries this one on: :code after a trailing `,` or `\`, or an attribute list's state
        @pending = nil
      end

      def scan
        offset = 0
        @source.each_line do |raw|
          scan_line(raw.chomp, offset)
          offset += raw.length
        end

        @source.each_char.with_index do |char, index|
          if char == "\n" || char == "\r"
            @ruby << char
            @host_language << char
          elsif @mask[index]
            @ruby << char
            @host_language << " "
          else
            @ruby << " "
            @host_language << char
          end
        end
        self
      end

      private

      def scan_line(line, offset)
        indent = line[/\A[ \t]*/].length
        return if indent == line.length

        if @pending
          if @pending == :code
            mark(offset + indent, offset + line.length)
            @pending = nil unless broken?(line)
          else
            scan_attributes(line, offset, indent, @pending)
          end
          return
        end

        if @block
          if indent > @block[:indent]
            case @block[:kind]
            when :ruby then mark(offset + indent, offset + line.length)
            when :text then mark_interpolations(line, offset, indent)
            end
            return
          end
          @block = nil
        end

        content = line[indent..]
        case content
        when /\A\/\[/ # conditional comment: its children are ordinary Slim
          nil
        when /\A\// # HTML or Slim comment
          @block = { kind: :host, indent: indent }
        when /\A[|']/ # verbatim text
          @block = { kind: :text, indent: indent }
          mark_interpolations(line, offset, indent + 1)
        when /\A</ # inline HTML
          mark_interpolations(line, offset, indent)
        when /\A-/ # control code
          ruby_line(line, offset, indent + 1)
        when /\A=(=?)([<>]*)/ # output code
          ruby_line(line, offset, indent + $&.length)
        when EMBEDDED_RE
          @block = { kind: $1 == "ruby" ? :ruby : :host, indent: indent }
        when /\Adoctype\b/
          nil
        else
          scan_tag(line, offset, indent)
        end
      end

      # Ruby to the end of the line, carried on to the next by a trailing `,` or `\` (Slim's "broken line")
      def ruby_line(line, offset, from)
        mark(offset + from, offset + line.length)
        @pending = :code if broken?(line)
      end

      def broken?(line)
        line.rstrip.end_with?(",", "\\")
      end

      def scan_tag(line, offset, col)
        match = TAG_RE.match(line[col..])
        return unless match

        col += match[1].length if match[1]
        while (shortcut = ATTR_SHORTCUT_RE.match(line[col..]))
          col += shortcut[0].length
        end
        col += line[col..][/\A[<>']*/].length

        state = { delim: nil }
        if (wrapper = /\A\s*([(\[{])/.match(line[col..]))
          state[:delim] = DELIMS[wrapper[1]]
          col += wrapper[0].length
        end
        scan_attributes(line, offset, col, state)
      end

      # A tag's attributes from `col` on, then whatever follows them on the line. `state` carries the list across
      # lines: the wrapper's closing delimiter, and a Ruby or quoted value cut by a line break.
      def scan_attributes(line, offset, col, state)
        if state[:code]
          col = scan_ruby_value(line, offset, col, state) or return
        elsif state[:quote]
          col = scan_quoted_value(line, offset, col, state) or return
        end

        loop do
          rest = line[col..]
          if (match = SPLAT_RE.match(rest))
            col = scan_ruby_value(line, offset, col + match[0].length, state) or return
          elsif (match = QUOTED_ATTR_RE.match(rest))
            state[:quote] = match[3]
            state[:braces] = 0
            state[:interpolating] = false
            col = scan_quoted_value(line, offset, col + match[0].length, state) or return
          elsif (match = CODE_ATTR_RE.match(rest))
            col = scan_ruby_value(line, offset, col + match[0].length, state) or return
          elsif state[:delim].nil?
            break
          elsif (match = /\A\s*#{ ATTR_NAME }(?=\s|#{ Regexp.escape(state[:delim]) }|\z)/.match(rest)) # boolean
            col += match[0].length
          elsif (match = /\A\s*#{ Regexp.escape(state[:delim]) }/.match(rest))
            col += match[0].length
            state[:delim] = nil
            break
          else
            # A wrapped attribute list goes on on the next line
            @pending = state
            return
          end
        end

        @pending = nil
        scan_tag_tail(line, offset, col)
      end

      # A Ruby attribute value: up to the first whitespace, or the wrapper's delimiter, outside brackets. A line whose
      # remainder is just `,` or `\` carries the value on to the next line.
      def scan_ruby_value(line, offset, col, state)
        code = state[:code] ||= { depth: 0, open: nil, close: nil }
        from = col
        while col < line.length
          if line[col..].match?(/\A[,\\]\z/)
            mark(offset + from, offset + line.length)
            @pending = state
            return nil
          end

          char = line[col]
          if code[:depth].zero?
            break if char.match?(/\s/) || char == state[:delim]

            if DELIMS.key?(char)
              code[:open] = char
              code[:close] = DELIMS[char]
              code[:depth] = 1
            end
          elsif char == code[:open]
            code[:depth] += 1
          elsif char == code[:close]
            code[:depth] -= 1
          end
          col += 1
        end

        mark(offset + from, offset + col)
        state[:code] = nil
        col
      end

      # A quoted attribute value, which may run over several lines, with Ruby inside its #{ } interpolations
      def scan_quoted_value(line, offset, col, state)
        while col < line.length
          char = line[col]
          if state[:braces].zero? && char == state[:quote]
            state[:quote] = nil
            return col + 1
          end

          if char == "{"
            state[:braces] += 1
            if state[:braces] == 1
              state[:interpolating] = col > 0 && line[col - 1] == "#"
              col += 1
              next
            end
          elsif char == "}"
            state[:braces] -= 1
            if state[:braces].zero?
              state[:interpolating] = false
              col += 1
              next
            end
          end
          mark(offset + col, offset + col + 1) if state[:interpolating]
          col += 1
        end

        @pending = state
        nil
      end

      def scan_tag_tail(line, offset, col)
        rest = line[col..]
        case rest
        when /\A\s*:\s*/ # block expansion: another tag on the same line
          scan_tag(line, offset, col + $&.length)
        when /\A\s*=(=?)(['<>]*)/ # output code
          ruby_line(line, offset, col + $&.length)
        when /\A\s*\/\s*/, /\A\s*\z/ # closed tag, no content
          nil
        else # inline text
          mark_interpolations(line, offset, col)
        end
      end

      # Ruby inside the #{ } interpolations of text
      def mark_interpolations(line, offset, col)
        while (start = line.index('#{', col))
          col = start + 2
          next if start > 0 && line[start - 1] == "\\"

          depth = 1
          while col < line.length && depth > 0
            depth += 1 if line[col] == "{"
            depth -= 1 if line[col] == "}"
            col += 1
          end
          mark(offset + start + 2, offset + col - (depth.zero? ? 1 : 0))
        end
      end

      def mark(from, to)
        @mask.fill(true, from, to - from) if to > from
      end
    end
  end
end
