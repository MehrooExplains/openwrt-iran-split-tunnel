# openwrt-iran-split-tunnel

<p align="center">
  <strong>English</strong> | <a href="README.fa.md">فارسی</a>
</p>

Automatic **Iran / international traffic split tunneling** for OpenWrt using **Momo + sing-box + Hysteria2**.

This project is built for a simple goal:

- Iranian domains and IP ranges go **DIRECT** through the normal WAN connection.
- International traffic goes through **Hysteria2**.
- TCP and UDP are both handled.
- Foreign DNS queries are resolved through the tunnel to reduce DNS pollution issues.
- Installation is designed to be as automatic and device-independent as possible across supported OpenWrt targets.

> Project status: early public release (`0.1.x`). Test it on recoverable hardware before relying on it on a critical router.

## How it works

```text
LAN / Wi-Fi
     |
     v
    Momo
     |
     v
  sing-box
   /     \
  /       \
Iran    Foreign
DIRECT  Hysteria2
```

Traffic flow:

- Iranian IPs and domains → **DIRECT**
- Other IPv4 traffic → **Hysteria2**
- TCP → Momo Redirect → sing-box
- UDP → Momo TPROXY → sing-box
- Iranian DNS → direct resolver
- Foreign DNS → Cloudflare DoH through Hysteria2

Iran routing data is provided by [Chocolate4U/Iran-sing-box-rules](https://github.com/Chocolate4U/Iran-sing-box-rules):

```text
geosite-ir.srs
geoip-ir.srs
```

## Supported systems

The installer is designed for:

- OpenWrt `24.10` using `opkg`
- OpenWrt `25.12` using `apk`
- Compatible OpenWrt Snapshot builds
- `firewall4`
- `nftables`
- Architectures for which Momo publishes an official package

The installer automatically attempts to detect:

- OpenWrt release
- package manager (`apk` or `opkg`)
- OpenWrt package architecture from `DISTRIB_ARCH`
- device model
- available RAM and Overlay space
- the matching Momo package for the detected OpenWrt release and architecture

The project is not tied to one Linksys, TP-Link, Xiaomi, GL.iNet, x86, or other specific device model. The router still needs enough storage and memory to run Momo and sing-box. Physics remains annoyingly undefeated.

## Installation

SSH into your OpenWrt router:

```sh
ssh root@192.168.1.1
```

Use your router's actual IP address if it is different.

Then run:

```sh
wget -O /tmp/iran-split-install.sh \
  https://raw.githubusercontent.com/MehrooExplains/openwrt-iran-split-tunnel/main/install.sh && \
sh /tmp/iran-split-install.sh
```

During installation, the script asks for your Hysteria2 URI:

```text
Paste your Hysteria2 URI:
> hysteria2://...
```

Your real URI, password, and server credentials are processed locally on the router and are **not uploaded to this repository**.

### Non-interactive installation

You can also pass the URI through an environment variable:

```sh
HY2_URI='hysteria2://...' sh /tmp/iran-split-install.sh
```

## DNS design

A common failure mode is deceptively annoying: the tunnel is connected and an external IP is visible, but sites such as YouTube still fail to load. A direct or polluted DNS path is often the reason.

For IPv4, the project creates a sing-box DNS inbound on:

```text
0.0.0.0:1053
```

Momo redirects LAN client DNS traffic to that inbound.

```text
Client DNS
    |
    v
Momo DNS Hijack
    |
    v
sing-box
   /     \
Iran   Foreign
Direct  Cloudflare DoH
        through Hysteria2
```

If your OpenWrt firmware also has a separate **DNS Redirect** feature enabled, avoid running a second DNS hijack path at the same time unless you know exactly how the two interact. Two competing DNS interception systems are an excellent way to turn a simple network into performance art.

## Iran rule sets

The downloaded rule sets are stored on the router at:

```text
/etc/momo/rules/geosite-ir.srs
/etc/momo/rules/geoip-ir.srs
```

To update them manually:

```sh
openwrt-iran-split-update
```

The updater downloads and validates new files before replacing the current rules. If the update fails, the last known-good files are kept.

## Health check

After installation:

```sh
openwrt-iran-split-health
```

The health checker verifies the important runtime pieces, including Momo, sing-box, nftables, policy routing, and the DNS/Redirect/TPROXY listeners.

From a device connected to the router, you can check the external IPv4 address with:

```sh
curl -4 https://api.ipify.org
```

International traffic should show the Hysteria2 exit IP.

## IPv6

In `0.1.x`, IPv6 proxying and IPv6 DNS hijacking are disabled by default. The current goal is a predictable IPv4 setup across a wide range of OpenWrt networks.

If your network has public IPv6, review Dual Stack behavior separately before relying on the tunnel for IPv6 traffic.

## Low-memory routers

The installer checks available RAM and Overlay storage. It intentionally does **not**:

- repartition storage
- format USB devices
- automatically create Swap

An installer that silently reformats storage is less of an installer and more of an incident report waiting to happen.

## Backups

Before changing important existing settings, backups are stored under:

```text
/etc/openwrt-iran-split-tunnel/backups/
```

## Uninstall

```sh
wget -O /tmp/iran-split-uninstall.sh \
  https://raw.githubusercontent.com/MehrooExplains/openwrt-iran-split-tunnel/main/uninstall.sh && \
sh /tmp/iran-split-uninstall.sh
```

The uninstaller intentionally does not remove Momo, the Momo LuCI app, or sing-box, because users may rely on those packages for other configurations.

## Security

Do not post any of the following in public Issues, commits, or files:

```text
Real Hysteria2 URI
Password
Certificate
API token
Full router backup
```

Momo is downloaded from official releases of [nikkinikki-org/OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo).

## Project scope

The current release intentionally focuses on one setup:

```text
OpenWrt + Momo + sing-box + Hysteria2
Iran DIRECT / Foreign Proxy
```

## License

This project is released under the [MIT License](LICENSE).
