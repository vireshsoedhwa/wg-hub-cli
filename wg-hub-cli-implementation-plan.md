# wg-hub-cli Implementation Plan

## 1. Project Summary

**Project name:** `wg-hub-cli`

`wg-hub-cli` is a small SSH-only command-line toolkit for managing WireGuard clients on a WireGuard hub server.

The project is intentionally lightweight. It does **not** provide a web UI, dashboard, API, Docker stack, or exposed admin panel. It is designed for users who want to manage WireGuard peers securely over SSH.

The tool should work on any Linux server that acts as a WireGuard hub, including:

- A VPS
- A home server
- A dedicated bare-metal server
- A Debian/Ubuntu VM
- A cloud instance
- A small Linux appliance
- A lab server behind another router, if reachable by peers

The server does not have to be a VPS. The only assumption is that the server is the central WireGuard hub where peer configs are managed.

---

## 2. Primary Use Case

A user has a WireGuard hub server and wants to add client devices easily.

Example topology:

```text
Remote laptop / phone / tablet
        ↓ WireGuard
WireGuard hub server
        ↓ optional site-to-site peer
Home router / firewall / LAN
        ↓
NAS / internal services
```

The user wants to run:

```bash
sudo wg-add-client iphone
```

and have the tool automatically:

1. Pick the next available VPN IP.
2. Generate a WireGuard keypair.
3. Create a client config.
4. Add the client peer to the server WireGuard config.
5. Restart or reload WireGuard safely.
6. Save the client in a registry.
7. Print a QR code for easy mobile import.

---

## 3. Design Goals

### Must Have

- SSH-only management.
- No exposed web admin interface.
- No database required.
- No Docker required.
- Bash-based first version.
- Works with plain WireGuard.
- Auto-assigns client VPN IPs.
- Prevents duplicate IP assignment.
- Prevents duplicate client names.
- Creates backups before editing WireGuard config.
- Keeps client configs private with secure permissions.
- Supports QR code output for phones.
- Supports both remote-access clients and site-to-site hub patterns.

### Nice to Have Later

- Remove/revoke client.
- List clients.
- Show client config again.
- Show QR code again.
- Show latest handshake/status.
- Support custom AllowedIPs per client.
- Support optional DNS setting.
- Support full-tunnel clients.
- Support multiple WireGuard interfaces.
- Support dry-run mode.
- Support config validation before applying changes.

### Explicit Non-Goals for v0.1

- No web UI.
- No multi-user admin system.
- No OAuth/SSO.
- No Kubernetes.
- No complex database.
- No automatic firewall management in v0.1.
- No full replacement for Netmaker, wg-easy, or Tailscale.

---

## 4. Target Platforms

Initial target:

```text
Debian 12+
Debian 13+
Ubuntu 22.04+
Ubuntu 24.04+
Ubuntu 26.04+
```

The tool should rely on common packages:

```text
wireguard
wireguard-tools
qrencode
systemd
bash
grep
awk
sed
```

Optional future support:

```text
Alpine Linux
Fedora
Arch Linux
FreeBSD-style systems
```

---

## 5. Recommended Repository Structure

```text
wg-hub-cli/
├── README.md
├── LICENSE
├── .gitignore
├── install.sh
├── uninstall.sh
├── shellcheck.sh
├── config/
│   └── wg-hub-cli.example.env
├── bin/
│   ├── wg-add-client
│   ├── wg-list-clients
│   ├── wg-show-client
│   └── wg-remove-client
├── templates/
│   └── client.conf.template
└── docs/
    ├── getting-started.md
    ├── server-setup.md
    ├── opnsense-site-to-site.md
    ├── security-notes.md
    └── troubleshooting.md
```

For v0.1, keep it smaller:

```text
wg-hub-cli/
├── README.md
├── LICENSE
├── .gitignore
├── install.sh
├── config/
│   └── wg-hub-cli.example.env
└── bin/
    └── wg-add-client
```

