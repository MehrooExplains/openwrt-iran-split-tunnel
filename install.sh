Failed to create stream fd: Operation not permitted
Failed to create stream fd: Operation not permitted
Failed to create stream fd: Operation not permitted
#!/bin/sh
# openwrt-iran-split-tunnel
# Automatic Iran DIRECT / international Hysteria2 split tunneling for OpenWrt.
# SPDX-License-Identifier: MIT

set -eu

PROJECT="openwrt-iran-split-tunnel"
PROJECT_REPO="${PROJECT_REPO:-MehrooExplains/openwrt-iran-split-tunnel}"
PROJECT_BRANCH="${PROJECT_BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/${PROJECT_REPO}/${PROJECT_BRANCH}"
MOMO_REPO="nikkinikki-org/OpenWrt-momo"
MOMO_API="https://api.github.com/repos/${MOMO_REPO}/releases/latest"
RULE_GEOSITE_GH="https://raw.githubusercontent.com/Chocolate4U/Iran-sing-box-rules/rule-set/geosite-ir.srs"
RULE_GEOIP_GH="https://raw.githubusercontent.com/Chocolate4U/Iran-sing-box-rules/rule-set/geoip-ir.srs"
RULE_GEOSITE_CDN="https://cdn.jsdelivr.net/gh/Chocolate4U/Iran-sing-box-rules@rule-set/geosite-ir.srs"
RULE_GEOIP_CDN="https://cdn.jsdelivr.net/gh/Chocolate4U/Iran-sing-box-rules@rule-set/geoip-ir.srs"
STATE_DIR="/etc/${PROJECT}"
PROFILE_DIR="/etc/momo/profiles"
PROFILE_NAME="iran-split-hy2.json"
PROFILE="${PROFILE_DIR}/${PROFILE_NAME}"
RULE_DIR="/etc/momo/rules"
TMP_DIR="/tmp/${PROJECT}.$$"
BACKUP_DIR="${STATE_DIR}/backups/$(date +%Y%m%d-%H%M%S)"

log() { printf '%s\n' "[+] $*"; }
warn() { printf '%s\n' "[!] $*" >&2; }
die() { printf '%s\n' "[x] $*" >&2; exit 1; }

cleanup() { rm -rf "$TMP_DIR" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

[ "$(id -u)" = "0" ] || die "Run this installer as root."
[ -r /etc/openwrt_release ] || die "This installer is for OpenWrt only."
# shellcheck source=/dev/null
. /etc/openwrt_release

mkdir -p "$TMP_DIR" "$STATE_DIR" "$BACKUP_DIR"

fetch_to() {
    url="$1"
    out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --connect-timeout 20 --retry 2 --retry-delay 2 -o "$out" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$out" "$url"
    elif command -v uclient-fetch >/dev/null 2>&1; then
        uclient-fetch -O "$out" "$url"
    else
        die "No downloader found (curl, wget, or uclient-fetch)."
    fi
}

fetch_with_fallback() {
    primary="$1"
    fallback="$2"
    out="$3"
    if fetch_to "$primary" "$out"; then
        return 0
    fi
    warn "Primary download failed; trying fallback CDN."
    fetch_to "$fallback" "$out"
}

if command -v apk >/dev/null 2>&1; then
    PKG_MGR="apk"
    pkg_update() { apk update; }
    pkg_install() { apk add "$@"; }
    local_pkg_install() { apk add --allow-untrusted "$@"; }
    package_installed() { apk info -e "$1" >/dev/null 2>&1; }
elif command -v opkg >/dev/null 2>&1; then
    PKG_MGR="opkg"
    pkg_update() { opkg update; }
    pkg_install() { opkg install "$@"; }
    local_pkg_install() { opkg install "$@"; }
    package_installed() { opkg status "$1" 2>/dev/null | grep -q '^Status: install ok installed'; }
else
    die "Neither apk nor opkg was found."
fi

ensure_packages() {
    needs_install=0
    for package in "$@"; do
        if package_installed "$package"; then
            log "Prerequisite package already installed: $package"
        else
            log "Missing prerequisite package: $package"
            needs_install=1
        fi
    done

    if [ "$needs_install" -eq 0 ]; then
        return 0
    fi

    log "Updating package indexes for missing prerequisites..."
    pkg_update || warn "Package index update returned an error; trying the available indexes."

    for package in "$@"; do
        if ! package_installed "$package"; then
            log "Installing prerequisite package: $package"
            pkg_install "$package" || die "Could not install required package: $package"
        fi
    done
}

verify_commands() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || die "Prerequisite verification failed; command '$cmd' is still missing."
    done
}

