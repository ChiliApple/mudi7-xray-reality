#!/bin/sh
# selftest-debug.sh — tun2socks im DEBUG-Modus, testet Pfad durch tun0 vom Mudi.
# Zeigt, wo der Relay haengt: SOCKS-Connect, Antwort, Fehler.
set -u
echo "== Vorbereitung =="
xray-off >/dev/null 2>&1
killall tun2socks 2>/dev/null
sleep 1

echo "== Xray/SOCKS starten =="
/etc/init.d/xray start >/dev/null 2>&1
sleep 2
pgrep -af xray | head -1 | sed 's/^/  /'
echo -n "  SOCKS-Referenz: "; curl -s --max-time 8 --socks5-hostname 127.0.0.1:10808 https://api.ipify.org; echo

echo "== tun0 (MTU 1280) =="
ip tuntap add mode tun dev tun0 2>/dev/null
ip addr add 198.18.0.1/15 dev tun0 2>/dev/null
ip link set dev tun0 up
ip link set dev tun0 mtu 1280

echo "== tun2socks DEBUG (Hintergrund) =="
/usr/bin/tun2socks -device tun0 -proxy socks5://127.0.0.1:10808 -loglevel debug > /tmp/t2s-debug.log 2>&1 &
T2SPID=$!
sleep 2
kill -0 "$T2SPID" 2>/dev/null && echo "  tun2socks pid=$T2SPID laeuft" || echo "  !! tun2socks sofort gestorben"

echo "== Test durch tun0 =="
ip route add 1.1.1.1/32 dev tun0 2>/dev/null
echo -n "  Trace ueber tun0: "; curl -s --max-time 12 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep -E '^ip=' || echo "(keine Antwort)"
ip route del 1.1.1.1/32 dev tun0 2>/dev/null
sleep 1

echo "== tun2socks Debug-Log (letzte 30 Zeilen) =="
kill "$T2SPID" 2>/dev/null
tail -n 30 /tmp/t2s-debug.log | sed 's/^/  /'

echo "== Aufraeumen =="
ip link set dev tun0 down 2>/dev/null
ip tuntap del mode tun dev tun0 2>/dev/null
/etc/init.d/xray stop 2>/dev/null
echo "== fertig =="
