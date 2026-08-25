# Overlay on the official LibreChat API image.
# See README.md — this is not a fork; each patch only makes a hardcoded value
# configurable, and every default is preserved.
ARG LIBRECHAT_VERSION=v0.8.7

# ---------------------------------------------------------------------------
# Stage 1 — client build.
#
# Needed only because patch 002 changes React code and the official image ships
# nothing but the compiled bundle. Copying a source file into it changes
# nothing, so the bundle has to be rebuilt from source at the very same tag the
# final image is based on. A mismatch here would put a client from one version
# in front of a server from another.
# ---------------------------------------------------------------------------
FROM node:24-alpine AS client
ARG LIBRECHAT_VERSION
RUN apk add --no-cache git python3 make g++
WORKDIR /src

RUN git clone --depth 1 --branch "${LIBRECHAT_VERSION}" \
      https://github.com/danny-avila/LibreChat.git .

COPY patches/002-upload-routing/002-upload-routing.patch /tmp/002.patch
COPY patches/003-table-copy/003-table-copy.patch /tmp/003.patch
COPY patches/004-video-tool-uploads/004-video-tool-uploads.patch /tmp/004.patch
COPY patches/005-reasoning-toggle/005-reasoning-toggle.patch /tmp/005.patch
# --check first: a patch that no longer applies must fail the build loudly here,
# not produce a silently unpatched bundle further down.
# 005 last: it patches files 002 and 003 already touched.
RUN git apply --check /tmp/002.patch && git apply /tmp/002.patch \
 && git apply --check /tmp/003.patch && git apply /tmp/003.patch \
 && git apply --check /tmp/004.patch && git apply /tmp/004.patch \
 && git apply --check /tmp/005.patch && git apply /tmp/005.patch

RUN npm ci --no-audit --no-fund
# Builds data-provider, data-schemas, api, client-package and finally the client.
RUN npm run frontend

# ---------------------------------------------------------------------------
# Stage 2 — the image we actually ship.
# ---------------------------------------------------------------------------
FROM ghcr.io/danny-avila/librechat-api:${LIBRECHAT_VERSION}

# 001 — configurable image resize ceilings (IMAGE_MAX_*). Server-side, a plain
# file swap.
COPY patches/001-image-resize/resize.js /app/api/server/services/Files/images/resize.js

# 005 — reasoning toggle, server half: re-attach the validated user
# `reasoning_effort` after model-spec enforcement, gated by
# `interface.reasoningToggle`. Same file-swap mechanism as 001.
COPY patches/005-reasoning-toggle/buildEndpointOption.js /app/api/server/middleware/buildEndpointOption.js

# 002 — configurable upload methods. The compiled client, plus data-provider:
# the schema and the resolution helper live there, and the server reads them
# too. Forgetting the second one leaves the server on the old schema and the
# config silently without effect.
COPY --from=client /src/client/dist /app/client/dist
COPY --from=client /src/packages/data-provider/dist /app/packages/data-provider/dist
# 003 also passes a key through the interface builder, which lives in
# data-schemas. Without this copy the server keeps the old builder and drops
# `tableCopy` on its way to the client — silently.
COPY --from=client /src/packages/data-schemas/dist /app/packages/data-schemas/dist

ARG LIBRECHAT_VERSION
LABEL org.opencontainers.image.title="librechat-api (dpa-plus overlay)" \
      org.opencontainers.image.description="Official LibreChat API image with patches that make hardcoded values configurable. Defaults unchanged." \
      org.opencontainers.image.source="https://github.com/dpa-plus/librechat-patches" \
      org.opencontainers.image.licenses="MIT" \
      eu.dpa.librechat.base-version="${LIBRECHAT_VERSION}" \
      eu.dpa.librechat.patches="001-image-resize,002-upload-routing,003-table-copy,004-video-tool-uploads,005-reasoning-toggle"
