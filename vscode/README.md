# Ruby LSP Slim (VS Code)

The editor half of the [ruby-lsp-slim](../README.md) gem: a `slim` language with the MIT
[ruby-slim.tmbundle](https://github.com/slim-template/ruby-slim.tmbundle) grammar, comment toggling, bracket pairs,
indentation folding and Ruby-aware indent rules. It has no code of its own: the gem registers Slim documents with the
Ruby LSP extension at runtime, and this extension gives them a language and a grammar.

Install from a checkout with **Developer: Install Extension from Location...** and pick this folder, or package it
with `npx @vscode/vsce package` and install the `.vsix`.
