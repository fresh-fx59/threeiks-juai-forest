# 3X-UI + VLESS+Reality Quick Setup

Deploy VLESS+Reality VPN on any VPS in one command.

## Quick Start

```bash
curl -sL https://raw.githubusercontent.com/fresh-fx59/threeiks-juai-forest/main/setup.sh | sudo bash
```

## What It Does

1. Installs Docker (if not present)
2. Deploys [3X-UI](https://github.com/MHSanaei/3x-ui) panel via Docker
3. Configures UFW firewall (ports 22, 443, 2053)
4. Prints panel URL and default credentials

## After Setup

1. Open `http://YOUR_SERVER_IP:2053/` and log in (`admin`/`admin`)
2. **Change default credentials immediately**
3. Change panel port and set a random web base path
4. Create a VLESS+Reality inbound on port 443
5. Import the client link into your VPN app

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

## Management

```bash
cd /opt/3x-ui
docker compose logs -f    # View logs
docker compose restart    # Restart
docker compose down       # Stop
docker compose pull && docker compose up -d  # Update
```

## Uninstall

```bash
cd /opt/3x-ui && docker compose down
docker rmi ghcr.io/mhsanaei/3x-ui:latest
rm -rf /opt/3x-ui
```
