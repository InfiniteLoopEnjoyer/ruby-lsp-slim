# Changelog

## Unreleased

- The add-on registers Slim documents with the editor itself (`client/registerCapability` for text synchronisation
  and every feature the Ruby LSP offers ERB), so the stock Ruby LSP extension sends `.slim` files to the server with no
  `files.associations` entry and no client patch. A `slim` language id is picked up when present; otherwise the path
  pattern `**/*.slim` matches.
- Logs an activation line to the Ruby LSP output channel.
- Example application under `examples/` for trying the add-on by hand.

## 0.1.0

- Slim documents in the Ruby LSP: an `ERBDocument` with a scanner that follows Slim's line indicators (control and
  output lines, broken lines, Ruby attribute values, splats, wrapped attribute lists, quoted-value interpolation, text
  and comment blocks, embedded filters), keyed on the `.slim` extension whatever language id the client sends.
- Hover and completion for calls without a receiver, which the Ruby LSP otherwise answers with nothing in a template.
- Requests at host-language positions stay with the Ruby LSP instead of being delegated to the editor's HTML service.
- A grammar-only VS Code extension contributing the `slim` language with the ruby-slim.tmbundle grammar.
