# Thin overlay on the official LibreChat API image.
# See README.md — this is not a fork; each patch only makes a hardcoded value
# configurable, and every default is preserved.
ARG LIBRECHAT_VERSION=v0.8.6-rc1
FROM ghcr.io/danny-avila/librechat-api:${LIBRECHAT_VERSION}

# 001 — configurable image resize ceilings (IMAGE_MAX_*)
COPY patches/001-image-resize/resize.js /app/api/server/services/Files/images/resize.js

ARG LIBRECHAT_VERSION
LABEL org.opencontainers.image.title="librechat-api (dpa-plus overlay)" \
      org.opencontainers.image.description="Official LibreChat API image with patches that make hardcoded values configurable. Defaults unchanged." \
      org.opencontainers.image.source="https://github.com/dpa-plus/librechat-patches" \
      org.opencontainers.image.licenses="MIT" \
      eu.dpa.librechat.base-version="${LIBRECHAT_VERSION}" \
      eu.dpa.librechat.patches="001-image-resize"
