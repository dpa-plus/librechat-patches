# 002 — configurable upload methods

**Applied:** no — requires a client rebuild, see below
**Upstream status:** open — [PR #11279](https://github.com/danny-avila/LibreChat/pull/11279) (draft since Jan 2026)
**Base:** v0.8.7

## What upstream does

Which upload methods the attachment menu offers is decided by a hardcoded set,
`documentSupportedProviders` in `packages/data-provider/src/schemas.ts`. It
contains `custom`, so **every** custom endpoint is offered "Upload to provider",
whether or not the model behind it can read files.

A single custom endpoint routinely serves models with very different
capabilities. One reads images, the next is text-only. For the text-only one
that menu entry is a dead end, and it is the first entry in the list. Users pick
it and get an opaque provider error.

## What this patch changes

Two opt-out switches, configurable per endpoint **and** per model spec, resolved
most specific first (spec → endpoint → enabled):

```yaml
fileConfig:
  endpoints:
    MyEndpoint:
      uploadMethods:
        provider: false     # hide "Upload to provider"
        context: false      # hide "Upload as text"

modelSpecs:
  list:
    - name: my-text-only-model
      uploadMethods:
        provider: false     # overrides the endpoint setting
```

With nothing configured the behaviour is byte-for-byte what it was. The switches
can only ever **remove** an option: a method the provider cannot do stays hidden
regardless.

All four conversation upload paths resolve through one pure function,
`getAvailableUploadOptions`: the attachment menu, the decision whether a drop
dialog opens at all, the dialog itself, and clipboard paste. If no option
remains for the given files, the drop is rejected with a message rather than
silently uploaded or shown as an empty dialog.

### Scope

`assistants`/`azureAssistants` endpoints and the agent builder side panel have
their own upload flows and are deliberately **not** covered. This is documented
in the schema comment and in `librechat.example.yaml`.

This is a surface switch, not an access control. The server does not enforce it.

## Why it is not applied here

The decision lives in the React client, and the official image ships only
`client/dist`, the compiled bundle. Copying a source file into the image changes
nothing, because nothing recompiles.

Applying this patch requires a build stage: fetch the source at the base tag,
apply `002-upload-methods.patch`, run `npm run frontend`, and place the resulting
`client/dist` into the image. That turns this repository from an overlay into a
real build, with a full client build on every version bump instead of a checksum
comparison. We deliberately have not taken that on.

The patch is kept here so it is ready if that changes, and as the basis for the
upstream contribution.

## Contents

| File | Purpose |
|---|---|
| `002-upload-methods.patch` | `git diff` against `v0.8.7`, 26 files |
| `upstream.sha256` | checksums of the 18 pre-existing files it touches |

Verify it still applies:

```bash
git clone --depth 1 --branch v0.8.7 https://github.com/danny-avila/LibreChat.git
cd LibreChat && git apply --check ../patches/002-upload-methods/002-upload-methods.patch
```

## Verification at time of writing

Typecheck clean for `packages/data-provider`, `packages/api` and the client.
ESLint clean. Full suites: 1292 tests in `packages/data-provider`, 2829 in
`client`, 596 in `packages/api`. Four independent review rounds; the last one
concluded the patch is acceptable.