---

## 6. Configuration File

The project should not hardcode server IPs, subnets, paths, or interface names inside the script.

Use:

```text
/etc/wg-hub-cli/config.env
```

Example:

```bash
# WireGuard interface and config
WG_INTERFACE="wg0"
WG_CONF="/etc/wireguard/wg0.conf"

# Generated client configs and registry
CLIENT_DIR="/etc/wireguard/clients"
REGISTRY="/etc/wireguard/clients/registry.tsv"

# VPN addressing
VPN_SUBNET_PREFIX="10.50.0"
CLIENT_START="10"
CLIENT_END="250"

# Server endpoint reachable by clients
# This can be a VPS IP, public server IP, DNS name, or DDNS name.
SERVER_ENDPOINT="your-server.example.com:51820"

# Client routes
# Split tunnel example:
CLIENT_ALLOWED_IPS="10.50.0.0/24, 192.168.200.0/24"

# Optional DNS pushed to clients.
# Leave empty by default to avoid breaking normal internet.
CLIENT_DNS=""

# Reserved VPN IPs.
# Example:
# 10.50.0.1 = hub server
# 10.50.0.2 = site-to-site router/firewall
RESERVED_IPS="10.50.0.1 10.50.0.2"

# WireGuard restart mode
# Options for future use: restart, syncconf
APPLY_MODE="restart"
```

---

## 7. Generated Files

The tool should create:

```text
/etc/wireguard/clients/
├── iphone.conf
├── ipad.conf
├── macbook.conf
└── registry.tsv
```

Example registry:

```text
name	ip	public_key	status	created_at
iphone	10.50.0.11	CLIENT_PUBLIC_KEY	active	2026-06-06T10:15:00Z
ipad	10.50.0.12	CLIENT_PUBLIC_KEY	active	2026-06-06T10:20:00Z
```

Use tab-separated values to keep it simple.

Permissions:

```text
/etc/wireguard/clients/              700
/etc/wireguard/clients/*.conf        600
/etc/wireguard/clients/registry.tsv  600
/etc/wg-hub-cli/config.env           600
```

---

## 8. Command Design

### v0.1 Command

```bash
sudo wg-add-client <client-name>
```

Example:

```bash
sudo wg-add-client iphone
```

Expected behavior:

1. Load `/etc/wg-hub-cli/config.env`.
2. Validate root permissions.
3. Validate dependencies.
4. Validate client name.
5. Check that the client does not already exist.
6. Find next free VPN IP.
7. Generate client keypair.
8. Create client config.
9. Backup server WireGuard config.
10. Append new peer block.
11. Restart WireGuard.
12. Save client to registry.
13. Print config path.
14. Print QR code.

---

## 9. Future Commands

### List Clients

```bash
sudo wg-list-clients
```

Example output:

```text
Name       VPN IP        Status    Latest handshake
macbook    10.50.0.10    active    2 minutes ago
iphone     10.50.0.11    active    never
ipad       10.50.0.12    active    1 hour ago
```

### Show Client Config

```bash
sudo wg-show-client iphone
```

Prints the saved config.

QR mode:

```bash
sudo wg-show-client iphone --qr
```

### Remove Client

```bash
sudo wg-remove-client iphone
```

Expected behavior:

1. Backup `wg0.conf`.
2. Remove the matching peer block.
3. Mark client as revoked in registry.
4. Move config to an archive folder.
5. Restart/reload WireGuard.
6. Do not automatically reuse the revoked IP in v0.1/v0.2.

---

## 10. Server-Side WireGuard Config Pattern

The tool should assume the server already has a working WireGuard interface.

Example:

```ini
[Interface]
Address = 10.50.0.1/24
ListenPort = 51820
PrivateKey = SERVER_PRIVATE_KEY

PostUp = iptables -A FORWARD -i wg0 -o wg0 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -o wg0 -j ACCEPT

[Peer]
# Site-to-site firewall/router
PublicKey = SITE_ROUTER_PUBLIC_KEY
AllowedIPs = 10.50.0.2/32, 192.168.200.0/24
```

