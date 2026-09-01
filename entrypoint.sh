#!/bin/bash

set -e

# ============================================================
# Railway
# ============================================================

PORT="${PORT:-8080}"

export HOME=/root
export USER=root
export DISPLAY=:1

echo ""
echo "=================================================="
echo " Railway XFCE Desktop Container"
echo "=================================================="
echo " PORT    : ${PORT}"
echo " DISPLAY : ${DISPLAY}"
echo "=================================================="
echo ""


# ============================================================
# Runtime directories
# ============================================================

mkdir -p /run/dbus
mkdir -p /root/.vnc


# ============================================================
# Start D-Bus system bus
#
# No systemd required.
# ============================================================

if [ ! -S /run/dbus/system_bus_socket ]; then
    echo "[+] Starting D-Bus system bus..."

    dbus-daemon \
        --system \
        --fork
fi


# ============================================================
# Clean old VNC state
# ============================================================

echo "[+] Cleaning old VNC state..."

rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1
rm -f /root/.vnc/*.pid


# ============================================================
# Start TigerVNC
#
# NO PASSWORD
#
# --I-KNOW-THIS-IS-INSECURE is required by TigerVNC
# when SecurityTypes=None is used.
# ============================================================

echo "[+] Starting TigerVNC without password..."

vncserver :1 \
    -geometry 1280x800 \
    -depth 24 \
    -localhost no \
    -SecurityTypes None \
    --I-KNOW-THIS-IS-INSECURE


# ============================================================
# Wait for X11 socket
# ============================================================

echo "[+] Waiting for X11..."

for i in $(seq 1 30); do

    if [ -S /tmp/.X11-unix/X1 ]; then
        echo "[+] X11 is ready."
        break
    fi

    sleep 1

done


if [ ! -S /tmp/.X11-unix/X1 ]; then
    echo ""
    echo "[ERROR] X11 socket was not created."
    echo ""
    echo "VNC log:"
    echo ""

    cat /root/.vnc/*.log 2>/dev/null || true

    exit 1
fi


# ============================================================
# Check XFCE process
# ============================================================

sleep 2

echo ""
echo "[+] XFCE processes:"
ps aux | grep -E 'xfce4-session|xfwm4|xfdesktop' | grep -v grep || true


# ============================================================
# Start noVNC
#
# Railway handles HTTPS.
#
# Browser
#    HTTPS/WSS
#       ↓
# Railway
#       ↓
# HTTP/WebSocket
#       ↓
# noVNC :$PORT
#       ↓
# VNC :5901
# ============================================================

echo ""
echo "[+] Starting noVNC..."
echo "[+] Listening on 0.0.0.0:${PORT}"
echo ""

websockify \
    --web=/usr/share/novnc/ \
    "0.0.0.0:${PORT}" \
    "127.0.0.1:5901" &

NOVNC_PID=$!


# ============================================================
# Wait for noVNC
# ============================================================

sleep 2

if ! kill -0 "${NOVNC_PID}" 2>/dev/null; then

    echo ""
    echo "[ERROR] noVNC failed to start."
    echo ""

    exit 1
fi


# ============================================================
# Verify applications
# ============================================================

echo ""
echo "=================================================="
echo " Installed applications"
echo "=================================================="

echo ""
echo "[Firefox]"
firefox --version 2>/dev/null || true

echo ""
echo "[Chromium]"
chromium --version 2>/dev/null || true

echo ""
echo "[OpenCode]"
opencode --version 2>/dev/null || true


# ============================================================
# Ready
# ============================================================

echo ""
echo "=================================================="
echo " Desktop is READY"
echo "=================================================="
echo ""
echo " noVNC:"
echo ""
echo " https://YOUR-RAILWAY-DOMAIN/vnc.html"
echo ""
echo " Applications:"
echo ""
echo " Firefox:"
echo "   firefox"
echo ""
echo " Chromium:"
echo "   chromium"
echo ""
echo " OpenCode:"
echo "   opencode"
echo ""
echo " VNC authentication:"
echo "   DISABLED"
echo ""
echo " systemd:"
echo "   NOT USED"
echo ""
echo " snapd:"
echo "   NOT INSTALLED"
echo ""
echo " flatpak:"
echo "   NOT INSTALLED"
echo ""
echo "=================================================="
echo ""


# ============================================================
# Keep container alive
# ============================================================

wait "${NOVNC_PID}"
