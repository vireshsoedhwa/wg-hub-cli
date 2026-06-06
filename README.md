# wg-hub-cli

A tiny SSH-only WireGuard client manager for a Linux WireGuard hub server.

## What It Is

A Bash CLI that lets you add WireGuard client peers by running a single command over SSH. It auto-assigns IPs, generates keys, updates the server config, and prints a QR code for mobile import.

## What It Is Not

- Not a web UI or dashboard.
- Not a replacement for Netmaker, wg-easy, or Tailscale.
- Not a full VPN orchestration platform.

## Example Topology

```text
Remote laptop / phone / tablet
        ↓ WireGuard
WireGuard hub server (runs wg-hub-cli)
        ↓ optional site-to-site peer
Home router / firewall / LAN
        ↓
NAS / internal services
```

## Features (v0.1)

- **Auto IP assignment** — picks the next free VPN IP from a configurable range.
- **Duplicate prevention** — rejects duplicate client names and IPs.
- **Keypair generation** — creates a WireGuard keypair per client.
- **Server public key derivation** — reads the server private key at runtime, no manual config needed.
- **Config from template** — renders client configs from a separate template file.
- **Backup before edit** — backs up `wg0.conf` before every change.
- **WireGuard reload** — restarts or syncconfs the interface automatically.
- **QR code output** — prints a scannable QR code for mobile devices.
- **Registry** — tracks all clients in a simple TSV file.
- **Prerequisite checks** — verifies WireGuard is installed and configured, offers to bootstrap if not.

## Requirements

- Debian 12+ / Ubuntu 22.04+ (other distros may work)
- `wireguard`, `wireguard-tools`, `qrencode`
- `bash`, `grep`, `awk`, `sed`, `systemd`

## Install

```bash
git clone https://github.com/vireshsoedhwa/wg-hub-cli.git
cd wg-hub-cli
sudo ./install.sh
```

## Configure

The installer prompts for all settings interactively with sensible defaults. Just press Enter to accept a default, or type a custom value.

To edit the config later:

```bash
sudo nano /etc/wg-hub-cli/config.env
```

Key settings:

- `SERVER_ENDPOINT` — your server's public IP/DNS and port.
- `CLIENT_ALLOWED_IPS` — routes pushed to clients.
- `RESERVED_IPS` — IPs that should never be assigned to clients.

## Add a Client

```bash
sudo wg-add-client iphone
```

The command will:

1. Pick the next available VPN IP.
2. Generate a WireGuard keypair.
3. Create a client config file.
4. Backup and update the server config.
5. Restart WireGuard.
6. Save the client in the registry.
7. Print a QR code for the WireGuard mobile app.

### Gateway Mode (Site-to-Site)

For clients that are routers with a LAN behind them (e.g. OPNsense), use `--gateway` with `--pubkey` to add the peer using a public key generated on the gateway itself:

```bash
sudo wg-add-client home-opnsense --gateway 192.168.200.0/24 --pubkey <gateway-public-key>
```

**Recommended workflow:**

1. Generate a WireGuard keypair **on the gateway** (e.g. in OPNsense's WireGuard UI).
2. Copy the gateway's **public key**.
3. Run `wg-add-client` on the hub with `--pubkey` so the private key never leaves the gateway.
4. Configure the gateway's WireGuard peer using the hub details printed after the command.

With `--pubkey`, no client config file or QR code is generated — the gateway manages its own config.

**Without `--pubkey`** (keys generated on the hub):

```bash
sudo wg-add-client home-opnsense --gateway 192.168.200.0/24
```

This generates a keypair on the hub and creates a client config file, which you'd then transfer to the gateway. Less secure since the private key leaves the hub.

Multiple subnets can be comma-separated:

```bash
sudo wg-add-client office-router --gateway 192.168.1.0/24,10.0.0.0/24 --pubkey <key>
```

## List Clients

```bash
sudo wg-list-clients
```

Prints a table of all clients with their VPN IP, status, and creation date.

## Show Client Details

```bash
sudo wg-show-client iphone
```

Shows full details for a client including live WireGuard status (endpoint, last handshake, transfer). Optionally displays the QR code again.

## Remove a Client

```bash
sudo wg-remove-client iphone
```

Removes the peer from the server config, restarts WireGuard, deletes the client config file, and marks the client as removed in the registry.

## Reset All Clients

```bash
sudo wg-reset-clients
```

Removes all peers from the server config, deletes all client configs and the registry, and restarts WireGuard. A backup of `wg0.conf` is created first. Requires typing `yes` to confirm.

## Scan QR Code

On your phone:

1. Open the WireGuard app.
2. Tap **+** → **Create from QR code**.
3. Scan the QR code printed in your terminal.
4. Activate the tunnel.

## Security Notes

- All management is SSH-only. No ports are exposed for administration.
- Client configs and private keys are stored with `600` permissions.
- The client directory is `700` (root-only access).
- Never commit generated configs or keys to version control (`.gitignore` is preconfigured).
- Use split-tunnel by default to avoid routing all traffic through the VPN unintentionally.

## File Layout

```text
/etc/wg-hub-cli/config.env              Server settings
/etc/wg-hub-cli/client.conf.template    Client config template
/usr/local/sbin/wg-add-client           Add a client
/usr/local/sbin/wg-list-clients         List all clients
/usr/local/sbin/wg-show-client          Show client details
/usr/local/sbin/wg-remove-client        Remove a client
/usr/local/sbin/wg-reset-clients       Remove all clients (full reset)
/etc/wireguard/clients/                 Generated client configs
/etc/wireguard/clients/registry.tsv     Client registry
```

## Roadmap

- ~~**v0.2** — `wg-list-clients`, `wg-show-client`, `wg-remove-client`~~ ✓
- **v0.3** — dry-run mode, config validation, rollback on failed restart
- **v0.4** — split/full tunnel profiles, custom AllowedIPs, optional DNS/MTU
- **v0.5** — multi-interface support

## Testing

```bash
./test/run-tests.sh
```

Tests use [BATS](https://github.com/bats-core/bats-core) with mock commands for `wg`, `systemctl`, etc. After cloning, initialize submodules:

```bash
git submodule update --init --recursive
```

## License

MIT