When adding a normal client, the tool appends:

```ini
[Peer]
# iphone
PublicKey = CLIENT_PUBLIC_KEY
AllowedIPs = 10.50.0.11/32
```

Important distinction:

```text
Normal remote client:
  AllowedIPs = one client /32 only on the server

Site-to-site peer:
  AllowedIPs = peer /32 plus LAN subnet(s) behind that peer
```

---

## 11. Client Config Pattern

Default split-tunnel client config:

```ini
[Interface]
PrivateKey = CLIENT_PRIVATE_KEY
Address = 10.50.0.11/24

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = your-server.example.com:51820
AllowedIPs = 10.50.0.0/24, 192.168.200.0/24
PersistentKeepalive = 25
```

Optional DNS should only be included if configured:

```ini
DNS = 192.168.200.1
```

Default should be no DNS line, because bad DNS settings can make users think their internet is broken.

---

## 12. IP Assignment Logic

The script should auto-pick a free IP.

Example range:

```text
10.50.0.10 - 10.50.0.250
```

Skip:

```text
10.50.0.1  server
10.50.0.2  site-to-site firewall/router
any IP already in wg0.conf
any IP already in registry.tsv
```

Duplicate IP protection should check:

```bash
grep -q "$CANDIDATE_IP/32" "$WG_CONF"
grep -q "$CANDIDATE_IP" "$REGISTRY"
```

If no free IP is found:

```text
Error: no free VPN IPs available.
```

---

## 13. Client Name Validation

Allow only safe names:

```text
letters
numbers
hyphen
underscore
dot
```

Regex:

```bash
^[a-zA-Z0-9._-]+$
```

Reject names like:

```text
my phone
iphone;rm -rf /
../../../test
```

This prevents path traversal and shell injection problems.

---

## 14. Safety Requirements

Before editing `wg0.conf`, always back it up:

```bash
cp /etc/wireguard/wg0.conf "/etc/wireguard/wg0.conf.bak.$(date +%Y%m%d-%H%M%S)"
```

Before restart, basic validation should check:

```text
No placeholder keys
No duplicate AllowedIPs
No empty PublicKey
No empty PrivateKey
wg0.conf exists
```

After restart:

```bash
systemctl status wg-quick@wg0 --no-pager -l
wg show
```

If restart fails, the script should print the backup path and recovery command.

Example:

```bash
cp /etc/wireguard/wg0.conf.bak.20260606-101500 /etc/wireguard/wg0.conf
systemctl restart wg-quick@wg0
```

---

## 15. Install Script Plan

`install.sh` should:

1. Check that it is running as root.
2. Detect supported OS.
3. Install dependencies if possible:
   - `wireguard`
   - `wireguard-tools`
   - `qrencode`
4. Create `/etc/wg-hub-cli`.
5. Copy example config if no config exists.
6. Copy `bin/wg-add-client` to `/usr/local/sbin/wg-add-client`.
7. Create `/etc/wireguard/clients`.
8. Set permissions.
9. Print next steps.

Example install flow:

```bash
git clone https://github.com/YOUR_USERNAME/wg-hub-cli.git
cd wg-hub-cli
sudo ./install.sh
sudo nano /etc/wg-hub-cli/config.env
sudo wg-add-client iphone
```

---

## 16. `.gitignore`

Use a defensive `.gitignore`:

```gitignore
# Never commit real WireGuard secrets or generated configs
*.key
*.conf
*.env
config.env
clients/
registry.tsv

# Local testing
tmp/
.DS_Store

# Editor files
*.swp
*.swo
.vscode/
.idea/
```

Important: the repo should include only:

```text
config/wg-hub-cli.example.env
templates/client.conf.template
```

It should never include real keys or real client configs.

---

