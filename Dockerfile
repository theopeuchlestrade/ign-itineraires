# syntax=docker/dockerfile:1.7

# The digest currently resolves to the Cirrus Flutter stable builder. The
# framework is then pinned to the exact Flutter 3.47.9 revision used by CI.
FROM ghcr.io/cirruslabs/flutter:stable@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS build
WORKDIR /app

ARG FLUTTER_VERSION=3.47.9
ENV FLUTTER_VERSION=${FLUTTER_VERSION}
ARG FLUTTER_REVISION=c197ca5199e9ee5661e865596c9c07294dfab51c

RUN set -eux; \
    flutter_root="$(dirname "$(dirname "$(command -v flutter)")")"; \
    git -C "${flutter_root}" fetch --depth=1 origin "refs/tags/${FLUTTER_VERSION}:refs/tags/${FLUTTER_VERSION}"; \
    git -C "${flutter_root}" checkout --detach "${FLUTTER_REVISION}"; \
    rm -f "${flutter_root}/bin/cache/flutter.version.json" "${flutter_root}/version"; \
    flutter --version; \
    flutter precache --web

COPY pubspec.* ./
RUN flutter pub get --enforce-lockfile

COPY . .
RUN sh scripts/build_web_release.sh /

FROM nginx:1.30.6-alpine@sha256:0e52bd054126cdc040b1276c0af347aeb02a41b9cfe305d6094767ac30e97949 AS runtime
LABEL org.opencontainers.image.source="https://github.com/theopeuchlestrade/ign-itineraires"

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

RUN sed -i \
      -e 's#pid[[:space:]]\+/run/nginx.pid;#pid /tmp/nginx.pid;#' \
      -e 's#pid[[:space:]]\+/var/run/nginx.pid;#pid /tmp/nginx.pid;#' \
      /etc/nginx/nginx.conf \
 && mkdir -p /var/cache/nginx /var/run /tmp \
 && chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/run /tmp

USER nginx
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -q -O - http://127.0.0.1:8080/healthz >/dev/null 2>&1 || exit 1
CMD ["nginx", "-g", "daemon off;"]
