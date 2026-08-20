#!/bin/sh
# SPDX-License-Identifier: MIT
# Conservative uninstall: removes this project's configuration and helpers but
# deliberately keeps Momo and sing-box packages installed.

set -eu
PROJECT="openwrt-iran-split-tunnel"
STATE_DIR="/etc/$PROJECT"
PROFILE="/etc/momo/profiles/iran-split-hy2.json"

/etc/init.d/momo stop >/dev/null 2>&1 || true
uci set momo.config.enabled='0' 2>/dev/null || true
uci commit momo 2>/dev/null || true

rm -f "$PROFILE"
rm -f /etc/momo/rules/geosite-ir.srs /etc/momo/rules/geoip-ir.srs
rm -f /usr/bin/openwrt-iran-split-update /usr/bin/openwrt-iran-split-health
sed -i '/# openwrt-iran-split-tunnel rules/d' /etc/crontabs/root 2>/dev/null || true
/etc/init.d/cron restart >/dev/null 2>&1 || true

printf '%s\n' "Project configuration removed."
printf '%s\n' "Momo and sing-box packages were intentionally kept installed."
printf '%s\n' "Backups, if any, remain under $STATE_DIR/backups/."
