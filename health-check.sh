#!/bin/sh
# SPDX-License-Identifier: MIT

ok=0
bad=0
pass() { printf '[OK] %s\n' "$*"; ok=$((ok + 1)); }
fail() { printf '[FAIL] %s\n' "$*"; bad=$((bad + 1)); }
warn() { printf '[WARN] %s\n' "$*"; }

if [ "$(/etc/init.d/momo status 2>/dev/null)" = "running" ]; then pass "Momo is running"; else fail "Momo is not running"; fi
# OpenWrt BusyBox does not guarantee pgrep, so inspect its portable ps output.
# shellcheck disable=SC2009
if ps w 2>/dev/null | grep '[s]ing-box.*momo' >/dev/null; then pass "sing-box is running under Momo"; else fail "sing-box process was not found"; fi
if nft list table inet momo >/dev/null 2>&1; then pass "nftables table inet momo exists"; else fail "nftables table inet momo is missing"; fi
if ip rule show 2>/dev/null | grep -q 'fwmark 0x80.*lookup 80'; then pass "TPROXY policy rule exists"; else fail "TPROXY policy rule is missing"; fi
if ip route show table 80 2>/dev/null | grep -q 'local default dev lo'; then pass "TPROXY route table 80 exists"; else fail "TPROXY route table 80 is missing"; fi
if busybox netstat -lnptu 2>/dev/null | grep -q ':1053'; then pass "DNS inbound is listening on port 1053"; else fail "DNS inbound port 1053 is not listening"; fi
if busybox netstat -lnptu 2>/dev/null | grep -q ':7891'; then pass "TCP redirect inbound is listening on 7891"; else fail "TCP redirect inbound 7891 is not listening"; fi
if busybox netstat -lnptu 2>/dev/null | grep -q ':7892'; then pass "UDP TPROXY inbound is listening on 7892"; else fail "UDP TPROXY inbound 7892 is not listening"; fi

if [ -f /proc/swaps ]; then
    swap_used="$(awk 'NR>1 {s+=$4} END {print s+0}' /proc/swaps)"
    if [ "$swap_used" -gt 0 ] 2>/dev/null; then
        warn "Swap is currently in use: ${swap_used} KiB"
    else
        pass "Swap pressure is currently zero"
    fi
fi

printf '\nChecks passed: %s | failed: %s\n' "$ok" "$bad"
[ "$bad" -eq 0 ]
