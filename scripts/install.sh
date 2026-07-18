#!/bin/sh
# install.sh — Xray-core REALITY-Client Installer fuer GL.iNet Mudi 7
# OpenWrt 23.05 / aarch64 / musl. Idempotent & reproduzierbar.
#
# Secrets kommen AUSSCHLIESSLICH aus /etc/xray/secrets.env (NICHT im Repo!).
# Binary wird gegen die offizielle .dgst-Pruefsumme verifiziert.
#
# Aufruf:  sh scripts/install.sh
set -eu

# --- gepinnte Version (siehe VERSION-Datei) ---
XRAY_VERSION="v26.6.1"
ARCH_ASSET="Xray-linux-arm64-v8a.zip"
BASE_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}"

BIN_DEST="/usr/bin/xray"
ETC_DIR="/etc/xray"
ASSET_DIR="/usr/share/xray"
SECRETS="${ETC_DIR}/secrets.env"

# Repo-Root relativ zu diesem Script (scripts/ -> ..)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="${REPO_ROOT}/config/config.template.json"
INITD_SRC="${REPO_ROOT}/etc/init.d/xray"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

log()  { echo "[install] $*"; }
die()  { echo "[install][FEHLER] $*" >&2; exit 1; }

# --- Vorbedingungen ---
command -v curl     >/dev/null 2>&1 || die "curl fehlt"
command -v unzip    >/dev/null 2>&1 || die "unzip fehlt -> opkg update && opkg install unzip"
command -v sha256sum>/dev/null 2>&1 || die "sha256sum fehlt"
[ -f "$TEMPLATE" ] || die "Template nicht gefunden: $TEMPLATE"
[ -f "$SECRETS" ]  || die "Secrets fehlen: $SECRETS anlegen (Vorlage: config/secrets.env.example)"

# --- Binary laden ---
log "Lade ${ARCH_ASSET} (${XRAY_VERSION}) ..."
curl -fL -o "$TMP/xray.zip"      "${BASE_URL}/${ARCH_ASSET}"        || die "Download Binary fehlgeschlagen"
curl -fL -o "$TMP/xray.zip.dgst" "${BASE_URL}/${ARCH_ASSET}.dgst"   || die "Download .dgst fehlgeschlagen"

# --- SHA256 gegen offizielle .dgst pruefen ---
HAVE="$(sha256sum "$TMP/xray.zip" | cut -d' ' -f1)"
grep -iq "$HAVE" "$TMP/xray.zip.dgst" || die "SHA256 MISMATCH: $HAVE nicht in .dgst enthalten -> Abbruch"
log "SHA256 verifiziert gegen offizielle .dgst: $HAVE"

# --- Entpacken + platzieren ---
unzip -o "$TMP/xray.zip" -d "$TMP/x" >/dev/null || die "Entpacken fehlgeschlagen"
[ -f "$TMP/x/xray" ] || die "xray-Binary nicht im Archiv gefunden"
install -m 0755 "$TMP/x/xray" "$BIN_DEST"
mkdir -p "$ASSET_DIR"
[ -f "$TMP/x/geoip.dat" ]   && install -m 0644 "$TMP/x/geoip.dat"   "$ASSET_DIR/" || true
[ -f "$TMP/x/geosite.dat" ] && install -m 0644 "$TMP/x/geosite.dat" "$ASSET_DIR/" || true

VER_OUT="$("$BIN_DEST" version 2>/dev/null | head -1 || true)"
log "Installiert: ${VER_OUT:-xray}"

# --- Config aus Template + Secrets rendern ---
mkdir -p "$ETC_DIR"
# shellcheck disable=SC1090
. "$SECRETS"
: "${XRAY_SERVER:?fehlt in secrets.env}"
: "${XRAY_PORT:?fehlt in secrets.env}"
: "${XRAY_UUID:?fehlt in secrets.env}"
: "${XRAY_PBK:?fehlt in secrets.env}"
: "${XRAY_SID:?fehlt in secrets.env}"
: "${XRAY_SNI:?fehlt in secrets.env}"
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
log "Config gerendert: $ETC_DIR/config.json (chmod 600)"

# --- Config testen (nicht fatal, nur Hinweis) ---
if "$BIN_DEST" run -test -c "$ETC_DIR/config.json" >/dev/null 2>&1; then
    log "Config-Test: OK"
else
    log "WARN: Config-Test nicht bestaetigt -> manuell pruefen: $BIN_DEST run -test -c $ETC_DIR/config.json"
fi

# --- procd-Service installieren + starten ---
install -m 0755 "$INITD_SRC" /etc/init.d/xray
/etc/init.d/xray enable
/etc/init.d/xray restart
log "Service aktiv."
log "SOCKS-Test: curl --socks5-hostname 127.0.0.1:10808 https://api.ipify.org ; echo"
log "Erwartung: die oeffentliche IP deines REALITY-Servers."
