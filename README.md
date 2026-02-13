# 3X-UI + VLESS+Reality Quick Setup

Deploy VLESS+Reality VPN on any VPS in one command.

## Quick Start

```bash
curl -sL https://raw.githubusercontent.com/fresh-fx59/threeiks-juai-forest/main/setup.sh | sudo bash
```

> **Note**: Do NOT use `sudo bash <(curl ...)` — process substitution fails on many servers. Always use the pipe syntax above.

## What It Does

1. Installs Docker (if not present)
2. Deploys [3X-UI](https://github.com/MHSanaei/3x-ui) panel via Docker
3. Configures UFW firewall (ports 22, 443, 2053)
4. Prints panel URL and default credentials

## After Setup

1. Open `http://YOUR_SERVER_IP:2053/` and log in (`admin`/`admin`)
2. **Change default credentials immediately**
3. Change panel port and set a random web base path (e.g., `/a8Kx9mP2/`)
4. Create a VLESS+Reality inbound on port 443:
   - Protocol: `vless`, Port: `443`, Flow: `xtls-rprx-vision`
   - Security: `reality`, uTLS: `chrome`, click **Get New Cert**
   - Dest: `dl.google.com:443`, SNI: `dl.google.com`
5. Copy the VLESS URI and import it into your client app

## Requirements

- VPS with Ubuntu 22.04+
- Root or sudo access
- Port 443 available

## Client Apps

| Platform | App |
|----------|-----|
| Windows | [v2rayN](https://github.com/2dust/v2rayN) |
| macOS/iOS | [V2BOX](https://apps.apple.com/app/v2box-v2ray-client/id6446814690) |
| Android | [v2rayNG](https://github.com/2dust/v2rayNG) |
| Linux | [Nekoray](https://github.com/MatsuriDayo/nekoray) |

## Security Checklist

- [ ] Change default username and password
- [ ] Change panel port from `2053` to a random port
- [ ] Set a random web base path (never leave as `/`)
- [ ] Enable HTTPS for the panel with a self-signed cert
- [ ] Harden SSH (disable password auth, use keys only)

## DNS Leak Prevention

VLESS+Reality clients resolve DNS remotely through the tunnel by default — no additional configuration needed. The server's default `geoip:private` routing rule blocks access to private IP ranges through the tunnel.

## Management

```bash
cd /opt/3x-ui
sudo docker compose logs -f    # View logs
sudo docker compose restart    # Restart
sudo docker compose down       # Stop
sudo docker compose pull && sudo docker compose up -d  # Update
```

## Uninstall

```bash
cd /opt/3x-ui && sudo docker compose down
sudo docker rmi ghcr.io/mhsanaei/3x-ui:latest
sudo rm -rf /opt/3x-ui
```
