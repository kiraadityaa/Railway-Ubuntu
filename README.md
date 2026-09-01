# Railway XFCE Desktop Container

[![Docker Build](https://img.shields.io/badge/Docker-Ready-blue.svg)](#)
[![Platform](https://img.shields.io/badge/Platform-Railway-darkviolet.svg)](#)
[![OS](https://img.shields.io/badge/Ubuntu-22.04-orange.svg)](#)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#)

A lightweight remote Linux desktop environment running on Railway using Docker, XFCE, TigerVNC, and noVNC.

This project provides a browser-accessible Ubuntu 22.04 desktop with Firefox, Chromium, and OpenCode CLI. The entire environment runs inside a container without systemd, snapd, or Flatpak. The desktop can be accessed directly from a web browser through noVNC.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Components](#components)
- [Features](#features)
  - [XFCE Desktop](#xfce-desktop)
  - [Browser-Based Desktop](#browser-based-desktop)
  - [Browser Support](#browser-support)
  - [OpenCode Integration](#opencode-integration)
- [Railway Deployment](#railway-deployment)
- [Runtime Flow](#runtime-flow)
- [Technical Decisions](#technical-decisions)
- [VNC Configuration & Security](#vnc-configuration--security)
- [Local Docker Testing](#local-docker-testing)
- [Troubleshooting](#troubleshooting)
- [Security Model](#security-model)
- [Limitations & Use Cases](#limitations--use-cases)

---

## Overview

This project is designed for environments where a full Linux desktop is required inside a containerized platform such as Railway. 

**Key Characteristics:**
* Ubuntu 22.04 base
* XFCE Desktop Environment
* TigerVNC & noVNC (WebSocket proxy through websockify)
* Firefox installed as a native Debian package
* Chromium installed as a native binary (configured with `--no-sandbox`)
* OpenCode CLI & D-Bus session support
* Railway `$PORT` integration
* **Zero Bloat**: No systemd, no snapd, no Snap-based Chromium, and no Flatpak.

The container is intentionally designed to run as a regular Docker process rather than booting a traditional Linux init system.

---

## Architecture

```text
                         Internet
                            |
                            | HTTPS
                            v
                  +----------------------+
                  |       Railway        |
                  |   Public HTTP Proxy  |
                  +----------+-----------+
                             |
                             | $PORT
                             v
                  +----------------------+
                  |       noVNC          |
                  |     websockify       |
                  +----------+-----------+
                             |
                             | WebSocket
                             v
                  +----------------------+
                  |      TigerVNC        |
                  |       :5901          |
                  +----------+-----------+
                             |
                             | X11
                             v
                  +----------------------+
                  |        XFCE          |
                  |       DISPLAY=:1     |
                  +----------+-----------+
                             |
            +----------------+----------------+
            |                |                |
            v                v                v
       +---------+      +-----------+    +-----------+
       | Firefox |      | Chromium  |    | OpenCode  |
       |  .deb   |      |  Native   |    |    CLI    |
       +---------+      +-----------+    +-----------+
```

---

## Project Structure

```text
.
├── Dockerfile
├── entrypoint.sh
└── README.md
```

> **Note:** The XFCE VNC startup script is generated directly by the `Dockerfile`, so no additional `xstartup` file is required in the repository.

---

## Components

| Component | Purpose |
| :--- | :--- |
| **Ubuntu 22.04** | Base operating system |
| **XFCE** | Lightweight graphical desktop |
| **TigerVNC** | VNC server |
| **noVNC** | Browser-based VNC client |
| **websockify** | WebSocket-to-VNC bridge |
| **D-Bus** | Desktop session and application communication |
| **Firefox** | Native Firefox browser (.deb) |
| **Chromium** | Native Chromium browser |
| **OpenCode** | AI coding agent CLI |
| **Railway** | Container hosting and HTTP routing |

---

## Features

### XFCE Desktop

The project uses XFCE because it provides a complete graphical environment while keeping resource consumption relatively low compared with heavier desktop environments. It provides a Window manager, Desktop panel, Application menu, File manager, Terminal, Desktop settings, Session management, and Basic desktop utilities.

The desktop is launched through:
```bash
dbus-run-session -- startxfce4
```
This allows XFCE applications to obtain a proper D-Bus session without requiring `systemd`.

### Browser-Based Desktop

The desktop is exposed through noVNC. After deployment, Railway provides a public domain (e.g., `https://your-project.up.railway.app`). The desktop can be opened at:
`https://your-project.up.railway.app/vnc.html`

No separate VNC client is required; a modern browser is enough.

### Browser Support

#### Firefox
Firefox is installed using the Mozilla Team PPA, intentionally avoiding the Ubuntu Snap package. The resulting installation is a native Debian package.

Check the installation:
```bash
firefox --version
```

#### Chromium
Chromium is not installed through Snap, Flatpak, or Ubuntu's Chromium Snap package. Instead, the Docker image downloads a Linux Chromium build directly from the Chromium browser snapshot infrastructure. 

The binary is installed under `/opt/chromium/` and exposed through `/usr/local/bin/chromium`.

Check the installation:
```bash
chromium --version
```

**Chromium Sandbox & Flatpak Limitations:**
Flatpak requires a sandboxing layer based on Bubblewrap. Inside restricted container environments, Bubblewrap may fail with `Operation not permitted`. For this reason, this project does not use Flatpak. 

The Chromium launcher intentionally includes container compatibility flags:
```bash
/opt/chromium/chrome \
    --no-sandbox \
    --disable-dev-shm-usage
```

> **Security Consideration:** Running Chromium with `--no-sandbox` significantly reduces browser isolation. Do not use this setup for untrusted browsing workloads unless the surrounding container and network environment are appropriately isolated.

### OpenCode Integration

OpenCode is installed automatically during Docker image creation using the official installer.

Check the installation:
```bash
opencode --version
```
Launch OpenCode via terminal (`opencode`) or from the XFCE application menu.

> **Warning regarding API Keys:** API keys should never be placed directly into the `Dockerfile`, `README.md`, `entrypoint.sh`, or the Git repository. Instead, configure provider credentials using Railway environment variables (e.g., `OPENAI_API_KEY=...`).

---

## Railway Deployment

No traditional Linux server is required. You only need a GitHub repository and a Railway account.

1. Create a new Railway project.
2. Select **Deploy from GitHub repo**.
3. Select this repository.
4. Allow Railway to detect the `Dockerfile`.
5. Deploy the service.

Railway will automatically build the Docker image and assign a port dynamically via the `$PORT` environment variable. The `entrypoint.sh` reads this and configures the noVNC server to listen on `0.0.0.0:$PORT`.

---

## Runtime Flow

```text
Container starts
      |
      v
entrypoint.sh
      |
      +--> Create runtime directories
      |
      +--> Start D-Bus system bus
      |
      +--> Remove stale VNC files
      |
      +--> Start TigerVNC
      |
      +--> Wait for X11 socket
      |
      +--> XFCE starts through xstartup
      |
      +--> Start websockify/noVNC
      |
      +--> Verify installed applications
      |
      +--> Keep noVNC process alive
```

---

## Technical Decisions

### Why There Is No systemd
Containers normally do not need a traditional init system. This makes the container easier to deploy on platforms such as Railway. The Docker container itself acts as the process supervisor via `entrypoint.sh`.

### Why There Is No snapd
Snap introduces additional services, expects a more traditional host environment, and commonly expects `systemd` integration. This project intentionally avoids Snap completely.

### D-Bus Management
A graphical Linux desktop requires more than just an X server. This project starts a system D-Bus daemon manually (`dbus-daemon --system --fork`) to avoid requiring `systemd`.

---

## VNC Configuration & Security

TigerVNC runs on `DISPLAY=:1` (TCP 5901). The VNC server is started using:
```bash
vncserver :1 \
    -geometry 1280x800 \
    -depth 24 \
    -localhost no \
    -SecurityTypes None \
    --I-KNOW-THIS-IS-INSECURE
```

> **Important:** This project intentionally disables VNC authentication to simplify the Railway/noVNC environment. Security is therefore dependent on the external access layer. For production environments, authentication should be added through an appropriate access layer.

---

## Local Docker Testing

The image can be tested locally before deploying to Railway.

**Build:**
```bash
docker build --platform linux/amd64 -t railway-xfce .
```

**Run:**
```bash
docker run --rm -p 8080:8080 -e PORT=8080 railway-xfce
```

**Access:**
Open `http://localhost:8080/vnc.html` in your browser.

---

## Troubleshooting

<details>
<summary><strong>Chromium fails with "Operation not permitted"</strong></summary>

**Cause:** Chromium is being launched through Flatpak.
**Solution:** This project intentionally does not use Flatpak. Verify the binary location:
```bash
which chromium
# Expected: /usr/local/bin/chromium
```
</details>

<details>
<summary><strong>TigerVNC Refuses SecurityTypes None</strong></summary>

Ensure the following option exists in your VNC configuration:
`--I-KNOW-THIS-IS-INSECURE`
</details>

<details>
<summary><strong>XFCE Does Not Start</strong></summary>

Check VNC logs and process status:
```bash
cat /root/.vnc/*.log
ps aux | grep xfce
ps aux | grep dbus
```
The VNC display should be `:1`.
</details>

<details>
<summary><strong>noVNC Page Opens but Desktop Does Not Connect</strong></summary>

Check whether TigerVNC is running and listening:
```bash
ps aux | grep Xtigervnc
ls -la /tmp/.X11-unix/  # Expected: X1
netstat -tlnp           # Expected internal port: 5901
```
</details>

---

## Customization

* **Change Desktop Resolution:** Edit `entrypoint.sh` and change `-geometry 1280x800` to `-geometry 1920x1080`.
* **Change Timezone:** Modify the `ENV TZ=Asia/Jakarta` instruction in the `Dockerfile`.
* **Add Linux Packages:** Add desired packages (e.g., `htop`, `jq`, `unzip`) to the main `apt-get install` block in the `Dockerfile`.

---

## Security Model

This project intentionally prioritizes compatibility with restricted container environments. The following choices reduce isolation:
1. VNC authentication disabled
2. Chromium sandbox disabled
3. Container desktop exposed through Railway

**Recommended precautions:**
* Do not store sensitive credentials inside the container.
* Do not commit API keys to GitHub.
* Use Railway environment variables for secrets.
* Avoid browsing untrusted websites with privileged data available.
* Treat the container as a disposable environment.

---

## Limitations & Use Cases

### Recommended Use Cases
* Remote Linux desktop experiments
* Browser testing & Lightweight browser automation
* Disposable development environments
* OpenCode development workflows
* Testing Linux GUI applications

### Not Recommended For
* Highly sensitive workloads
* Permanent personal desktops
* Handling private credentials or storing passwords
* Untrusted multi-user environments
* Production workloads requiring browser sandbox isolation

---

## License

MIT License

> If this project is based on or incorporates code from other projects, review their individual licenses before redistributing modified components.

## Acknowledgements

This project builds upon several open-source projects and technologies:
Ubuntu | XFCE | TigerVNC | noVNC | websockify | Firefox | Chromium | OpenCode | Docker | Railway

Please refer to each project's official documentation and licensing terms for detailed information.
