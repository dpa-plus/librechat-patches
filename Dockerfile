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
# --check first: a patch that no longer applies must fail the build loudly here,
# not produce a silently unpatched bundle further down.
RUN git apply --check /tmp/002.patch && git apply /tmp/002.patch

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

# 002 — configurable upload methods. The compiled client, plus data-provider:
# the schema and the resolution helper live there, and the server reads them
# too. Forgetting the second one leaves the server on the old schema and the
# config silently without effect.
COPY --from=client /src/client/dist /app/client/dist
COPY --from=client /src/packages/data-provider/dist /app/packages/data-provider/dist

ARG LIBRECHAT_VERSION
LABEL org.opencontainers.image.title="librechat-api (dpa-plus overlay)" \
      org.opencontainers.image.description="Official LibreChat API image with patches that make hardcoded values configurable. Defaults unchanged." \
      org.opencontainers.image.source="https://github.com/dpa-plus/librechat-patches" \
      org.opencontainers.image.licenses="MIT" \
      eu.dpa.librechat.base-version="${LIBRECHAT_VERSION}" \
      eu.dpa.librechat.patches="001-image-resize,002-upload-routing"
