#!/bin/sh
# selftest-tcp.sh v2 — TCP-Test durch tun0 mit Xray-debug + tun2socks-debug + SOCKS-conns.
set -u
CFG=/etc/xray/config.json
echo "== Vorbereitung =="
xray-off >/dev/null 2>&1; killall tun2socks 2>/dev/null; sleep 1
cp "$CFG" /tmp/config.json.bak
sed -i 's/"loglevel": *"[a-z]*"/"loglevel": "debug"/' "$CFG"
/etc/init.d/xray restart >/dev/null 2>&1; sleep 2

echo "== tun0 + tun2socks (debug) =="
ip tuntap add mode tun dev tun0 2>/dev/null
ip addr add 198.18.0.1/15 dev tun0 2>/dev/null
ip link set dev tun0 up; ip link set dev tun0 mtu 1280
/usr/bin/tun2socks -device tun0 -proxy socks5://127.0.0.1:10808 -loglevel debug > /tmp/t2s.log 2>&1 &
T=$!; sleep 2

echo "== TCP-Test http://1.1.1.1 (Port 80) =="
ip route add 1.1.1.1/32 dev tun0 2>/dev/null
( sleep 3; echo "  [SOCKS-conns]:"; netstat -tn 2>/dev/null | grep ':10808' | sed 's/^/    /' ) &
curl -s --max-time 10 -o /dev/null -w "  curl: code=%{http_code} time=%{time_total}s\n" http://1.1.1.1/ 2>&1
wait
ip route del 1.1.1.1/32 dev tun0 2>/dev/null
sleep 1; kill "$T" 2>/dev/null

echo "== Xray-Log: TCP zu 1.1.1.1? =="
logread | grep -i xray | grep -iE 'tcp:1\.1\.1\.1|1\.1\.1\.1:80|dialing to tcp|tunneling request to tcp|rejected|failed' | tail -n 12 | sed 's/^/  /'
echo "  (wenn leer: Xray hat KEINEN TCP-Connect zu 1.1.1.1 gesehen)"

echo "== tun2socks-Log =="
tail -n 12 /tmp/t2s.log | sed 's/^/  /'

echo "== zurueck + aufraeumen =="
cp /tmp/config.json.bak "$CFG"
/etc/init.d/xray stop >/dev/null 2>&1
ip link set dev tun0 down 2>/dev/null; ip tuntap del mode tun dev tun0 2>/dev/null
echo "== fertig =="
