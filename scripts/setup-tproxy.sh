#!/bin/sh
# setup-tproxy.sh — Stage B Deployment: TPROXY-Regeln + xray-on/off/confirm.
# Aendert NICHTS am laufenden Traffic. Aktiviert wird spaeter mit 'xray-on'.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ETC_DIR="/etc/xray"
SECRETS="$ETC_DIR/secrets.env"
NFT_TPL="$REPO_ROOT/etc/xray-tproxy.nft.template"

log() { echo "[tproxy-setup] $*"; }
die() { echo "[tproxy-setup][FEHLER] $*" >&2; exit 1; }

[ -f "$SECRETS" ] || die "secrets.env fehlt: $SECRETS"
[ -f "$NFT_TPL" ] || die "Template fehlt: $NFT_TPL"
# shellcheck disable=SC1090
. "$SECRETS"
: "${XRAY_SERVER:?fehlt in secrets.env}"

# --- Kernelmodule ---
opkg list-installed 2>/dev/null | grep -q '^kmod-nft-tproxy ' || { opkg update; opkg install kmod-nft-tproxy; }
opkg list-installed 2>/dev/null | grep -q '^kmod-nft-socket ' || opkg install kmod-nft-socket || log "WARN: kmod-nft-socket nicht verfuegbar (socket-Match evtl. eingeschraenkt)"

# --- nft-Regeln rendern (Server-IP einsetzen) ---
sed "s|__SERVER_ADDRESS__|${XRAY_SERVER}|g" "$NFT_TPL" > "$ETC_DIR/xray-tproxy.nft"
chmod 600 "$ETC_DIR/xray-tproxy.nft"
log "nft-Regeln gerendert: $ETC_DIR/xray-tproxy.nft"

# --- Befehle nach /usr/sbin ---
for s in xray-on xray-off xray-confirm; do
    cp "$REPO_ROOT/scripts/$s" "/usr/sbin/$s"
    chmod 0755 "/usr/sbin/$s"
done
log "Befehle installiert: xray-on / xray-off / xray-confirm"

# --- Boot-Default = AUS ---
/etc/init.d/xray disable 2>/dev/null || true
log "Autostart deaktiviert (Default: aus)."
log "Einschalten (mit Auto-Revert):  xray-on   -> testen -> xray-confirm"
log "Ausschalten:                     xray-off"
