# 002 — upload routing

**Applied:** yes — built into the image, see `Dockerfile`
**Type:** A + B (see the rule in the repository README)
**Base:** v0.8.7
**Upstream status:** open — [PR #11279](https://github.com/danny-avila/LibreChat/pull/11279) (draft since Jan 2026)

## What upstream does

Which upload methods the attachment menu offers is decided by a hardcoded set,
`documentSupportedProviders` in `packages/data-provider/src/schemas.ts`. It
contains `custom`, so **every** custom endpoint is offered "Upload to provider",
whether or not the model behind it can read files.

A single custom endpoint routinely serves models with very different
capabilities. One reads images, the next is text-only. For the text-only one
that menu entry is a dead end, and it is the first entry in the list. Users pick
it and get an opaque provider error.

The menu is also the only thing standing between a user and the wrong path.
Nothing in it reacts to the file: the choice is made before the file picker even
opens, and the same three entries appear for a spreadsheet and for a photo.

## Part A — the switches

Four opt-outs, configurable per endpoint **and** per model spec, resolved most
specific first (spec → endpoint → enabled):

```yaml
fileConfig:
  endpoints:
    MyEndpoint:
      uploadMethods:
        provider: false      # hide "Upload to Provider" and "Upload Image"
        context: false       # hide "Upload as Text"
        file_search: false   # hide "Upload for File Search"
        execute_code: false  # hide "Upload to Code Environment"

modelSpecs:
  list:
    - name: my-text-only-model
      uploadMethods:
        provider: false      # overrides the endpoint setting
```

With nothing configured the behaviour is byte-for-byte what it was. A switch can
only ever **remove** an option: a method the capability check withholds stays
hidden regardless.

`uploadMethodsSchema` is `.strict()`. The tool switches on a model spec are
camelCase (`fileSearch`, `executeCode`) while these are snake_case; a non-strict
object would drop `fileSearch: false` here without a word, leaving the option in
the menu and no clue why.

## Part B — routing by file type

```yaml
uploadMethods:
  autoRoute: true    # default false
```

This one changes behaviour rather than exposing a value, which is why it has to
be switched on. With `autoRoute` unset every path behaves as upstream.

Switched on:

- the attachment button opens the file picker directly, with no menu;
- a drop or a paste uploads straight away, with no dialog;
- **each file is routed on its own**, by MIME type and extension, through the
  same `getAvailableUploadOptions` that would have populated the menu.

Precedence among several applicable methods is the order the menu would have
listed them. A deployment that wants a different winner switches the loser off,
so "what is on offer here" keeps a single source of truth.

Files that no method can take are rejected with a message rather than sent down
a path that cannot accept them.

The Excel case, end to end:

```yaml
- name: spreadsheet-agent
  uploadMethods:
    provider: false
    context: false
    autoRoute: true
```

A dropped `.xlsx` now lands in the code environment without anyone choosing
anything — which is what the instruction "please click the paperclip and choose
Upload to Code Environment, the other options fail for .xlsx" in a model
description was standing in for.

### Scope

`assistants`/`azureAssistants` endpoints and the agent builder side panel have
their own upload flows and are deliberately **not** covered.

This is a surface, not an access control. The server does not enforce it.

## Contents

| File | Purpose |
|---|---|
| `002-upload-routing.patch` | `git diff` against `v0.8.7`, 26 files |
| `upstream.sha256` | checksums of the 18 pre-existing files it touches |

Verify it still applies:

```bash
git clone --depth 1 --branch v0.8.7 https://github.com/danny-avila/LibreChat.git
cd LibreChat && git apply --check ../patches/002-upload-routing/002-upload-routing.patch
```

Or reconstruct a full working tree with `tools/worktree.sh v0.8.7`.

## Why the image is built rather than copied

The decision lives in the React client, and the official image ships only
`client/dist`. Copying a source file into it changes nothing. The Dockerfile
therefore fetches the source at the base tag, applies this patch and runs
`npm run frontend`, then places both `client/dist` **and**
`packages/data-provider/dist` into the final image. The second one is easy to
miss: the schema and the resolution helper live there, and the server reads them
too.
