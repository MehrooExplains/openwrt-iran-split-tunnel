# Troubleshooting

## Public IP is foreign, but YouTube/Facebook do not open

Check DNS first. This project intentionally uses:

- `dns-in` on `0.0.0.0:1053`
- Momo IPv4 DNS hijack enabled
- foreign DNS over Cloudflare DoH through `hy2-out`
- Iran-domain DNS through the local/direct resolver

On the router:

```sh
/etc/init.d/momo status
busybox netstat -lnptu 2>/dev/null | grep -E ':1053|:7891|:7892'
nft list table inet momo
```

From a LAN client:

```sh
nslookup youtube.com ROUTER_LAN_IP
curl -4 --connect-timeout 15 -I https://www.youtube.com
curl -4 https://api.ipify.org
```

If `nslookup` fails, inspect the Momo app/core logs before changing routing rules.

## `table inet momo` does not exist

If Momo reports `running` but this fails:

```sh
nft list table inet momo
```

check the generated firewall template:

```sh
utpl -S /etc/momo/ucode/hijack.ut > /tmp/momo-hijack.nft
nft -c -f /tmp/momo-hijack.nft
```

A known failure mode is a generated rule jumping to `lan_dns_hijack` when that chain was not generated. The installer refreshes `hijack.ut` from the exact Momo release tag to avoid stale packaged templates.

## TPROXY policy routing

Expected checks:

```sh
ip rule show | grep -E '0x80|lookup 80'
ip route show table 80
```

Typical route table output includes:

```text
local default dev lo scope host
```

Ensure these packages are installed:

```sh
# OpenWrt 25.12+
apk list -I | grep -E 'kmod-nft-tproxy|kmod-nft-socket|ip-full|firewall4'

# OpenWrt 24.10
opkg list-installed | grep -E 'kmod-nft-tproxy|kmod-nft-socket|ip-full|firewall4'
```

## IPv6 leaks/direct traffic

The initial release proxies IPv4 only. IPv6 proxying and IPv6 DNS hijacking are disabled by default. If your LAN has globally routed IPv6, either disable IPv6 for this deployment or configure Momo dual-stack deliberately.

## Another transparent proxy is installed

PassWall/PassWall2, OpenClash, HomeProxy, Nikki, policy-routing packages, and hand-written nftables rules can conflict with Momo. Disable competing transparent-proxy engines while testing this project.

## Restore a backup

Backups created before installation are kept under:

```text
/etc/openwrt-iran-split-tunnel/backups/
```

The project does not automatically erase these backups during uninstall.
