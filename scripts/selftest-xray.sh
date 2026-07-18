#!/bin/sh
# selftest-xray.sh — Xray auf debug, tun0-Test, zeigt Xrays Sicht auf die Verbindung.
set -u
CFG=/etc/xray/config.json
echo "== Vorbereitung =="
xray-off >/dev/null 2>&1; killall tun2socks 2>/dev/null; sleep 1

echo "== Xray-Loglevel -> debug (temporaer) =="
cp "$CFG" /tmp/config.json.bak
sed -i 's/"loglevel": *"[a-z]*"/"loglevel": "debug"/' "$CFG"
grep loglevel "$CFG" | sed 's/^/  /'
/etc/init.d/xray restart >/dev/null 2>&1; sleep 2

echo "== tun0 + tun2socks =="
ip tuntap add mode tun dev tun0 2>/dev/null
ip addr add 198.18.0.1/15 dev tun0 2>/dev/null
ip link set dev tun0 up; ip link set dev tun0 mtu 1280
/usr/bin/tun2socks -device tun0 -proxy socks5://127.0.0.1:10808 -loglevel warn > /tmp/t2s.log 2>&1 &
T=$!; sleep 2

echo "== Test durch tun0 (1.1.1.1) =="
ip route add 1.1.1.1/32 dev tun0 2>/dev/null
echo -n "  Trace: "; curl -s --max-time 12 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep -E '^ip=' || echo "(keine Antwort)"
ip route del 1.1.1.1/32 dev tun0 2>/dev/null
sleep 1; kill "$T" 2>/dev/null

echo "== Xray-Log (was passierte mit 1.1.1.1?) =="
logread | grep -i xray | grep -iE '1\.1\.1\.1|proxy|reality|rejected|failed|accepted|dial' | tail -n 15 | sed 's/^/  /'

echo "== Loglevel zurueck auf warning =="
cp /tmp/config.json.bak "$CFG"
/etc/init.d/xray stop >/dev/null 2>&1

echo "== Aufraeumen =="
ip link set dev tun0 down 2>/dev/null; ip tuntap del mode tun dev tun0 2>/dev/null
echo "== fertig =="
