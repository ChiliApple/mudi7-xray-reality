#!/bin/sh
# install-tun2socks.sh — Stage B (tun2socks): Binary laden+verifizieren, Service + Befehle.
# Aendert NICHTS am Traffic. Aktivierung spaeter mit 'xray-on'.
set -eu
T2S_VER="v2.6.0"
ASSET="tun2socks-linux-arm64.zip"
SHA256="a5b326f79585851a7518b1072e1e2610d0a1ca6803b92f0630fcf97c035b5c81"
URL="https://github.com/xjasonlyu/tun2socks/releases/download/${T2S_VER}/${ASSET}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT INT TERM
log(){ echo "[t2s] $*"; }; die(){ echo "[t2s][FEHLER] $*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl fehlt"
command -v unzip >/dev/null 2>&1 || die "unzip fehlt -> opkg install unzip"
opkg list-installed 2>/dev/null | grep -q '^kmod-tun ' || { opkg update; opkg install kmod-tun; }

log "Lade ${ASSET} (${T2S_VER}) ..."
curl -fL -o "$TMP/t.zip" "$URL" || die "Download fehlgeschlagen"
HAVE="$(sha256sum "$TMP/t.zip" | cut -d' ' -f1)"
[ "$HAVE" = "$SHA256" ] || die "SHA256 MISMATCH: erwartet $SHA256, ist $HAVE"
log "SHA256 verifiziert (gepinnt): $HAVE"

unzip -o "$TMP/t.zip" -d "$TMP" >/dev/null || die "Entpacken fehlgeschlagen"
[ -f "$TMP/tun2socks-linux-arm64" ] || die "Binary nicht im Archiv"
cp "$TMP/tun2socks-linux-arm64" /usr/bin/tun2socks && chmod 0755 /usr/bin/tun2socks
log "Binary installiert: $(/usr/bin/tun2socks --version 2>/dev/null | head -1 || echo tun2socks)"

cp "$REPO_ROOT/etc/init.d/tun2socks" /etc/init.d/tun2socks && chmod 0755 /etc/init.d/tun2socks
for s in xray-on xray-off xray-confirm; do
    cp "$REPO_ROOT/scripts/$s" "/usr/sbin/$s" && chmod 0755 "/usr/sbin/$s"
done
/etc/init.d/xray disable 2>/dev/null || true
/etc/init.d/tun2socks disable 2>/dev/null || true
log "Fertig. Default: aus. Einschalten: xray-on  -> testen -> xray-confirm ; Aus: xray-off"
