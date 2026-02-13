#!/bin/bash
set -euo pipefail

# 3X-UI + VLESS+Reality Auto-Setup Script
# Usage: curl -sL https://raw.githubusercontent.com/fresh-fx59/threeiks-juai-forest/main/setup.sh | sudo bash

INSTALL_DIR="/opt/3x-ui"
DEFAULT_PORT=2053

echo "========================================="
echo "  3X-UI + VLESS+Reality Auto-Setup"
echo "========================================="
echo ""

# Check root/sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root or with sudo"
    exit 1
fi

# ─── Generate random credentials ───

rand_str() { dd if=/dev/urandom bs=512 count=1 2>/dev/null | tr -dc "$1" | head -c "$2"; }
PANEL_USER=$(rand_str 'a-zA-Z0-9' 8)
PANEL_PASS=$(rand_str 'a-zA-Z0-9' 16)
PANEL_PORT=$(shuf -i 10000-60000 -n 1)
WEB_BASE_PATH="/$(rand_str 'a-zA-Z0-9' 10)/"

# ─── Step 1: Install Docker ───

if ! command -v docker &>/dev/null; then
    echo "[1/6] Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    echo "  Docker installed."
else
    echo "[1/6] Docker already installed."
fi

# ─── Step 2: Start 3X-UI container ───

echo "[2/6] Setting up 3X-UI..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

curl -fsSL https://raw.githubusercontent.com/fresh-fx59/threeiks-juai-forest/main/docker-compose.yml \
    -o docker-compose.yml

docker compose pull
docker compose up -d

# ─── Step 3: Wait for panel readiness ───

echo "[3/6] Waiting for panel to start..."
for i in $(seq 1 30); do
    if curl -sf -o /dev/null "http://127.0.0.1:${DEFAULT_PORT}/" 2>/dev/null; then
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "ERROR: Panel did not start within 30 seconds"
        echo "Check logs: docker logs 3x-ui"
        exit 1
    fi
    sleep 1
done
echo "  Panel is ready."

# ─── Step 4: Auto-configure via API ───

echo "[4/6] Configuring panel and VPN..."

API="http://127.0.0.1:${DEFAULT_PORT}"

# Login with default credentials
LOGIN_RESPONSE=$(curl -s -D - "${API}/login" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d 'username=admin&password=admin' 2>/dev/null)

COOKIE=$(echo "$LOGIN_RESPONSE" | grep -i 'Set-Cookie:' | head -1 | sed 's/.*3x-ui=//;s/;.*//')

if [ -z "$COOKIE" ]; then
    echo "ERROR: Failed to log in to panel with default credentials."
    echo "Panel may already be configured. Check: http://YOUR_SERVER_IP:${DEFAULT_PORT}/"
    exit 1
fi

SESSION_COOKIE="3x-ui=${COOKIE}"

# Generate X25519 keys
X25519_OUTPUT=$(docker exec 3x-ui /app/bin/xray-linux-amd64 x25519 2>/dev/null)
PRIVATE_KEY=$(echo "$X25519_OUTPUT" | grep "PrivateKey:" | awk '{print $2}')
PUBLIC_KEY=$(echo "$X25519_OUTPUT" | grep "Password:" | awk '{print $2}')

# Generate client UUID and short ID
CLIENT_UUID=$(cat /proc/sys/kernel/random/uuid)
SHORT_ID=$(rand_str 'a-f0-9' 16)

# Get server IP
SERVER_IP=$(curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null \
    || curl -4 -s --max-time 5 https://ifconfig.me 2>/dev/null \
    || echo "YOUR_SERVER_IP")

# Create VLESS+Reality inbound on port 443
INBOUND_SETTINGS=$(cat <<ENDJSON
{
    "clients": [
        {
            "id": "${CLIENT_UUID}",
            "flow": "xtls-rprx-vision",
            "email": "user1",
            "limitIp": 0,
            "totalGB": 0,
            "expiryTime": 0,
            "enable": true,
            "tgId": "",
            "subId": "",
            "reset": 0
        }
    ],
    "decryption": "none",
    "fallbacks": []
}
ENDJSON
)

STREAM_SETTINGS=$(cat <<ENDJSON
{
    "network": "tcp",
    "security": "reality",
    "externalProxy": [],
    "realitySettings": {
        "show": false,
        "xver": 0,
        "dest": "dl.google.com:443",
        "serverNames": ["dl.google.com"],
        "privateKey": "${PRIVATE_KEY}",
        "minClient": "",
        "maxClient": "",
        "maxTimediff": 0,
        "shortIds": ["${SHORT_ID}"],
        "settings": {
            "publicKey": "${PUBLIC_KEY}",
            "fingerprint": "chrome",
            "serverName": "",
            "spiderX": "/"
        }
    },
    "tcpSettings": {
        "acceptProxyProtocol": false,
        "header": {"type": "none"}
    }
}
ENDJSON
)

SNIFFING='{"enabled":true,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
ALLOCATE='{"strategy":"always","refresh":5,"concurrency":3}'

