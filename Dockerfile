# syntax=docker/dockerfile:1

# ---- Build stage: assemble the static site and stamp the version ----
FROM alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf AS build
ARG APP_VERSION=unknown
WORKDIR /src
COPY site/ ./
RUN rm -f nginx.conf \
 && printf '{"version":"%s"}\n' "$APP_VERSION" > version.json

# ---- Runtime stage: non-root nginx on port 8080 ----
FROM nginxinc/nginx-unprivileged:1.30.6-alpine-slim@sha256:5d8bb9437d74a600ec5dbf90c035451c724dc33eac8d3a71078f6f8612c345f6
ARG APP_VERSION=unknown
LABEL org.opencontainers.image.source="https://github.com/TheProgrammingPath/hello-mt" \
      org.opencontainers.image.revision="${APP_VERSION}" \
      org.opencontainers.image.title="hello-mt"

COPY site/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/ /usr/share/nginx/html/

USER 101
EXPOSE 8080