VERSION="${DISTRIB_RELEASE:-unknown}"
ARCH="${DISTRIB_ARCH:-}"
[ -n "$ARCH" ] || die "Could not detect OpenWrt package architecture."

case "$VERSION" in
    24.10*) MOMO_BRANCH="openwrt-24.10" ;;
    25.12*) MOMO_BRANCH="openwrt-25.12" ;;
    *SNAPSHOT*|*snapshot*) MOMO_BRANCH="SNAPSHOT" ;;
    *)
        die "Unsupported OpenWrt release: $VERSION. Supported release families: 24.10, 25.12, and compatible SNAPSHOT builds."
        ;;
esac

RAM_KB="$(awk '/MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || echo 0)"
FREE_KB="$(df -k /overlay 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)"

log "OpenWrt: $VERSION"
log "Architecture: $ARCH"
log "Package manager: $PKG_MGR"
log "RAM: $((RAM_KB / 1024)) MiB"
[ "$FREE_KB" -gt 0 ] 2>/dev/null && log "Free overlay: $((FREE_KB / 1024)) MiB"

if ! command -v sing-box >/dev/null 2>&1 && [ "$FREE_KB" -gt 0 ] 2>/dev/null && [ "$FREE_KB" -lt 28000 ]; then
    die "Less than about 28 MiB is free on /overlay and sing-box is not installed. Use extroot/USB storage or free space first."
fi

log "Checking tunnel prerequisites..."
if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || command -v uclient-fetch >/dev/null 2>&1; then
    ensure_packages ca-bundle jsonfilter firewall4 ip-full kmod-inet-diag kmod-nft-socket kmod-nft-tproxy kmod-tun sing-box
else
    ensure_packages ca-bundle curl jsonfilter firewall4 ip-full kmod-inet-diag kmod-nft-socket kmod-nft-tproxy kmod-tun sing-box
fi

log "Verifying installed tunnel prerequisites..."
verify_commands nft fw4 jsonfilter sing-box uci ubus tar find sed awk grep
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1 && ! command -v uclient-fetch >/dev/null 2>&1; then
    die "Prerequisite verification failed; no downloader is available."
fi
nft list table inet fw4 >/dev/null 2>&1 || die "firewall4 is installed, but table 'inet fw4' is unavailable. Start or repair the firewall service first."

MODEL="$(ubus call system board 2>/dev/null | jsonfilter -e '@.model' 2>/dev/null || true)"
[ -n "$MODEL" ] || MODEL="unknown"
log "Device: $MODEL"
log "All tunnel prerequisites are ready."

modprobe nft_tproxy 2>/dev/null || true
modprobe nft_socket 2>/dev/null || true

if [ -f /etc/config/momo ]; then cp -a /etc/config/momo "$BACKUP_DIR/momo.uci"; fi
if [ -f "$PROFILE" ]; then cp -a "$PROFILE" "$BACKUP_DIR/${PROFILE_NAME}"; fi
if [ -f /etc/momo/ucode/hijack.ut ]; then cp -a /etc/momo/ucode/hijack.ut "$BACKUP_DIR/hijack.ut"; fi

log "Resolving the latest Momo release..."
fetch_to "$MOMO_API" "$TMP_DIR/momo-release.json" || die "Could not query the latest Momo release."
MOMO_TAG="$(jsonfilter -i "$TMP_DIR/momo-release.json" -e '@.tag_name' 2>/dev/null || true)"
[ -n "$MOMO_TAG" ] || die "Could not read Momo release tag from GitHub."
MOMO_ASSET="momo_${ARCH}-${MOMO_BRANCH}.tar.gz"
MOMO_URL="https://github.com/${MOMO_REPO}/releases/download/${MOMO_TAG}/${MOMO_ASSET}"
log "Momo release: $MOMO_TAG"
log "Momo asset: $MOMO_ASSET"

