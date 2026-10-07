# Ruby LSP Slim (VS Code)

The editor half of the [ruby-lsp-slim](../README.md) gem: a `slim` language with the MIT
[ruby-slim.tmbundle](https://github.com/slim-template/ruby-slim.tmbundle) grammar, comment toggling, bracket pairs,
indentation folding and Ruby-aware indent rules. It has no code of its own.

It is only useful once the Ruby LSP's VS Code extension sends `slim` documents to the server — see "Highlighting" in
the gem's README for where that stands. Until then the `files.associations` route (Slim as ERB) is what works, and
installing this extension changes nothing for those files.

Install from a checkout with **Developer: Install Extension from Location...** and pick this folder, or package it
with `npx @vscode/vsce package` and install the `.vsix`.
