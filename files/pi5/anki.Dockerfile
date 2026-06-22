# Managed by Ansible — copied into the ThisIsntTheWay/headless-anki clone as
# Dockerfile.pi5 and built locally by docker compose.
#
# Differs from upstream's Dockerfile ONLY in the Anki download: it is
# architecture-aware (linux-aarch64 on arm64, linux-x86_64 on amd64) and pins
# Anki 26.05 — the first release line that ships an official linux-aarch64
# binary. The base stays debian:13-slim (glibc 2.41), which satisfies Anki's
# glibc >= 2.36 requirement. The published kaiimehra/headless-anki arm64 image
# fails here because it is built on Ubuntu 22.04 (glibc 2.35).
ARG ANKICONNECT_VERSION=25.11.9.0
ARG ANKI_VERSION=26.05

# --- Build: install Anki + AnkiConnect ---
FROM debian:13-slim AS build
ARG ANKICONNECT_VERSION
ARG ANKI_VERSION
ARG TARGETARCH

RUN apt-get update && apt-get install --no-install-recommends -y \
        ca-certificates curl zstd \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH}" in \
        arm64) ANKI_ARCH=linux-aarch64 ;; \
        amd64) ANKI_ARCH=linux-x86_64 ;; \
        *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fL -o /tmp/anki.tar.zst \
        "https://github.com/ankitects/anki/releases/download/${ANKI_VERSION}/anki-${ANKI_VERSION}-${ANKI_ARCH}.tar.zst"; \
    mkdir -p /tmp/anki; \
    tar -x --zstd -f /tmp/anki.tar.zst -C /tmp/anki --strip-components=1; \
    # Anki 26.05's install.sh uses bash syntax, so run it with bash (not dash);
    # strip the xdg-mime call (no X/desktop in this build stage).
    ( cd /tmp/anki && sed 's/xdg-mime/#/' install.sh | bash - ); \
    mkdir -p /app/anki-connect; \
    curl -fL "https://git.sr.ht/~foosoft/anki-connect/archive/${ANKICONNECT_VERSION}.tar.gz" \
        | tar -xz -C /app/anki-connect --strip-components=1

# --- Final stage (identical to upstream) ---
FROM debian:13-slim

# Qt6 runtime deps. Anki 26.05's bundled Qt6 needs more system libs than the
# upstream list (which targeted 25.02.7) — notably libwebpdemux2, GL/EGL, and the
# full xcb platform-plugin set. Installed as a superset so the import chain in
# aqt.qt.qt6 resolves even with QT_QPA_PLATFORM=offscreen (it still loads Qt GUI libs).
# Installing the Debian Qt6 GUI packages pulls the full closure of low-level
# system libs Anki's bundled Qt6 links against (libminizip1, libdouble-conversion,
# libpcre2-16, libmd4c, libb2, etc.) — ending the missing-.so cascade in one shot.
# The explicit xcb/GL/webp libs cover the platform-plugin + image-format deps that
# aren't hard Depends of the Qt6 libs. (offscreen still loads the Qt GUI libs.)
RUN apt-get update && apt-get install --no-install-recommends -y \
        ca-certificates curl jq mpv \
        libqt6gui6 libqt6widgets6 libqt6network6 libqt6dbus6 libqt6svg6 \
        libnss3 libxkbfile1 libxkbcommon0 libxkbcommon-x11-0 \
        libminizip1 libwebpdemux2 libwebp7 \
        libgl1 libegl1 libopengl0 libglib2.0-0 libdbus-1-3 \
        libfontconfig1 libfreetype6 libxrender1 \
        libxcomposite1 libxdamage1 libxrandr2 libxtst6 \
        libxcb-cursor0 libxcb-xinerama0 libxcb-icccm4 libxcb-image0 \
        libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 libxcb-shape0 \
        libxcb-util1 libxcb-xkb1 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN useradd -m anki && mkdir /app && chown anki /app
WORKDIR /app

COPY --from=build /usr/local /usr/local
COPY --from=build /app/anki-connect /app/anki-connect
COPY startup.sh /app/startup.sh

# Anki profile + AnkiConnect wiring (data/ + startup.sh come from the upstream clone)
ADD data /data
RUN mkdir -p /data/addons21 /export \
    && ln -sf /app/anki-connect/plugin /data/addons21/AnkiConnectDev \
    && jq '.webBindAddress = "0.0.0.0"' /app/anki-connect/plugin/config.json > /tmp/c \
    && mv /tmp/c /app/anki-connect/plugin/config.json \
    && chown -R anki:anki /app /data /export
VOLUME /data
VOLUME /export

USER anki

ENV ANKICONNECT_WILDCARD_ORIGIN="0"
ENV QMLSCENE_DEVICE=softwarecontext
ENV FONTCONFIG_PATH=/etc/fonts
ENV QT_XKB_CONFIG_ROOT=/usr/share/X11/xkb
ENV QT_QPA_PLATFORM="vnc"

CMD ["/bin/bash", "/app/startup.sh"]
