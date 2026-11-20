# syntax=docker/dockerfile:1

# ---- Build stage: assemble the static site and stamp the version ----
FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a AS build
ARG APP_VERSION=unknown
WORKDIR /src
COPY site/ ./
RUN rm -f nginx.conf \
 && printf '{"version":"%s"}\n' "$APP_VERSION" > version.json

# ---- Runtime stage: non-root nginx on port 8080 ----
FROM nginxinc/nginx-unprivileged:1.31.7-alpine-slim@sha256:a8cb0f33d51fa107c96fd2bd3a71aaf564ec131e9d2bdf8700944f0ed8b170d7
ARG APP_VERSION=unknown
LABEL org.opencontainers.image.source="https://github.com/TheProgrammingPath/hello-mt" \
      org.opencontainers.image.revision="${APP_VERSION}" \
      org.opencontainers.image.title="hello-mt"

# Patch OS packages that have published fixes (musl CVE-2026-107891,
# zlib CVE-2026-85091) without waiting for upstream to rebuild the base.
# Needs root for this one step; USER 101 below drops back to non-root.
USER root
RUN apk upgrade --no-cache 

COPY site/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/ /usr/share/nginx/html/

USER 101
EXPOSE 8080