fetch_to "$MOMO_URL" "$TMP_DIR/momo.tar.gz" || die "No Momo release asset was found for architecture '$ARCH' on '$MOMO_BRANCH'."
tar -tzf "$TMP_DIR/momo.tar.gz" >/dev/null 2>&1 || die "Downloaded Momo archive is invalid."
mkdir -p "$TMP_DIR/momo"
tar -xzf "$TMP_DIR/momo.tar.gz" -C "$TMP_DIR/momo"

if [ "$PKG_MGR" = "apk" ]; then
    MOMO_PKG="$(find "$TMP_DIR/momo" -type f -name 'momo-*.apk' | head -n 1)"
    LUCI_PKG="$(find "$TMP_DIR/momo" -type f -name 'luci-app-momo-*.apk' | head -n 1)"
else
    MOMO_PKG="$(find "$TMP_DIR/momo" -type f -name 'momo_*.ipk' | head -n 1)"
    [ -n "$MOMO_PKG" ] || MOMO_PKG="$(find "$TMP_DIR/momo" -type f -name 'momo-*.ipk' | head -n 1)"
    LUCI_PKG="$(find "$TMP_DIR/momo" -type f -name 'luci-app-momo_*.ipk' | head -n 1)"
    [ -n "$LUCI_PKG" ] || LUCI_PKG="$(find "$TMP_DIR/momo" -type f -name 'luci-app-momo-*.ipk' | head -n 1)"
fi
[ -n "$MOMO_PKG" ] || die "Momo package was not found inside the release archive."
[ -n "$LUCI_PKG" ] || die "luci-app-momo package was not found inside the release archive."

log "Installing Momo and LuCI app..."
local_pkg_install "$MOMO_PKG" "$LUCI_PKG" || die "Momo package installation failed."

HIJACK_URL="https://raw.githubusercontent.com/${MOMO_REPO}/${MOMO_TAG}/momo/files/ucode/hijack.ut"
if fetch_to "$HIJACK_URL" "$TMP_DIR/hijack.ut" && [ -s "$TMP_DIR/hijack.ut" ]; then
    mkdir -p /etc/momo/ucode
    if [ -f /etc/momo/ucode/hijack.ut ]; then
        cp -a /etc/momo/ucode/hijack.ut "$BACKUP_DIR/hijack.ut.packaged"
    fi
    cp "$TMP_DIR/hijack.ut" /etc/momo/ucode/hijack.ut
    chmod 644 /etc/momo/ucode/hijack.ut
else
    warn "Could not refresh hijack.ut from the release tag; keeping the packaged copy."
fi