## 17. README Plan

README sections:

```text
# wg-hub-cli

## What it is
A tiny SSH-only WireGuard client manager for a Linux WireGuard hub.

## What it is not
Not a web UI, not a dashboard, not a replacement for Netmaker/wg-easy/Tailscale.

## Supported servers
VPS, home server, VM, cloud instance, bare-metal Linux server.

## Example topology

## Features

## Requirements

## Install

## Configure

## Add a client

## Scan QR code

## OPNsense/site-to-site notes

## Security notes

## Troubleshooting

## Roadmap
```

---

## 18. Documentation Files

### `docs/server-setup.md`

Explain how to prepare any Linux server:

```text
Install WireGuard
Enable IP forwarding
Open UDP 51820
Create initial wg0.conf
Start wg-quick@wg0
```

Keep this generic. Do not assume DigitalOcean.

### `docs/opnsense-site-to-site.md`

Explain the optional pattern:

```text
OPNsense peer connects to hub server
Hub has AllowedIPs = 10.50.0.2/32, home LAN subnet
Clients route home LAN through hub
OPNsense firewall permits selected client access
```

### `docs/security-notes.md`

Cover:

```text
Do not expose SMB directly
Do not expose web admin panels
Keep private keys private
Use SSH keys
Use UFW/nftables/firewall
Use split tunnel unless full tunnel is intended
Back up configs
Do not commit generated client configs
```

### `docs/troubleshooting.md`

Common issues:

```text
No handshake
Duplicate AllowedIPs
Internet stops when VPN activates
Client can ping server but not LAN
SMB port 445 hangs
Firewall blocks
Wrong endpoint
Wrong public key
```

---

## 19. Version Roadmap

### v0.1

Core add-client functionality.

```text
wg-add-client
auto IP assignment
config.env
registry.tsv
QR code output
backup before edit
restart WireGuard
```

### v0.2

Basic management commands.

```text
wg-list-clients
wg-show-client
wg-show-client --qr
wg-remove-client
```

### v0.3

Safer apply behavior.

```text
dry-run mode
config validation
duplicate AllowedIPs detection
rollback on failed restart
better status output
```

### v0.4

More flexible client profiles.

```text
split-tunnel profile
full-tunnel profile
custom AllowedIPs
optional DNS
optional MTU
```

### v0.5

Multi-interface support.

```text
support wg0, wg1, etc.
per-interface registry
per-interface config
```

---

## 20. Suggested First Coding Task

Implement `bin/wg-add-client` with this minimum behavior:

```text
Load config.env
Validate root
Validate client name
Find next free IP
Generate keys
Create client config
Backup wg0.conf
Append peer block
Restart wg-quick@wg0
Write registry entry
Print QR code
```

Then test on a disposable WireGuard server before using it on the real hub.

---

## 21. Acceptance Criteria for v0.1

The v0.1 release is complete when:

1. `sudo ./install.sh` installs the command.
2. `/etc/wg-hub-cli/config.env` controls server settings.
3. `sudo wg-add-client iphone` creates a unique client config.
4. The new client appears in `/etc/wireguard/clients/registry.tsv`.
5. The new peer appears in `/etc/wireguard/wg0.conf`.
6. `wg-quick@wg0` restarts successfully.
7. The QR code imports correctly into the WireGuard mobile app.
8. The client can connect and handshake.
9. Duplicate client names are rejected.
10. Duplicate IPs are avoided.

---

## 22. Example Final User Workflow

Install once:

```bash
git clone https://github.com/YOUR_USERNAME/wg-hub-cli.git
cd wg-hub-cli
sudo ./install.sh
sudo nano /etc/wg-hub-cli/config.env
```

Add a device:

```bash
sudo wg-add-client iphone
```

On the phone:

```text
Open WireGuard app
Tap +
Scan QR code
Activate tunnel
```

Check server:

```bash
sudo wg show
```

That is the intended long-term workflow.
