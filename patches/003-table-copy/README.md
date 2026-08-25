# 003 — table copy

**Applied:** yes — built into the image, see `Dockerfile`
**Type:** B (off-by-default switch, see the rule in the repository README)
**Base:** v0.8.7
**Upstream status:** not offered yet

## What upstream does

A rendered markdown table is a bare `<table>`. Copying it means selecting it by
hand, and pasting that into Excel or Word produces one run of scrambled text.
The complaint, verbatim from a user's feedback document (May 2026):

> „Bei LieberChat muss man dagegen die ganze Tabelle manuell markieren, und wenn
> man sie einfügt, wird alles durcheinander."

## What this patch changes

```yaml
interface:
  tableCopy: true   # default: off
```

Switched on, every rendered table gets a copy button (visible on hover and on
keyboard focus). One click writes the table to the clipboard **twice in one
item**: as `text/html`, which is what lets Excel and Word paste a real table,
and as tab-separated `text/plain` for editors and terminals. The HTML copy is
stripped of the renderer's classes and styles — structure, text, `colspan` and
`rowspan` survive, everything else goes.

With `tableCopy` unset the table renders character for character as upstream.

## Contents

| File | Purpose |
|---|---|
| `003-table-copy.patch` | `git diff` against `v0.8.7`, 4 files |
| `upstream.sha256` | checksums of the 2 pre-existing files it touches |

Touches `packages/data-provider/src/config.ts` (the `interface` schema — the
top-level config parse is `.strict()`, so an unknown key would be a startup
error, not a silent no-op) and the markdown table component. Reuses the existing
`com_ui_copy_to_clipboard` translation key, so no locale files change.
