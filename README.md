<p align="center">
  <img src="docs/readme-assets/hero.png" alt="librechat-patches — a thin overlay on the official LibreChat image" width="100%">
</p>

# librechat-patches

## Why this exists

Running [LibreChat](https://github.com/danny-avila/LibreChat) for an enterprise
customer keeps hitting the same wall: a value that has to be configurable for
this deployment is hardcoded upstream, applied to every endpoint, with no
environment variable and no config key to reach it.

These are rarely controversial changes. Usually somebody has already asked for
them, and often somebody has already written the patch. What is missing is a
merge. The requests behind patch 001 have been open since **April 2025** and
**December 2025**; the related pull request is still a draft.

That is a perfectly reasonable pace for a project maintained by two people. It
is not a pace you can put in front of a customer who needs the setting next
week.

So this repository is the shortcut. We apply the change ourselves, in a form
narrow enough that the shortcut stays cheap — and we offer the same change
upstream, so that one day we can delete it again.

## What it is

A build of the official LibreChat image with a small set of patches applied.
Each patch either makes a hardcoded value configurable or puts a better
behaviour behind a switch — and in both cases, **an image with no configuration
set behaves exactly like the one it was built from.**

```dockerfile
FROM node:24-alpine AS client
RUN git clone --depth 1 --branch ${LIBRECHAT_VERSION} .../LibreChat.git .
RUN git apply /tmp/002-upload-routing.patch && npm ci && npm run frontend

FROM ghcr.io/danny-avila/librechat-api:${LIBRECHAT_VERSION}
COPY patches/001-image-resize/resize.js /app/api/server/...
COPY --from=client /src/client/dist /app/client/dist
```

Server-side patches are a file swap. Client-side ones are not: the official
image ships only the compiled bundle, so the client is rebuilt from source at
the same tag. That is why this repository builds rather than merely copies.

**This is not a fork and not a distribution.** We track upstream release for
release, we carry as few patched files as we can, and every patch here is
written so it could be merged upstream unchanged. If you can run stock
LibreChat, run stock LibreChat.

## Patches

| # | Type | What it does | Applied | Upstream |
|---|---|---|---|---|
| [001](./patches/001-image-resize) | A | Image resize ceilings (512 / 768 / 2000 / 1568) via `IMAGE_MAX_*` | yes | [#6777](https://github.com/danny-avila/LibreChat/discussions/6777), [#11065](https://github.com/danny-avila/LibreChat/discussions/11065) — open |
| [002](./patches/002-upload-routing) | A + B | Which upload methods the attachment menu offers, per endpoint and per model spec; optionally drops the choice entirely and routes by file type | yes | [PR #11279](https://github.com/danny-avila/LibreChat/pull/11279) — draft |
| [003](./patches/003-table-copy) | B | Copy button on markdown tables — `text/html` + TSV in one clipboard item, so Excel pastes a real table | yes | not offered yet |

## The rule every patch follows

> **An image with no configuration set behaves exactly like the official image
> it was built from.**

That is the whole contract, and it admits two kinds of patch:

**Type A — makes something configurable.** A value upstream hardcodes becomes an
environment variable or a config key, with the upstream number as the default.
Patch 001 is this.

**Type B — changes behaviour, behind an off-by-default switch.** Sometimes the
upstream behaviour is not a value to tune but a decision to make differently.
Those patches are allowed, provided the new behaviour has to be turned on. Patch
002 is this: with `autoRoute` unset, the attachment menu is upstream's, key for
key.

The earlier wording of this rule was "a patch may never change behaviour". That
was a shorthand for the contract above, and it turned out to be too narrow: it
forbade fixing a decision that is simply wrong for a given deployment, while
adding nothing the contract does not already guarantee.

What the contract buys, and why we keep it:

- a patch can be offered upstream as-is, because it costs existing users
  nothing;
- it cannot silently diverge from upstream behaviour;
- and backing a change out is one line of configuration, not a rollback.

The test for any proposed patch is still: *would upstream accept this?* If the
answer is no, it is not a patch — it belongs in configuration, or in a sidecar
service alongside LibreChat.

## Keeping up with upstream

Every patch directory carries `upstream.sha256`, the checksum of the original
file it was derived from. A scheduled workflow checks each new upstream release
against those checksums:

| Situation | What happens |
|---|---|
| New release, patched files unchanged | PR that only bumps the base tag |
| New release, a patched file changed | Issue with the diff — needs a human |
| No new release | nothing |

So "does the new version break our patches?" is answered by a notification
rather than by archaeology.

## Versioning

Tags mirror upstream: `v0.8.7-dpa.1`, `v0.8.7-dpa.2`. The base version is always
readable from the tag.

Images: `ghcr.io/dpa-plus/librechat-api`.

## Deployment

Deliberately manual. The workflow builds and publishes; rolling out is a
separate, conscious step. A smoke test can prove that the container starts and
that a patch is active — it cannot prove that an agent still talks to its code
interpreter.

## Contributing

Maintained for our own deployments. Issues and pull requests are welcome, but
there is no promised response time.

If you are hitting the same wall — some value your deployment needs to configure
and upstream does not expose — a patch here is a reasonable place to put it,
provided it follows the rule above. And please open or upvote the upstream issue
too. **The goal is to empty this repository, not to grow it.** Every patch that
lands upstream gets deleted here.

## Licence

LibreChat is MIT-licensed, and so is this overlay. The patched files are
derivative works of the originals and retain their copyright.
