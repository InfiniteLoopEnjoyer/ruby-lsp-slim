# ruby-lsp-slim

A [Ruby LSP](https://github.com/Shopify/ruby-lsp) add-on for [Slim](https://slim-template.github.io) templates:
go to definition, hover, completion, semantic highlighting and the rest of the Ruby LSP's features for the Ruby
inside `.slim` files. It is the Slim counterpart of the Ruby LSP's built-in ERB support, answering
[Shopify/ruby-lsp#1233](https://github.com/Shopify/ruby-lsp/issues/1233).

## Installation

Add the gem to the development group of your application's `Gemfile` and `bundle install`:

```ruby
group :development do
  gem "ruby-lsp-slim", require: false
end
```

Restart the Ruby LSP from your editor. On activation the add-on registers Slim documents with the editor itself
(`client/registerCapability`, for text synchronisation and every feature the Ruby LSP offers ERB), so the stock Ruby
LSP extension starts sending `.slim` files to the server — no settings, no patched extension. The registration matches
by the `slim` language id when the editor has one, and by the `**/*.slim` path otherwise, so it works even on files
the editor shows as plain text.

**VS Code** — for Slim syntax highlighting, comment toggling and indentation, install the grammar-only extension in
[vscode/](vscode/) (**Developer: Install Extension from Location...**, or `npx @vscode/vsce package` and install the
`.vsix`), or any extension that contributes the `slim` language.

**Other editors** — any client that honours dynamic registration works. One that does not can still be told to open
`.slim` files as `erb` (or `eruby`): the add-on keys on the file extension, not the language id.

## What you get

Everything the Ruby LSP offers inside ERB files, on the Ruby that Slim would evaluate:

- control and output lines (`- code`, `= code`, `== code`), including lines broken with a trailing `,` or `\`
- Ruby attribute values (`div class=classes(:x)`), splats (`*attrs`), wrapped attribute lists over several lines
- `#{ }` interpolations in text, verbatim blocks and quoted attribute values
- `ruby:` embedded blocks

A call without a receiver, such as `= icon(:lock)` or `div class=table_classes(:scroll)`, is the common case in a
template, and the Ruby LSP cannot infer its receiver there (it sees `Object`). Go to definition offers every method of
that name in the index, as it does in ERB; the add-on makes hover and completion do the same, so hovering a helper
shows its signature, documentation and definition links, and typing a prefix offers the project's methods (locals,
keywords and `Object`'s methods still come from the Ruby LSP). Calls with a receiver (`Model.find`, `@user.name`)
work as in any Ruby file.

A form builder is the other receiver a template is full of, and the Ruby LSP cannot type it: `f`, `form`, `builder`,
`fields` or any `*_form`/`*_builder`/`*_fields` local — a block parameter, or a local the template only declares —
is taken as `SimpleForm::FormBuilder` when that is in the index, `ActionView::Helpers::FormBuilder` otherwise, as a
guessed receiver (hover says so), so `f.number_field` hovers, completes and jumps into Action View. Nothing changes in
`.rb` or `.erb` files.

## Highlighting

Two layers: the grammar extension colours Slim itself (tags, attributes, text, filters), and the Ruby LSP's semantic
tokens colour the Ruby inside it, exactly as in a Ruby file.

## How it works

The Ruby LSP's `ERBDocument` replaces every character outside `<% %>` with a space, so the Ruby string it parses has
exactly the layout of the template and Prism's offsets double as editor positions. `RubyLsp::Slim::Document` is an
`ERBDocument` with that scan swapped for one that follows Slim's line indicators, and `RubyLsp::Slim::Scanner` is that
scan. A small extension to the server's document store builds a Slim document for any `.slim` path, whatever language
id the editor sent.

Slim omits `end`, so the Ruby handed to Prism is never complete; Prism's error-tolerant parse carries it. Blocks
nest wrongly past a dedent, but every node stays in place, which is what navigation needs. The Ruby LSP does not
compute diagnostics or formatting for ERB-derived documents, so none of that shows up in the editor, and requests at
host-language positions stay with the server instead of being delegated to the editor's HTML service as ERB's are.

## See also

[afomera/ruby-lsp-slim](https://github.com/afomera/ruby-lsp-slim) takes the same approach on the server and runs a
second, dedicated Ruby LSP process for Slim files on the editor side.

## Development

```sh
bundle install
bundle exec rake   # tests, then RuboCop
```

`examples/` holds a helper and a template to try things on by hand.

## License

MIT, see [LICENSE.txt](LICENSE.txt).
