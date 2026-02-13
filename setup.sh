#!/bin/bash
set -euo pipefail

# 3X-UI + VLESS+Reality Quick Setup Script
# Usage: curl -sL https://raw.githubusercontent.com/fresh-fx59/threeiks-juai-forest/main/setup.sh | sudo bash

INSTALL_DIR="/opt/3x-ui"
PANEL_PORT=2053

echo "========================================="
echo "  3X-UI + VLESS+Reality Setup"
echo "========================================="
echo ""

# Check root/sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root or with sudo"
    exit 1
fi

# Install Docker if not present
if ! command -v docker &>/dev/null; then
    echo "[1/4] Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    echo "  Docker installed."
else
    echo "[1/4] Docker already installed."
fi

# Create working directory
echo "[2/4] Setting up 3X-UI..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download docker-compose.yml from the repo
curl -fsSL https://raw.githubusercontent.com/fresh-fx59/threeiks-juai-forest/main/docker-compose.yml \
    -o docker-compose.yml

# Start the container
docker compose pull
docker compose up -d

# Configure UFW
echo "[3/4] Configuring firewall..."
if command -v ufw &>/dev/null; then
    ufw allow 22/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
    ufw allow ${PANEL_PORT}/tcp >/dev/null 2>&1 || true
    echo "y" | ufw enable >/dev/null 2>&1 || true
    echo "  UFW configured (ports 22, 443, ${PANEL_PORT})."
else
    echo "  UFW not found, skipping firewall setup."
    echo "  Make sure ports 22, 443, and ${PANEL_PORT} are open."
fi

# Get server IP
SERVER_IP=$(curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null || curl -4 -s --max-time 5 https://ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

# Wait for panel to start
echo "[4/4] Waiting for panel to start..."
sleep 5

echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "  Panel URL:  http://${SERVER_IP}:${PANEL_PORT}/"
echo "  Username:   admin"
echo "  Password:   admin"
echo ""
echo "  IMPORTANT: Change these defaults immediately!"
echo ""
echo "  Next steps:"
echo "  1. Log in to the panel"
echo "  2. Change username, password, port, and web base path"
echo "  3. Create a VLESS+Reality inbound on port 443"
echo "  4. Import the client link into your VPN app"
echo ""
echo "  Install dir: ${INSTALL_DIR}"
echo "  Manage:      cd ${INSTALL_DIR} && docker compose [up -d|down|logs]"
echo "========================================="
