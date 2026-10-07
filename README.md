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

The Ruby LSP discovers the add-on on its next start (restart the server from your editor).

### Tell your editor to send Slim files to the server

This is the one manual step, and it is needed because of the client, not the server: the Ruby LSP extensions only
hand `ruby` and `erb` documents to the language server, so a Slim file never reaches it. Have the editor present
`.slim` files as ERB and the add-on takes over from there, keyed on the `.slim` extension.

**VS Code** — in `.vscode/settings.json` (or your user settings):

```json
{
  "files.associations": {
    "*.slim": "erb"
  }
}
```

The trade-off: the file gets VS Code's ERB grammar, so there is no Slim-aware syntax highlighting (the Ruby LSP's
semantic highlighting still colours the Ruby parts). See [Highlighting](#highlighting) for the way out.

**Other editors** — any client works as long as it opens `.slim` files with the language id `erb` (or `eruby`), or
with any language id at all if the client can be told to send `.slim` files: the add-on keys on the extension.

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
keywords and `Object`'s methods still come from the Ruby LSP). Calls with a receiver (`f.text_field`, `Model.find`)
work as in any Ruby file. Nothing changes in `.rb` or `.erb` files.

## Highlighting

With the `files.associations` route the editor has no Slim grammar, because the language id decides both the grammar
and what the Ruby LSP extension sends to the server. The fix is to send `slim` documents as such:

1. Install the grammar-only extension in [vscode/](vscode/) (**Developer: Install Extension from Location...**, or
   `npx @vscode/vsce package` and install the `.vsix`). It contributes the `slim` language with the MIT
   [ruby-slim.tmbundle](https://github.com/slim-template/ruby-slim.tmbundle) grammar.
2. Have the Ruby LSP extension send `slim` documents. Its language list is a constant,
   `SUPPORTED_LANGUAGE_IDS = ["ruby", "erb"]` in `vscode/src/common.ts`, used only to build the client's
   `documentSelector` in `collectClientOptions` (`vscode/src/client.ts`). Upstream, a setting such as
   `rubyLsp.additionalLanguageIds` appended there would do it; until then, the installed extension can be patched in
   place — in `out/extension.js` of `shopify.ruby-lsp-*`, change `["ruby","erb"]` to `["ruby","erb","slim"]` (an
   extension update undoes it).
3. Remove the `files.associations` entry and reload the window.

The server side needs nothing: the add-on keys on the `.slim` extension, whatever language id arrives.

## How it works

The Ruby LSP's `ERBDocument` replaces every character outside `<% %>` with a space, so the Ruby string it parses has
exactly the layout of the template and Prism's offsets double as editor positions. `RubyLsp::Slim::Document` is an
`ERBDocument` with that scan swapped for one that follows Slim's line indicators, and `RubyLsp::Slim::Scanner` is that
scan. A small extension to the server's document store builds a Slim document for any `.slim` path, whatever language
id the editor sent.

Slim omits `end`, so the Ruby handed to Prism is never complete; Prism's error-tolerant parse carries it. Blocks
nest wrongly past a dedent, but every node stays in place, which is what navigation needs. The Ruby LSP does not
compute diagnostics or formatting for ERB-derived documents, so none of that shows up in the editor.

## Development

```sh
bundle install
bundle exec rake
```

## License

MIT, see [LICENSE.txt](LICENSE.txt).
