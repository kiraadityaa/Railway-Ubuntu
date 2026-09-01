FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta

# ============================================================
# Base packages
# ============================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies \
    xubuntu-icon-theme \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    dbus \
    dbus-x11 \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xauth \
    x11-utils \
    x11-xserver-utils \
    x11-apps \
    xterm \
    ca-certificates \
    sudo \
    vim \
    nano \
    net-tools \
    curl \
    wget \
    git \
    tzdata \
    gnupg \
    software-properties-common \
    unzip \
    procps \
    psmisc \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# Firefox
# Native .deb from Mozilla Team PPA
# NOT Snap
# ============================================================

RUN add-apt-repository ppa:mozillateam/ppa -y

RUN printf '%s\n' \
    'Package: firefox*' \
    'Pin: release o=LP-PPA-mozillateam' \
    'Pin-Priority: 1001' \
    > /etc/apt/preferences.d/mozilla-firefox

RUN apt-get update && apt-get install -y \
    firefox \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# Chromium dependencies
# ============================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxshmfence1 \
    libasound2 \
    libx11-xcb1 \
    libxcb1 \
    libxext6 \
    libxrender1 \
    libpango-1.0-0 \
    libcairo2 \
    libatspi2.0-0 \
    fonts-liberation \
    fonts-dejavu \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# Chromium
#
# Native Chromium snapshot.
# NO Snap
# NO Flatpak
# ============================================================

RUN set -eux; \
    CHROMIUM_REV="$(curl -fsSL \
        https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/LAST_CHANGE)"; \
    echo "Installing Chromium revision: ${CHROMIUM_REV}"; \
    curl -fL \
        "https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/${CHROMIUM_REV}/chrome-linux.zip" \
        -o /tmp/chromium.zip; \
    unzip -q /tmp/chromium.zip -d /opt; \
    mv /opt/chrome-linux /opt/chromium; \
    rm -f /tmp/chromium.zip; \
    /opt/chromium/chrome --version


# ============================================================
# Chromium launcher
#
# Railway/container environment:
# Chromium sandbox is disabled intentionally.
# ============================================================

RUN cat > /usr/local/bin/chromium <<'EOF'
#!/bin/bash

exec /opt/chromium/chrome \
    --no-sandbox \
    --disable-dev-shm-usage \
    "$@"
EOF

RUN chmod +x /usr/local/bin/chromium


# Chromium aliases
RUN ln -sf /usr/local/bin/chromium /usr/local/bin/chromium-browser


# ============================================================
# Chromium XFCE application launcher
# ============================================================

RUN mkdir -p /root/.local/share/applications

RUN cat > /root/.local/share/applications/chromium.desktop <<'EOF'
[Desktop Entry]
Name=Chromium
Comment=Chromium Web Browser
Exec=/usr/local/bin/chromium %U
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
EOF


# ============================================================
# OpenCode CLI
# ============================================================
#
# Official installer.
#
# The current installer may install into:
# /root/.opencode/bin
#
# Therefore we explicitly symlink it into /usr/local/bin.
# ============================================================

RUN curl -fsSL https://opencode.ai/install \
    | bash -s -- --no-modify-path

RUN ln -sf /root/.opencode/bin/opencode /usr/local/bin/opencode

RUN /usr/local/bin/opencode --version


# ============================================================
# XFCE application launcher for OpenCode
# ============================================================

RUN cat > /root/.local/share/applications/opencode.desktop <<'EOF'
[Desktop Entry]
Name=OpenCode
Comment=AI Coding Agent
Exec=xterm -e /usr/local/bin/opencode
Terminal=false
Type=Application
Categories=Development;Utility;
StartupNotify=true
EOF


# ============================================================
# XFCE / D-Bus VNC startup
#
# No separate xstartup file needed.
# ============================================================

RUN mkdir -p /root/.vnc

RUN cat > /root/.vnc/xstartup <<'EOF'
#!/bin/sh

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce

export XDG_CONFIG_DIRS=/etc/xdg/xdg-xfce:/etc/xdg

export XDG_DATA_DIRS=/usr/local/share:/usr/share

exec dbus-run-session -- startxfce4
EOF

RUN chmod +x /root/.vnc/xstartup


# ============================================================
# Environment
# ============================================================

ENV HOME=/root
ENV USER=root
ENV DISPLAY=:1
ENV PATH=/usr/local/bin:/root/.opencode/bin:$PATH


# ============================================================
# Entrypoint
# ============================================================

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh


# ============================================================
# Railway
# ============================================================

EXPOSE 8080

CMD ["/entrypoint.sh"]
