#!/bin/sh
# SPDX-License-Identifier: MIT
set -eu

PROFILE="/etc/momo/profiles/iran-split-hy2.json"
RULE_DIR="/etc/momo/rules"
GEO_SITE="$RULE_DIR/geosite-ir.srs"
GEO_IP="$RULE_DIR/geoip-ir.srs"
TMP="/tmp/openwrt-iran-split-rules.$$"

GH_SITE="https://raw.githubusercontent.com/Chocolate4U/Iran-sing-box-rules/rule-set/geosite-ir.srs"
GH_IP="https://raw.githubusercontent.com/Chocolate4U/Iran-sing-box-rules/rule-set/geoip-ir.srs"
CDN_SITE="https://cdn.jsdelivr.net/gh/Chocolate4U/Iran-sing-box-rules@rule-set/geosite-ir.srs"
CDN_IP="https://cdn.jsdelivr.net/gh/Chocolate4U/Iran-sing-box-rules@rule-set/geoip-ir.srs"

log() { printf '%s\n' "[+] $*"; }
warn() { printf '%s\n' "[!] $*" >&2; }
cleanup() { rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
mkdir -p "$TMP" "$RULE_DIR"

fetch_to() {
    url="$1"; out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --connect-timeout 20 --retry 2 -o "$out" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$out" "$url"
    else
        uclient-fetch -O "$out" "$url"
    fi
}
fetch_pair() {
    primary="$1"; fallback="$2"; out="$3"
    fetch_to "$primary" "$out" || fetch_to "$fallback" "$out"
}

fetch_pair "$GH_SITE" "$CDN_SITE" "$TMP/geosite-ir.srs"
fetch_pair "$GH_IP" "$CDN_IP" "$TMP/geoip-ir.srs"
[ -s "$TMP/geosite-ir.srs" ] || { warn "geosite download is empty"; exit 1; }
[ -s "$TMP/geoip-ir.srs" ] || { warn "geoip download is empty"; exit 1; }

# Validate the new binary rule sets without touching the working copies.
[ -f "$PROFILE" ] || { warn "Profile not found: $PROFILE"; exit 1; }
CHECK_CFG="$TMP/check.json"
sed \
    -e "s#${GEO_SITE}#${TMP}/geosite-ir.srs#g" \
    -e "s#${GEO_IP}#${TMP}/geoip-ir.srs#g" \
    "$PROFILE" > "$CHECK_CFG"
sing-box check -c "$CHECK_CFG" >/dev/null

same=1
if [ ! -f "$GEO_SITE" ] || ! cmp -s "$TMP/geosite-ir.srs" "$GEO_SITE"; then same=0; fi
if [ ! -f "$GEO_IP" ] || ! cmp -s "$TMP/geoip-ir.srs" "$GEO_IP"; then same=0; fi
if [ "$same" = "1" ]; then
    log "Iran rule sets are already current."
    exit 0
fi

[ -f "$GEO_SITE" ] && cp "$GEO_SITE" "$TMP/geosite-old.srs" || true
[ -f "$GEO_IP" ] && cp "$GEO_IP" "$TMP/geoip-old.srs" || true
cp "$TMP/geosite-ir.srs" "$GEO_SITE.new"
cp "$TMP/geoip-ir.srs" "$GEO_IP.new"
mv "$GEO_SITE.new" "$GEO_SITE"
mv "$GEO_IP.new" "$GEO_IP"
chmod 644 "$GEO_SITE" "$GEO_IP"

was_running=0
if [ "$(/etc/init.d/momo status 2>/dev/null || true)" = "running" ]; then was_running=1; fi
if [ "$was_running" = "1" ]; then
    if ! /etc/init.d/momo restart >/dev/null 2>&1; then
        warn "Momo restart failed; restoring previous rule sets."
        [ -f "$TMP/geosite-old.srs" ] && cp "$TMP/geosite-old.srs" "$GEO_SITE" || true
        [ -f "$TMP/geoip-old.srs" ] && cp "$TMP/geoip-old.srs" "$GEO_IP" || true
        /etc/init.d/momo restart >/dev/null 2>&1 || true
        exit 1
    fi
fi
log "Iran rule sets updated and validated."
