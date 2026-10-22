# Neovim document previews

- Markview renders Markdown and math symbols in the document.
- `image.nvim` uses the **Sixel** backend for directly opened images and Markdown
  image-link popups. Move the cursor onto an image-link line to preview it. Local
  paths are relative to the document; HTTP(S) images are downloaded automatically.
- `lua/math_popup.lua` detects the math expression under the cursor with
  Tree-sitter, compiles it to PNG, then displays it in an `image.nvim` floating
  window. It supports Markdown `$…$` / `$$…$$` and math nodes in TeX buffers.
- `lua/sixel_transport.lua` routes image.nvim's Sixel packets through Neovim
  0.12's `nvim_ui_send()` instead of writing directly to the stderr channel
  (see `:h nvim_ui_send()`). The compatibility shim only matches complete Sixel
  packets; ordinary stderr and other protocols are untouched. It also uses
  tmux's native image handling when `#{sixel_support}` reports `1`; other tmux
  builds retain the original passthrough wrapper. Automatic repaint retries are
  not used.
- Snacks image support is disabled entirely so image files and document previews
  have a single handler (`image.nvim`/Sixel), without competing Kitty-protocol output.

## Requirements

- A Sixel-capable terminal; tmux must also pass Sixel output through.
- `tree-sitter` CLI and a C compiler for parser installation. The configuration
  installs `markdown`, `markdown_inline`, and `latex` using `nvim-treesitter`.
- `pdflatex`, ImageMagick (`magick`, with PDF decoding support), and its PDF
  delegate (normally Ghostscript).
- LaTeX packages: `standalone`, `amsmath`, `amssymb`, `amsfonts`, `mathtools`,
  and `xcolor`.

## Math popup behavior

Popups appear in normal mode after a 250 ms pause. Moving the cursor, editing,
entering insert mode, scrolling, or leaving the window closes the math popup.
Cursor movement, edits, scrolling the source window, and resizing recheck the
expression after that pause. A single cancellable debounce timer handles cursor
bursts; unrelated filetypes do not schedule previews. Entering insert mode or
leaving the source window cancels an in-flight conversion. Layout changes in
unrelated windows are ignored.
Repeated expressions reuse PNGs from `stdpath("cache")/math-popup/`; the key
includes the expression and foreground/background colors.

Conversions are asynchronous, use a 15-second timeout per command, disable TeX
shell escape, and restrict TeX file access. This is **not a full TeX sandbox**;
only preview trusted documents. Source-document preambles, custom macros,
external files, and arbitrary package declarations are not imported.

A conversion failure produces a warning pointing to a `.log` in the same cache
directory instead of opening an empty popup. The failed expression is not retried
in the current session; edit it or restart Neovim after fixing dependencies.

## Intermittent missing/black previews

`window_overlap_clear_enabled` is deliberately **false** for Sixel. In the
installed image.nvim version, overlap polling repeatedly renders images that
have not yet been painted, resetting the backend's 50 ms flush timer. With
ongoing redraws this can prevent Sixel transmission entirely. The trade-off is
that image.nvim no longer automatically hides an image behind overlapping UI
windows. Math popups still close when leaving their source window.

Run `:PreviewDebugStart`, reproduce both a working and a missing preview, then
run `:PreviewDebugStop`. The diagnostic file is
`stdpath("cache")/document-preview.log`. It combines image.nvim's renderer/backend
logs with math detection, cache/conversion, popup opening/closing, and stale-result
cancellation events. Logging is off by default. The log may contain image paths
and URLs; review it before sharing. These logs can distinguish a missing render
request from a successful Sixel send, but cannot prove the terminal displayed it.

## Checks

```sh
nvim --headless -u NONE -l nvim/tests/math_popup.lua
nvim --headless -u NONE -l nvim/tests/sixel_transport.lua
python3 nvim/tests/sixel_flush.py
```

The test uses actual installed parsers and actual `pdflatex`/`magick` conversion,
but mocks terminal image drawing. It checks inline/block math, TeX environments,
cache reuse, bounded debounce timers, conversion cancellation, errors, and
stale-popup cleanup. The Python regression
starts a real Neovim TUI in a private PTY and exercises the actual image transform
and Sixel flush scheduling during redraws, comparing the old overlap setting
against the current configuration. It captures real TUI terminal output and
checks that an intact Sixel packet is delivered through `nvim_ui_send()`. A PTY
is not a graphics decoder, so visual Sixel output must still be checked in an
interactive terminal.

For the full interactive checklist, run `nvim nvim/preview-test.md` from the
repository root. It uses the existing wallpaper as a local image and includes a
remote image (requires internet), inline/block math, matrices, and aligned equations.

For a minimal manual check, open a Markdown file containing:

```markdown
![Local image](./example.png)

Inline math: $\alpha + x^2$.

$$
\sum_{i=1}^{n} i = \frac{n(n+1)}{2}
$$
```

Move onto the image-link line, then into the inline and block formulas. Check
that each popup contains an image and closes on moving away. `<Space>mp` toggles
Markview's document rendering; `<Space>ms` toggles its split preview.
