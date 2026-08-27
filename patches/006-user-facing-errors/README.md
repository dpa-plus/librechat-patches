# 006 — structured user-facing errors

**Applied:** yes — built into the image, see `Dockerfile`  
**Type:** B (opt-in error code; all other errors retain upstream behavior)  
**Base:** v0.8.7  
**Upstream status:** not offered yet

## What upstream does

LibreChat wraps every unrecognized provider error in a generic English sentence
and then appends the complete technical message. This remains useful for unknown
failures, but it also affects errors that an authenticated deployment-side
adapter has already translated into a concise instruction for the user.

## What this patch changes

An error containing this structured payload:

```json
{"code":"user_facing_error","info":"Choose a model that supports images and upload the file again."}
```

renders only the `info` value. The provider SDK may prepend an HTTP status and
the server may add its normal diagnostic sentence; LibreChat's existing JSON
extraction still finds the payload before the renderer selects it.

The code is the opt-in. Plain strings, unknown JSON error codes and all existing
LibreChat error types keep the upstream diagnostic wrapper unchanged.

## Contents

| File | Purpose |
|---|---|
| `006-user-facing-errors.patch` | Adds one structured error type and focused rendering tests |
| `upstream.sha256` | Checksum of the existing v0.8.7 file touched by the patch |

