#!/bin/sh
# selftest-tcp.sh — isolierter TCP-Test durch tun0 (Port 80, verbose) + tun2socks-Debug.
set -u
echo "== Vorbereitung =="
xray-off >/dev/null 2>&1; killall tun2socks 2>/dev/null; sleep 1
/etc/init.d/xray start >/dev/null 2>&1; sleep 2

echo "== tun0 (MTU 1280) =="
ip tuntap add mode tun dev tun0 2>/dev/null
ip addr add 198.18.0.1/15 dev tun0 2>/dev/null
ip link set dev tun0 up; ip link set dev tun0 mtu 1280
/usr/bin/tun2socks -device tun0 -proxy socks5://127.0.0.1:10808 -loglevel debug > /tmp/t2s.log 2>&1 &
T=$!; sleep 2

echo "== TCP-Test durch tun0: http://1.1.1.1 (Port 80, kein TLS), verbose =="
ip route add 1.1.1.1/32 dev tun0 2>/dev/null
curl -v --max-time 12 -o /dev/null http://1.1.1.1/ 2>&1 | grep -iE 'trying|connected|http/|timed|refused|closed|reset' | sed 's/^/  /'
ip route del 1.1.1.1/32 dev tun0 2>/dev/null
sleep 1; kill "$T" 2>/dev/null

echo "== tun2socks-Debug-Log =="
tail -n 20 /tmp/t2s.log | sed 's/^/  /'

echo "== Aufraeumen =="
ip link set dev tun0 down 2>/dev/null; ip tuntap del mode tun dev tun0 2>/dev/null
/etc/init.d/xray stop 2>/dev/null
echo "== fertig =="
