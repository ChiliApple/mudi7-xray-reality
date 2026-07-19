#!/bin/sh
# selftest.sh — testet den kompletten Tunnel-Pfad VOM MUDI aus (hev), ohne Client-Geraet.
set -u
echo "== [1] xray-on (startet hev + tun0 + routing) =="
xray-on
# auf Xray-SOCKS warten (nach Reboot kann Xray-Start dauern)
i=0; while [ $i -lt 30 ]; do netstat -lnt 2>/dev/null | grep -q "127.0.0.1:10808" && break; sleep 0.3; i=$((i+1)); done
sleep 1

echo "== [2] hev laeuft? =="
pgrep -af hev-socks5-tunnel | head -1 | sed 's/^/  /' || echo "  !! hev NICHT aktiv"

echo "== [3] tun0-Status =="
ip addr show tun0 2>/dev/null | grep -E 'state |198\.18' | sed 's/^/  /'

echo "== [4a] Referenz: SOCKS direkt -> Exit-IP =="
echo -n "  "; curl -s --max-time 8 --socks5-hostname 127.0.0.1:10808 https://api.ipify.org; echo

echo "== [4b] ENTSCHEIDEND: TCP via tun0 -> Cloudflare-Trace =="
ip route add 1.1.1.1/32 dev tun0 2>/dev/null
echo -n "  Trace-IP: "; curl -s --max-time 12 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep -E '^ip=' | sed 's/^ip=//' || echo "(keine Antwort)"
ip route del 1.1.1.1/32 dev tun0 2>/dev/null

echo "== [5] tun0 Zaehler =="
ip -s link show tun0 2>/dev/null | sed -n '/RX:/{n;s/^/  RX/;p};/TX:/{n;s/^/  TX/;p}'

echo "== [6] xray-off =="
xray-off
echo "== fertig =="
