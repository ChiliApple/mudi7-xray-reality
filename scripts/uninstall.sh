#!/bin/sh
# uninstall.sh — entfernt Xray-core-Client-Setup vom Mudi 7 sauber.
# Laesst /etc/xray/secrets.env bewusst stehen (deine Secrets) — bei Bedarf
# manuell loeschen.
set -u

log() { echo "[uninstall] $*"; }

# Service stoppen + deaktivieren
if [ -f /etc/init.d/xray ]; then
    /etc/init.d/xray stop 2>/dev/null || true
    /etc/init.d/xray disable 2>/dev/null || true
    rm -f /etc/init.d/xray
    log "Service entfernt."
fi

# Binary + Assets
rm -f  /usr/bin/xray
rm -rf /usr/share/xray
log "Binary + Assets entfernt."

# --- Stage-B-Reste (Transparent Proxy), falls vorhanden ---
if command -v nft >/dev/null 2>&1; then
    nft list table inet xray >/dev/null 2>&1 && nft delete table inet xray 2>/dev/null || true
fi
ip rule del fwmark 0x1 table 100 2>/dev/null || true
ip route flush table 100 2>/dev/null || true
log "Transparent-Proxy-Regeln (falls vorhanden) entfernt."

log "Fertig. /etc/xray/ (secrets.env, config.json) bleibt erhalten."
log "Komplett entfernen: rm -rf /etc/xray"
