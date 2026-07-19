#!/bin/sh
# dns-probe.sh — inspiziert Mudi-DNS + prueft Heimnetz/Heim-DNS-Erreichbarkeit durch den Tunnel.
# Voraussetzung fuer [5]/[6]: Tunnel an (xray-on).
set -u
echo "== [1] Was lauscht auf :53? =="
netstat -lnp 2>/dev/null | grep ':53 ' | sed 's/^/  /' || echo "  nichts?"
echo "== [2] AdGuard-Config-Ort =="
find /etc /usr /tmp /mnt 2>/dev/null -name "*.yaml" | grep -i adguard | sed 's/^/  /' || echo "  keine gefunden"
echo "== [3] dnsmasq-Upstreams =="
uci show dhcp 2>/dev/null | grep -iE 'noresolv|list server|\.port=' | sed 's/^/  /' || echo "  keine"
echo "== [4] Tunnel an? =="
pgrep -af hev-socks5-tunnel | head -1 | sed 's/^/  /' || { echo "  hev NICHT aktiv -> erst 'xray-on', dann Script nochmal"; exit 0; }
echo "== [5] Heimnetz via Tunnel? (DSM 10.10.10.10:5000) =="
ip route add 10.10.10.0/24 dev tun0 2>/dev/null
curl -s -m 8 -o /dev/null -w "  DSM HTTP: %{http_code}  (Zeit %{time_total}s)\n" http://10.10.10.10:5000/ 2>&1 || echo "  keine Antwort"
echo "== [6] Heim-DNS 10.10.10.1 via Tunnel (google.com) =="
nslookup google.com 10.10.10.1 2>&1 | head -8 | sed 's/^/  /'
ip route del 10.10.10.0/24 dev tun0 2>/dev/null
echo "== fertig =="
