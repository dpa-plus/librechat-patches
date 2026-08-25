# 004 — video and audio uploads for tool sidecars

**Applied:** yes — built into the image, see `Dockerfile`
**Type:** B (off-by-default switch, see the rule in the repository README)
**Base:** v0.8.7
**Upstream status:** not offered yet

## What upstream does

LibreChat offers raw video and audio through the direct provider upload path
only for endpoints it classifies as natively capable of receiving those media
types. A custom endpoint therefore has no direct upload option for an MP4 or an
audio file, even when a local tool sidecar is responsible for processing the
stored file.

## What this patch changes

The patch adds the off-by-default `uploadMethods.providerVideoAudio` switch.
When enabled for an endpoint or model spec, raw video and audio become eligible
for the direct provider upload path.

This switch only changes upload-option resolution. It does not add video or
audio capabilities to the selected model, transmit media bytes through the chat
completion request, or provide access control. The intended architecture is for
LibreChat to retain the uploaded file while an authorised local tool resolves
and processes it separately.

The tool integration remains responsible for enforcing user and session
authorisation when resolving stored files. This patch neither exposes a file
resolver nor changes storage permissions.

## Configuration

```yaml
modelSpecs:
  list:
    - name: video-analysis
      uploadMethods:
        provider: true
        providerVideoAudio: true
        autoRoute: true

fileConfig:
  endpoints:
    ToolEndpoint:
      supportedMimeTypes:
        - 'video/.*'
        - 'audio/.*'
      uploadMethods:
        provider: true
        providerVideoAudio: true
        autoRoute: true
```

Model-spec configuration takes precedence over endpoint configuration in both
directions. An explicit `provider: false` remains authoritative and cannot be
bypassed by `providerVideoAudio: true`.

With `providerVideoAudio` unset, custom endpoints retain the upload behaviour
provided by patch 002 and stock LibreChat. There is no implicit opt-in.

## Interaction with upload routing

When `autoRoute` is enabled, an opted-in video or audio file is routed directly
through the provider branch. Without the new switch, the normal method
selection from patch 002 still applies; if another compatible method is
available it may be selected instead.

The build applies this patch after patches 002 and 003. Its functional
dependency is patch 002, which introduces the shared upload-option resolver and
per-model upload-method configuration extended here.

## Contents and validation

| File | Purpose |
|---|---|
| `004-video-tool-uploads.patch` | `git diff` against the patch-002 working tree, 4 files |
| `upstream.sha256` | checksums used to detect incompatible upstream changes |

The focused tests cover the default, endpoint opt-in, model-spec overrides,
`provider: false`, video, audio and automatic routing. The repository smoke
test also verifies that the complete patch sequence applies and that the
resulting image starts successfully.
