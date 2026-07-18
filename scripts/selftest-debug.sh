#!/bin/sh
# selftest-debug.sh v2 — rp_filter aus + SOCKS-Verbindungscheck + tun2socks-Debug.
set -u
echo "== Vorbereitung =="
xray-off >/dev/null 2>&1; killall tun2socks 2>/dev/null; sleep 1

echo "== rp_filter AUS (Antwort-Pakete auf tun0 nicht verwerfen) =="
for k in all default tun0 br-lan rmnet_data1; do
  v=$(sysctl -n net.ipv4.conf.$k.rp_filter 2>/dev/null) && sysctl -w net.ipv4.conf.$k.rp_filter=0 >/dev/null 2>&1 && echo "  $k: $v -> 0"
done

echo "== Xray/SOCKS =="
/etc/init.d/xray start >/dev/null 2>&1; sleep 2
echo -n "  SOCKS-Ref: "; curl -s --max-time 8 --socks5-hostname 127.0.0.1:10808 https://api.ipify.org; echo

echo "== tun0 (MTU 1280) =="
ip tuntap add mode tun dev tun0 2>/dev/null
ip addr add 198.18.0.1/15 dev tun0 2>/dev/null
ip link set dev tun0 up; ip link set dev tun0 mtu 1280
sysctl -w net.ipv4.conf.tun0.rp_filter=0 >/dev/null 2>&1

echo "== tun2socks DEBUG =="
/usr/bin/tun2socks -device tun0 -proxy socks5://127.0.0.1:10808 -loglevel debug > /tmp/t2s.log 2>&1 &
T=$!; sleep 2
kill -0 "$T" 2>/dev/null && echo "  tun2socks laeuft (pid $T)" || echo "  !! tun2socks tot"

echo "== Test durch tun0 =="
ip route add 1.1.1.1/32 dev tun0 2>/dev/null
( sleep 3; echo "  [SOCKS-Verbindungen]:"; netstat -tn 2>/dev/null | grep ':10808' | sed 's/^/    /' ) &
echo -n "  Trace: "; curl -s --max-time 12 https://1.1.1.1/cdn-cgi/trace 2>/dev/null | grep -E '^ip=' || echo "(keine Antwort)"
wait
ip route del 1.1.1.1/32 dev tun0 2>/dev/null
sleep 1; kill "$T" 2>/dev/null

echo "== tun2socks-Log =="
tail -n 15 /tmp/t2s.log | sed 's/^/  /'

echo "== Aufraeumen =="
ip link set dev tun0 down 2>/dev/null; ip tuntap del mode tun dev tun0 2>/dev/null
/etc/init.d/xray stop 2>/dev/null
echo "== fertig =="
