#!/bin/sh
# selftest.sh — testet den kompletten Tunnel-Pfad VOM MUDI aus (ohne Client-Geraet).
# Route eine Test-IP durch tun0 -> tun2socks -> SOCKS(10808) -> Xray -> REALITY.
set -u
echo "== [1] Tunnel einschalten =="
xray-on >/dev/null 2>&1
sleep 3

echo "== [2] Laeuft tun2socks? =="
pgrep -af tun2socks | head -1 || echo "  !! tun2socks NICHT aktiv"

echo "== [3] tun0-Status =="
ip addr show tun0 2>/dev/null | grep -E 'state |198\.18' | sed 's/^/  /'

echo "== [4a] Referenz: SOCKS direkt -> Exit-IP =="
echo -n "  "; curl -s --max-time 8 --socks5-hostname 127.0.0.1:10808 https://api.ipify.org; echo

echo "== [4b] ENTSCHEIDEND: via tun0 -> Cloudflare-Trace =="
ip route add 1.1.1.1/32 dev tun0 2>/dev/null
echo "  (Route 1.1.1.1 -> tun0 gesetzt, hole Trace ...)"
curl -s --max-time 12 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep -E '^ip=' | sed 's/^/  /' || echo "  (keine Antwort ueber tun0)"
ip route del 1.1.1.1/32 dev tun0 2>/dev/null

echo "== [5] tun0 Zaehler (Traffic durchgelaufen?) =="
ip -s link show tun0 2>/dev/null | sed -n '/RX:/{n;s/^/  RX/;p};/TX:/{n;s/^/  TX/;p}'

echo "== [6] Tunnel wieder aus =="
xray-off >/dev/null 2>&1
echo "== fertig =="