curl -s -o /dev/null -b "${SESSION_COOKIE}" "${API}/panel/api/inbounds/add" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "up=0" \
    --data-urlencode "down=0" \
    --data-urlencode "total=0" \
    --data-urlencode "remark=vless-reality" \
    --data-urlencode "enable=true" \
    --data-urlencode "expiryTime=0" \
    --data-urlencode "listen=" \
    --data-urlencode "port=443" \
    --data-urlencode "protocol=vless" \
    --data-urlencode "settings=${INBOUND_SETTINGS}" \
    --data-urlencode "streamSettings=${STREAM_SETTINGS}" \
    --data-urlencode "sniffing=${SNIFFING}" \
    --data-urlencode "allocate=${ALLOCATE}"

# Generate self-signed TLS cert for panel
docker exec 3x-ui openssl req -x509 -nodes -days 3650 \
    -newkey rsa:2048 \
    -keyout /root/cert/x-ui.key \
    -out /root/cert/x-ui.crt \
    -subj '/CN=localhost' 2>/dev/null

# Update panel settings (fetch all, modify, POST back — API replaces ALL settings)
python3 - "${API}" "${SESSION_COOKIE}" "${PANEL_PORT}" "${WEB_BASE_PATH}" <<'PYEOF'
import json, sys, urllib.request, urllib.parse

api, cookie, port, base_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

# Fetch current settings
req = urllib.request.Request(f"{api}/panel/setting/all", method="POST")
req.add_header("Cookie", cookie)
resp = urllib.request.urlopen(req)
settings = json.loads(resp.read())["obj"]

# Modify settings
settings["webPort"] = int(port)
settings["webBasePath"] = base_path
settings["webCertFile"] = "/root/cert/x-ui.crt"
settings["webKeyFile"] = "/root/cert/x-ui.key"

# POST updated settings as form-urlencoded
form_data = urllib.parse.urlencode(settings).encode()
req = urllib.request.Request(f"{api}/panel/setting/update", data=form_data, method="POST")
req.add_header("Cookie", cookie)
req.add_header("Content-Type", "application/x-www-form-urlencoded")
resp = urllib.request.urlopen(req)
result = json.loads(resp.read())
if not result.get("success"):
    print(f"WARNING: Settings update failed: {result.get('msg')}", file=sys.stderr)
    sys.exit(1)
PYEOF

# Update panel credentials
curl -s -o /dev/null -b "${SESSION_COOKIE}" "${API}/panel/setting/updateUser" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "oldUsername=admin" \
    --data-urlencode "oldPassword=admin" \
    --data-urlencode "newUsername=${PANEL_USER}" \
    --data-urlencode "newPassword=${PANEL_PASS}"

echo "  Panel configured."

# ─── Step 5: Restart container and update firewall ───

echo "[5/6] Restarting panel with new settings..."
docker compose restart
sleep 3

# Wait for panel on new port with HTTPS
for i in $(seq 1 30); do
    if curl -sfk -o /dev/null "https://127.0.0.1:${PANEL_PORT}${WEB_BASE_PATH}" 2>/dev/null; then
        break
    fi
    sleep 1
done

# ─── Step 6: Configure UFW ───

echo "[6/6] Configuring firewall..."
if command -v ufw &>/dev/null; then
    ufw allow 22/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
    ufw allow "${PANEL_PORT}/tcp" >/dev/null 2>&1 || true
    ufw delete allow "${DEFAULT_PORT}/tcp" >/dev/null 2>&1 || true
    echo "y" | ufw enable >/dev/null 2>&1 || true
    echo "  UFW configured (ports 22, 443, ${PANEL_PORT})."
else
    echo "  UFW not found, skipping firewall setup."
    echo "  Make sure ports 22, 443, and ${PANEL_PORT} are open."
fi

# ─── Build VLESS URI ───

VLESS_URI="vless://${CLIENT_UUID}@${SERVER_IP}:443?flow=xtls-rprx-vision&encryption=none&type=tcp&security=reality&sni=dl.google.com&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}#vless-reality"

# ─── Print summary ───

echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "  Panel URL:  https://${SERVER_IP}:${PANEL_PORT}${WEB_BASE_PATH}"
echo "  Username:   ${PANEL_USER}"
echo "  Password:   ${PANEL_PASS}"
echo ""
echo "  ⚠  Save these credentials — they are shown only once!"
echo ""
echo "  ─── VLESS URI (copy into your VPN app) ───"
echo ""
echo "  ${VLESS_URI}"
echo ""
echo "  ─── How to connect ───"
echo "  1. Install a client app (v2rayN, V2BOX, v2rayNG, etc.)"
echo "  2. Copy the VLESS URI above"
echo "  3. Import it into the app and connect"
echo ""
echo "  Install dir: ${INSTALL_DIR}"
echo "  Manage:      cd ${INSTALL_DIR} && docker compose [up -d|down|logs]"
echo "========================================="
