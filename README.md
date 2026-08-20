# openwrt-iran-split-tunnel

Automatic **Iran DIRECT / international Hysteria2** split tunneling for OpenWrt, built around **Momo + sing-box**.

The project configures transparent proxying for LAN clients while keeping Iranian destinations direct. It is designed to detect the OpenWrt release, package manager, CPU package architecture, LAN interface and router memory automatically instead of hard-coding one router model.

> Status: early public release (`0.1.x`). Test on a router you can recover before deploying remotely.

## What it does

- Iran IPs and domains -> **DIRECT**
- Other IPv4 traffic -> **Hysteria2**
- TCP -> Momo **Redirect** -> sing-box
- UDP -> Momo **TPROXY** -> sing-box
- Foreign DNS -> Cloudflare DoH **through Hysteria2**
- Iranian DNS -> local/direct resolver
- Downloads `geoip-ir.srs` and `geosite-ir.srs` from [Chocolate4U/Iran-sing-box-rules](https://github.com/Chocolate4U/Iran-sing-box-rules)
- Weekly atomic Iran rule updates with validation before replacement
- LuCI Momo GUI remains available
- Automatic low-memory Go limits on small routers
- Automatic backup before changing an existing Momo setup

## Supported systems

The installer currently targets:

- OpenWrt 24.10 (`opkg`)
- OpenWrt 25.12 (`apk`)
- Compatible OpenWrt SNAPSHOT builds
- `firewall4` / `nftables`
- Architectures for which the official Momo release publishes a matching package

Momo currently publishes release builds for many ARM, AArch64, MIPS/MIPSel, x86/i386, RISC-V and LoongArch package architectures. The installer uses OpenWrt's own `DISTRIB_ARCH` and asks GitHub for the matching release asset automatically.

A device still needs enough flash/RAM to run sing-box. No script can turn an 8 MB museum exhibit into a modern proxy gateway by sheer optimism.

## Install

SSH into the router as `root` and run:

```sh
wget -O /tmp/iran-split-install.sh \
  https://raw.githubusercontent.com/MehrooExplains/openwrt-iran-split-tunnel/main/install.sh && \
sh /tmp/iran-split-install.sh
```

The installer asks for a Hysteria2 share URI:

```text
hysteria2://password@example.com:443?...
```

The URI is parsed on the router and is **not uploaded to this repository**.

For non-interactive installation you can provide it as an environment variable:

```sh
HY2_URI='hysteria2://...' sh /tmp/iran-split-install.sh
```

## Automatic detection

The installer detects:

- OpenWrt release family
- `apk` vs `opkg`
- OpenWrt package architecture (`DISTRIB_ARCH`)
- matching Momo release asset
- logical LAN network name
- RAM size and low-memory tuning
- available overlay space before installing sing-box
- firewall4/nftables availability

It does **not** partition disks, create swap, or reformat storage automatically.

## DNS design

The generated sing-box profile uses an IPv4 DNS inbound on `0.0.0.0:1053`. Momo hijacks LAN IPv4 DNS to it.

- domains matching `geosite-ir` -> local/direct DNS
- everything else -> Cloudflare DoH (`1.1.1.1`) through the Hysteria2 outbound

This avoids the common case where the tunnel IP is correct but filtered sites still fail because DNS was resolved directly/polluted.

## IPv6

IPv6 proxying and IPv6 DNS hijacking are disabled by default in `0.1.x`. This is intentional: IPv6 behavior varies substantially across OpenWrt deployments, and enabling half-working dual stack is a creative way to manufacture leaks.

If your LAN receives globally routed IPv6 addresses, disable IPv6 on clients/LAN or configure Momo dual-stack intentionally before relying on the tunnel for IPv6 traffic.

## Iran rules

Rules are stored locally:

```text
/etc/momo/rules/geosite-ir.srs
/etc/momo/rules/geoip-ir.srs
```

Update manually:

```sh
openwrt-iran-split-update
```

A weekly cron job is installed for Sunday at 04:17. New files are downloaded to `/tmp`, validated by `sing-box check`, and only then replace the active rules.

## Health check

```sh
openwrt-iran-split-health
```

It checks Momo, sing-box, the Momo nftables table, TPROXY policy routing and the DNS/Redirect/TPROXY listeners.

From a LAN client, verify the public IP:

```sh
curl -4 https://api.ipify.org
```

Then test both an Iranian site and an international site.

## Important Momo DNS note

Momo's documentation recommends avoiding a second OpenWrt/dnsmasq "DNS Redirect" mechanism at the same time as Momo DNS hijacking. If your firmware exposes **Network -> DHCP and DNS -> DNS Redirect**, keep that separate redirect disabled when using this setup.

## Backups and uninstall

Installer backups are stored under:

```text
/etc/openwrt-iran-split-tunnel/backups/
```

To remove this project's profile/rules/helpers:

```sh
wget -O /tmp/iran-split-uninstall.sh \
  https://raw.githubusercontent.com/MehrooExplains/openwrt-iran-split-tunnel/main/uninstall.sh && \
sh /tmp/iran-split-uninstall.sh
```

The uninstall script intentionally keeps `momo`, `luci-app-momo`, and `sing-box` installed. It does not assume this project is the only reason those packages exist.

## Security

- Never commit a real Hysteria2 URI, password, certificate, API token or exported router backup.
- The installer downloads Momo only from `nikkinikki-org/OpenWrt-momo` releases.
- Iran rule sets come from `Chocolate4U/Iran-sing-box-rules`, with jsDelivr used only as a download fallback.
- Existing Momo configuration is backed up before modification.

## Scope

This repository deliberately focuses on one scenario:

**OpenWrt + Momo + sing-box + Hysteria2 + Iran split routing.**

OpenVPN, OpenConnect and a pile of unrelated backends are intentionally outside the initial scope. Small projects are easier to understand, test and maintain. Humanity has already produced enough configuration frameworks that require a framework to configure the framework.

## License

MIT License. Use it, modify it, fork it, redistribute it, or use it commercially while retaining the license notice.

## Upstream projects

- [nikkinikki-org/OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo)
- [SagerNet/sing-box](https://github.com/SagerNet/sing-box)
- [Chocolate4U/Iran-sing-box-rules](https://github.com/Chocolate4U/Iran-sing-box-rules)
