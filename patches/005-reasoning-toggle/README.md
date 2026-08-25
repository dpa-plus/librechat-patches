# 005 — reasoning toggle

**Applied:** yes — built into the image, see `Dockerfile`
**Type:** B (off-by-default switch, see the rule in the repository README)
**Base:** v0.8.7
**Upstream status:** not offered yet
**Depends on:** applies after 002 (locale file) and 003 (interface config) in
the Dockerfile order.

## What upstream does

Custom endpoints support a `reasoning_effort` parameter, and the parameters
side panel contains a slider for it. But as soon as `modelSpecs` are
configured — the intended setup for managed deployments — the panel is hidden
and no UI element can set the parameter. Users of a spec-only deployment have
no way to ask a reasoning model to think harder or stop it from overthinking.

## Why it matters

Reasoning models behind a router can use `reasoning_effort` as an explicit
user signal ("this one is hard, take your time"). Without any control in the
composer, that signal cannot be given, and the deployment has to guess from
heuristics alone.

## What this patch changes

```yaml
interface:
  reasoningToggle: true   # default: off
```

Switched on, the composer shows a badge (lightbulb, "Think thoroughly" /
"Gründlich nachdenken") next to the existing tool badges. Toggling it sets
`reasoning_effort: high` on the conversation — exactly the field the hidden
parameters panel would set — so the value flows through the existing,
unmodified request pipeline to the provider. Toggling it off clears the field.
The badge is not rendered for agents or assistants endpoints (those configure
their models themselves).

With the flag unset, nothing is rendered and the request payload is
byte-identical to upstream: the interface key is absent after
`removeNullishValues`, the component returns `null`.

## The server half (and why it exists)

With `modelSpecs.enforce: true` — the recommended hardening for managed
deployments — the server rebuilds the request body from the spec preset and
discards every user-supplied parameter except `chatProjectId`
(`applyModelSpecPreset`, `includePresetDefaults: true`). The toggle's value
would be silently dropped. Therefore `buildEndpointOption.js` re-attaches the
user's `reasoning_effort` AFTER enforcement, but only when all of these hold:

- `interface.reasoningToggle` is `true` (the switch for this whole patch),
- the value is one of the known effort levels (validated against a whitelist),
- the spec preset itself does NOT define `reasoning_effort` — an admin preset
  always stays authoritative,
- the request is not for the agents endpoint.

With the flag unset, enforcement behaves byte-identically to upstream: user
`reasoning_effort` is dropped exactly as before.

## Files

- `client/src/components/Chat/Input/ReasoningToggle.tsx` (new): the badge.
- `client/src/components/Chat/Input/BadgeRow.tsx`: renders it alongside the
  other ephemeral badges (same gate, which already excludes agents/assistants).
- `packages/data-provider/src/config.ts`: `interface.reasoningToggle` schema.
- `packages/data-schemas/src/app/interface.ts`: pass the flag through the
  interface builder whitelist (same contract as `tableCopy`, patch 003).
- `client/src/locales/{en,de}/translation.json`: `com_ui_reasoning_toggle`.
- `api/server/middleware/buildEndpointOption.js`: the enforcement re-attach
  described above. Shipped as a file swap in the Dockerfile (like 001), and as
  part of the .patch for source builds.
