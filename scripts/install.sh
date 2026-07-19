#!/bin/sh
# install.sh — Xray-core REALITY client installer for GL.iNet Mudi 7
# OpenWrt 23.05 / aarch64 / musl. Idempotent & reproducible.
#
# Secrets come EXCLUSIVELY from /etc/xray/secrets.env (NOT in the repo!).
# The binary is verified against the official .dgst checksum.
#
# Usage:  sh scripts/install.sh
set -eu

# --- pinned version (see VERSION file) ---
XRAY_VERSION="v26.6.1"
ARCH_ASSET="Xray-linux-arm64-v8a.zip"
BASE_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}"

BIN_DEST="/usr/bin/xray"
ETC_DIR="/etc/xray"
ASSET_DIR="/usr/share/xray"
SECRETS="${ETC_DIR}/secrets.env"

# repo root relative to this script (scripts/ -> ..)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="${REPO_ROOT}/config/config.template.json"
INITD_SRC="${REPO_ROOT}/etc/init.d/xray"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

log()  { echo "[install] $*"; }
die()  { echo "[install][ERROR] $*" >&2; exit 1; }

# --- preconditions ---
command -v curl     >/dev/null 2>&1 || die "curl missing"
command -v unzip    >/dev/null 2>&1 || die "unzip missing -> opkg update && opkg install unzip"
command -v sha256sum>/dev/null 2>&1 || die "sha256sum missing"
[ -f "$TEMPLATE" ] || die "template not found: $TEMPLATE"
[ -f "$SECRETS" ]  || die "secrets missing: create $SECRETS (template: config/secrets.env.example)"

# --- download binary ---
log "Downloading ${ARCH_ASSET} (${XRAY_VERSION}) ..."
curl -fL -o "$TMP/xray.zip"      "${BASE_URL}/${ARCH_ASSET}"        || die "binary download failed"
curl -fL -o "$TMP/xray.zip.dgst" "${BASE_URL}/${ARCH_ASSET}.dgst"   || die ".dgst download failed"

# --- verify SHA256 against official .dgst ---
HAVE="$(sha256sum "$TMP/xray.zip" | cut -d' ' -f1)"
grep -iq "$HAVE" "$TMP/xray.zip.dgst" || die "SHA256 MISMATCH: $HAVE not present in .dgst -> abort"
log "SHA256 verified against official .dgst: $HAVE"

# --- unpack + place ---
unzip -o "$TMP/xray.zip" -d "$TMP/x" >/dev/null || die "unpack failed"
[ -f "$TMP/x/xray" ] || die "xray binary not found in archive"
cp "$TMP/x/xray" "$BIN_DEST" && chmod 0755 "$BIN_DEST"
mkdir -p "$ASSET_DIR"
[ -f "$TMP/x/geoip.dat" ]   && cp "$TMP/x/geoip.dat"   "$ASSET_DIR/" && chmod 0644 "$ASSET_DIR/geoip.dat"   || true
[ -f "$TMP/x/geosite.dat" ] && cp "$TMP/x/geosite.dat" "$ASSET_DIR/" && chmod 0644 "$ASSET_DIR/geosite.dat" || true

VER_OUT="$("$BIN_DEST" version 2>/dev/null | head -1 || true)"
log "Installed: ${VER_OUT:-xray}"

# --- render config from template + secrets ---
mkdir -p "$ETC_DIR"
# shellcheck disable=SC1090
. "$SECRETS"
: "${XRAY_SERVER:?missing in secrets.env}"
: "${XRAY_PORT:?missing in secrets.env}"
: "${XRAY_UUID:?missing in secrets.env}"
: "${XRAY_PBK:?missing in secrets.env}"
: "${XRAY_SID:?missing in secrets.env}"
: "${XRAY_SNI:?missing in secrets.env}"
: "${XRAY_FP:=chrome}"

sed -e "s|__SERVER_ADDRESS__|${XRAY_SERVER}|g" \
    -e "s|__SERVER_PORT__|${XRAY_PORT}|g" \
    -e "s|__UUID__|${XRAY_UUID}|g" \
    -e "s|__PUBLIC_KEY__|${XRAY_PBK}|g" \
    -e "s|__SHORT_ID__|${XRAY_SID}|g" \
    -e "s|__SNI__|${XRAY_SNI}|g" \
    -e "s|__FINGERPRINT__|${XRAY_FP}|g" \
    "$TEMPLATE" > "$ETC_DIR/config.json"
chmod 600 "$ETC_DIR/config.json"
log "Config rendered: $ETC_DIR/config.json (chmod 600)"

# --- test config (non-fatal, hint only) ---
if "$BIN_DEST" run -test -c "$ETC_DIR/config.json" >/dev/null 2>&1; then
    log "Config test: OK"
else
    log "WARN: config test not confirmed -> check manually: $BIN_DEST run -test -c $ETC_DIR/config.json"
fi

# --- install + start procd service ---
cp "$INITD_SRC" /etc/init.d/xray && chmod 0755 /etc/init.d/xray
/etc/init.d/xray enable
/etc/init.d/xray restart
log "Service active."
log "SOCKS test: curl --socks5-hostname 127.0.0.1:10808 https://api.ipify.org ; echo"
log "Expected: the public IP of your REALITY server."