mkdir -p "$PROFILE_DIR" "$RULE_DIR"
log "Downloading Iran rule sets..."
fetch_with_fallback "$RULE_GEOSITE_GH" "$RULE_GEOSITE_CDN" "$TMP_DIR/geosite-ir.srs" || die "Could not download geosite-ir.srs."
fetch_with_fallback "$RULE_GEOIP_GH" "$RULE_GEOIP_CDN" "$TMP_DIR/geoip-ir.srs" || die "Could not download geoip-ir.srs."
[ -s "$TMP_DIR/geosite-ir.srs" ] || die "Downloaded geosite-ir.srs is empty."
[ -s "$TMP_DIR/geoip-ir.srs" ] || die "Downloaded geoip-ir.srs is empty."
cp "$TMP_DIR/geosite-ir.srs" "$RULE_DIR/geosite-ir.srs"
cp "$TMP_DIR/geoip-ir.srs" "$RULE_DIR/geoip-ir.srs"
chmod 644 "$RULE_DIR"/*.srs

HY2_URI="${HY2_URI:-}"
if [ -z "$HY2_URI" ]; then
    printf '\nPaste your Hysteria2 URI (hysteria2://...):\n> ' >/dev/tty
    IFS= read -r HY2_URI </dev/tty
fi
case "$HY2_URI" in
    hysteria2://*) URI_BODY="${HY2_URI#hysteria2://}" ;;
    hy2://*) URI_BODY="${HY2_URI#hy2://}" ;;
    *) die "The supplied URI is not a hysteria2:// or hy2:// URI." ;;
esac

URI_BODY="${URI_BODY%%#*}"
case "$URI_BODY" in
    *\?*) AUTHORITY="${URI_BODY%%\?*}"; QUERY="${URI_BODY#*\?}" ;;
    *) AUTHORITY="$URI_BODY"; QUERY="" ;;
esac
case "$AUTHORITY" in
    *@*) HY2_PASSWORD_RAW="${AUTHORITY%@*}"; HOSTPORT="${AUTHORITY#*@}" ;;
    *) die "Hysteria2 URI has no password/userinfo before @." ;;
esac

url_decode() {
    printf '%b' "$(printf '%s' "$1" | sed 's/+/ /g; s/%/\\x/g')"
}
query_get() {
    wanted="$1"
    old_ifs="$IFS"
    IFS='&'
    for pair in $QUERY; do
        key="${pair%%=*}"
        val="${pair#*=}"
        if [ "$key" = "$wanted" ]; then
            IFS="$old_ifs"
            url_decode "$val"
            return 0
        fi
    done
    IFS="$old_ifs"
    return 1
}
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

HY2_PASSWORD="$(url_decode "$HY2_PASSWORD_RAW")"
case "$HOSTPORT" in
    \[*\]:*)
        HY2_HOST="${HOSTPORT#\[}"; HY2_HOST="${HY2_HOST%%\]*}"
        HY2_PORT="${HOSTPORT##*]:}"
        ;;
    \[*\])
        HY2_HOST="${HOSTPORT#\[}"; HY2_HOST="${HY2_HOST%\]}"; HY2_PORT="443"
        ;;
    *:*) HY2_HOST="${HOSTPORT%:*}"; HY2_PORT="${HOSTPORT##*:}" ;;
    *) HY2_HOST="$HOSTPORT"; HY2_PORT="443" ;;
esac
[ -n "$HY2_HOST" ] || die "Could not parse Hysteria2 server host."
case "$HY2_PORT" in *[!0-9]*|'') die "Invalid Hysteria2 server port: $HY2_PORT" ;; esac

SNI="$(query_get sni 2>/dev/null || true)"
[ -n "$SNI" ] || SNI="$HY2_HOST"
OBFS_TYPE="$(query_get obfs 2>/dev/null || true)"
OBFS_PASSWORD="$(query_get obfs-password 2>/dev/null || true)"
[ -n "$OBFS_PASSWORD" ] || OBFS_PASSWORD="$(query_get obfs_password 2>/dev/null || true)"
ALPN="$(query_get alpn 2>/dev/null || true)"
INSECURE_RAW="$(query_get insecure 2>/dev/null || true)"
[ -n "$INSECURE_RAW" ] || INSECURE_RAW="$(query_get allowInsecure 2>/dev/null || true)"
case "$INSECURE_RAW" in 1|true|TRUE|yes|YES) INSECURE=true ;; *) INSECURE=false ;; esac

J_HOST="$(json_escape "$HY2_HOST")"
J_PASS="$(json_escape "$HY2_PASSWORD")"
J_SNI="$(json_escape "$SNI")"
J_OBFS_TYPE="$(json_escape "$OBFS_TYPE")"
J_OBFS_PASS="$(json_escape "$OBFS_PASSWORD")"
J_ALPN="$(json_escape "$ALPN")"

if [ -n "$OBFS_TYPE" ] && [ -n "$OBFS_PASSWORD" ]; then
    OBFS_JSON="\"obfs\": {\"type\": \"$J_OBFS_TYPE\", \"password\": \"$J_OBFS_PASS\"},"
else
    OBFS_JSON=""
fi
if [ -n "$ALPN" ]; then
    ALPN_JSON=", \"alpn\": [\"$J_ALPN\"]"
else
    ALPN_JSON=""
fi

cat > "$PROFILE" <<EOF_PROFILE
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "type": "local",
        "tag": "direct-dns"
      },
      {
        "type": "https",
        "tag": "proxy-dns",
        "server": "1.1.1.1",
        "server_port": 443,
        "path": "/dns-query",
        "tls": {
          "enabled": true,
          "server_name": "cloudflare-dns.com"
        },
        "detour": "hy2-out"
      }
    ],
    "rules": [
      {
        "rule_set": ["geosite-ir"],
        "action": "route",
        "server": "direct-dns"
      }
    ],
    "final": "proxy-dns",
    "strategy": "ipv4_only"
  },
  "inbounds": [
    {
      "type": "direct",
      "tag": "dns-in",
      "listen": "0.0.0.0",
      "listen_port": 1053
    },
    {
      "type": "redirect",
      "tag": "redirect-in",
      "listen": "0.0.0.0",
      "listen_port": 7891
    },
    {
      "type": "tproxy",
      "tag": "tproxy-in",
      "listen": "0.0.0.0",
      "listen_port": 7892,
      "network": "udp"
    }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-out",
      "server": "$J_HOST",
      "server_port": $HY2_PORT,
      "password": "$J_PASS",
      $OBFS_JSON
      "tls": {
        "enabled": true,
        "server_name": "$J_SNI",
        "insecure": $INSECURE$ALPN_JSON
      },
      "domain_resolver": "direct-dns"
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "action": "sniff",
        "timeout": "300ms"
      },
      {
        "ip_is_private": true,
        "action": "route",
        "outbound": "direct"
      },
      {
        "rule_set": ["geosite-ir", "geoip-ir"],
        "action": "route",
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "type": "local",
        "tag": "geosite-ir",
        "format": "binary",
        "path": "$RULE_DIR/geosite-ir.srs"
      },
      {
        "type": "local",
        "tag": "geoip-ir",
        "format": "binary",
        "path": "$RULE_DIR/geoip-ir.srs"
      }
    ],
    "final": "hy2-out",
    "auto_detect_interface": true
  }
}
EOF_PROFILE
chmod 600 "$PROFILE"

log "Validating sing-box profile..."
if ! sing-box check -c "$PROFILE"; then
    if [ -f "$BACKUP_DIR/${PROFILE_NAME}" ]; then
        cp -a "$BACKUP_DIR/${PROFILE_NAME}" "$PROFILE"
    else
        rm -f "$PROFILE"
    fi
    die "sing-box rejected the generated configuration. Previous profile was restored when available."
fi

LAN_NETWORK="${LAN_INTERFACE:-}"
if [ -z "$LAN_NETWORK" ] && uci -q show network.lan >/dev/null 2>&1; then
    LAN_NETWORK="lan"
fi
if [ -z "$LAN_NETWORK" ]; then
    for section in $(uci show network 2>/dev/null | sed -n "s/^network\.\([^.=]*\)=interface$/\1/p"); do
        case "$section" in loopback|wan|wan6) continue ;; esac
        LAN_NETWORK="$section"
        break
    done
fi
[ -n "$LAN_NETWORK" ] || die "Could not auto-detect a LAN network. Re-run with LAN_INTERFACE=<uci-network-name>."
log "LAN network: $LAN_NETWORK"

/etc/init.d/momo stop >/dev/null 2>&1 || true

uci set momo.config.enabled='1'
uci set momo.config.profile="file:${PROFILE_NAME}"
uci set momo.config.start_delay='0'
uci set momo.config.test_profile='1'
uci set momo.config.core_only='0'

uci set momo.proxy.enabled='1'
uci set momo.proxy.ipv4_dns_hijack='1'
uci set momo.proxy.ipv6_dns_hijack='0'
uci set momo.proxy.ipv4_proxy='1'
uci set momo.proxy.ipv6_proxy='0'
uci set momo.proxy.fake_ip_ping_hijack='0'
uci set momo.proxy.tcp_mode='redirect'
uci set momo.proxy.udp_mode='tproxy'
uci set momo.proxy.router_proxy='0'
uci set momo.proxy.lan_proxy='1'
uci set momo.proxy.proxy_tcp_dport='0-65535'
uci set momo.proxy.proxy_udp_dport='0-65535'
uci -q delete momo.proxy.lan_inbound_interface || true
uci add_list momo.proxy.lan_inbound_interface="$LAN_NETWORK"
uci set momo.proxy.bypass_china_mainland_ip='0'
uci set momo.proxy.bypass_china_mainland_ip6='0'

if ! uci -q get momo.@lan_access_control[0] >/dev/null 2>&1; then
    uci add momo lan_access_control >/dev/null
fi
uci set momo.@lan_access_control[0].enabled='1'
uci set momo.@lan_access_control[0].dns='1'
uci set momo.@lan_access_control[0].proxy='1'

if [ "$RAM_KB" -gt 0 ] 2>/dev/null && [ "$RAM_KB" -le 170000 ]; then
    uci set momo.procd.env_go_max_procs='1'
    uci set momo.procd.env_go_mem_limit='64MiB'
elif [ "$RAM_KB" -gt 0 ] 2>/dev/null && [ "$RAM_KB" -le 330000 ]; then
    uci set momo.procd.env_go_max_procs='2'
    uci set momo.procd.env_go_mem_limit='144MiB'
elif [ "$RAM_KB" -gt 0 ] 2>/dev/null && [ "$RAM_KB" -le 660000 ]; then
    uci set momo.procd.env_go_max_procs='2'
    uci set momo.procd.env_go_mem_limit='320MiB'
fi
uci commit momo

if fetch_to "$RAW_BASE/update-rules.sh" "$TMP_DIR/update-rules.sh"; then
    cp "$TMP_DIR/update-rules.sh" /usr/bin/openwrt-iran-split-update
    chmod 755 /usr/bin/openwrt-iran-split-update
else
    warn "Rule updater could not be installed; the tunnel can still run."
fi
if fetch_to "$RAW_BASE/health-check.sh" "$TMP_DIR/health-check.sh"; then
    cp "$TMP_DIR/health-check.sh" /usr/bin/openwrt-iran-split-health
    chmod 755 /usr/bin/openwrt-iran-split-health
fi

if [ -x /usr/bin/openwrt-iran-split-update ]; then
    sed -i '/# openwrt-iran-split-tunnel rules/d' /etc/crontabs/root 2>/dev/null || true
    printf '%s\n' '17 4 * * 0 /usr/bin/openwrt-iran-split-update >/dev/null 2>&1 # openwrt-iran-split-tunnel rules' >> /etc/crontabs/root
    /etc/init.d/cron enable >/dev/null 2>&1 || true
    /etc/init.d/cron restart >/dev/null 2>&1 || true
fi

log "Starting Momo..."
/etc/init.d/momo enable
if ! /etc/init.d/momo restart; then
    if [ -f "$BACKUP_DIR/momo.uci" ]; then
        cp -a "$BACKUP_DIR/momo.uci" /etc/config/momo
    fi
    die "Momo failed to restart. UCI backup was restored when available."
fi
sleep 4

MOMO_STATUS="$(/etc/init.d/momo status 2>/dev/null || true)"
[ "$MOMO_STATUS" = "running" ] || die "Momo is not running after installation. Check LuCI -> Services -> Momo -> Log."
nft list table inet momo >/dev/null 2>&1 || die "Momo is running but its nftables table was not created."

if command -v busybox >/dev/null 2>&1; then
    if ! busybox netstat -lnptu 2>/dev/null | grep -q ':1053'; then
        warn "DNS inbound port 1053 was not visible in netstat. Check the Momo core log if clients cannot resolve domains."
    fi
fi

cat > "$STATE_DIR/state" <<EOF_STATE
version=0.1.0
openwrt=$VERSION
arch=$ARCH
momo_tag=$MOMO_TAG
lan_network=$LAN_NETWORK
profile=$PROFILE
EOF_STATE
chmod 600 "$STATE_DIR/state"

printf '\n'
log "Installation completed successfully."
printf '%s\n' "    Iran IP/domains -> DIRECT"
printf '%s\n' "    Other IPv4 traffic -> Hysteria2"
printf '%s\n' "    TCP -> Redirect | UDP -> TPROXY"
printf '%s\n' "    DNS -> Momo hijack -> sing-box (Iran local / foreign DoH through Hysteria2)"
printf '%s\n' "    IPv6 proxying -> disabled by default"
printf '\n%s\n' "Health check: openwrt-iran-split-health"
printf '%s\n' "Update Iran rules: openwrt-iran-split-update"
printf '%s\n' "Backup: $BACKUP_DIR"
