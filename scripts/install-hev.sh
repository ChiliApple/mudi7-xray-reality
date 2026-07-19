#!/bin/sh
# install-hev.sh — Stage B (hev-socks5-tunnel): Binary laden+verifizieren, Service + Befehle.
# Loest tun2socks ab (lwIP-Stack, robuster TCP-Rueckweg). Aendert NICHTS am Traffic.
set -eu
HEV_VER="2.15.0"
ASSET="hev-socks5-tunnel-linux-arm64"
SHA256="311677bc9ed408fad8a9688d58580d4c125d4a0b8d5dd8d3b1a1e60e7e8733a8"
URL="https://github.com/heiher/hev-socks5-tunnel/releases/download/${HEV_VER}/${ASSET}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
log(){ echo "[hev] $*"; }; die(){ echo "[hev][FEHLER] $*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl fehlt"
opkg list-installed 2>/dev/null | grep -q '^kmod-tun ' || { opkg update; opkg install kmod-tun; }

# alten tun2socks-Service abschalten
[ -f /etc/init.d/tun2socks ] && { /etc/init.d/tun2socks stop 2>/dev/null; /etc/init.d/tun2socks disable 2>/dev/null; }
killall tun2socks 2>/dev/null || true

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT INT TERM
log "Lade ${ASSET} (${HEV_VER}) ..."
curl -fL -o "$TMP/hev" "$URL" || die "Download fehlgeschlagen"
HAVE="$(sha256sum "$TMP/hev" | cut -d' ' -f1)"
[ "$HAVE" = "$SHA256" ] || die "SHA256 MISMATCH: erwartet $SHA256, ist $HAVE"
log "SHA256 verifiziert (gepinnt): $HAVE"
cp "$TMP/hev" /usr/bin/hev-socks5-tunnel && chmod 0755 /usr/bin/hev-socks5-tunnel

mkdir -p /etc/hev
cp "$REPO_ROOT/etc/hev/config.yaml" /etc/hev/config.yaml
cp "$REPO_ROOT/etc/init.d/hev" /etc/init.d/hev && chmod 0755 /etc/init.d/hev
for s in xray-on xray-off xray-confirm; do
    cp "$REPO_ROOT/scripts/$s" "/usr/sbin/$s" && chmod 0755 "/usr/sbin/$s"
done
/etc/init.d/xray disable 2>/dev/null || true
/etc/init.d/hev disable 2>/dev/null || true
log "hev installiert. Default: aus. Einschalten: xray-on -> testen -> xray-confirm ; Aus: xray-off"
