#!/bin/sh
# security-check.sh — read-only audit of the tunnel stack's network exposure.
# Changes NOTHING. Run with the tunnel ON (xray-on) so live listeners are visible.
set -u
OK=0; WARN=0
ok()   { echo "  [OK]   $1"; OK=$((OK+1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN+1)); }

echo "== 1) Our stack's listeners (xray / hev) =="
LS="$(netstat -lnp 2>/dev/null | grep -E 'xray|hev-socks5' || true)"
if [ -n "$LS" ]; then
    echo "$LS" | sed 's/^/  /'
    EXPOSED="$(echo "$LS" | grep -E '0\.0\.0\.0:|:::' | grep -vE '127\.0\.0\.1|::1' || true)"
    [ -n "$EXPOSED" ] && warn "listener on a non-loopback address (reachable from LAN):" && echo "$EXPOSED" | sed 's/^/         /' || ok "all our listeners are loopback-only"
else
    echo "  [--]   no xray/hev listeners (tunnel off? run 'xray-on' first for a full check)"
fi

echo
echo "== 2) SOCKS inbound 10808 (must be 127.0.0.1 only) =="
S="$(netstat -lnp 2>/dev/null | grep ':10808' || true)"
if [ -n "$S" ]; then
    echo "$S" | grep -qvE '127\.0\.0\.1' && warn "SOCKS 10808 reachable off-loopback!" || ok "SOCKS 10808 loopback-only"
else
    echo "  [--]   SOCKS not listening (tunnel off)"
fi

echo
echo "== 3) Leftover TPROXY inbound (dokodemo 0.0.0.0:12345)? =="
if grep -q '"tproxy-in"' /etc/xray/config.json 2>/dev/null; then
    warn "tproxy-in present in /etc/xray/config.json - UNUSED with hev, opens 0.0.0.0:12345 -> remove"
elif netstat -lnp 2>/dev/null | grep -q ':12345'; then
    warn "port 12345 is listening (leftover tproxy-in) -> remove from config"
else
    ok "no leftover tproxy inbound"
fi

echo
echo "== 4) Firewall zone 'vpntun' input policy =="
INP="$(uci -q get firewall.vpntun.input 2>/dev/null || echo '')"
case "$INP" in
    REJECT|DROP) ok "vpntun input = $INP (restrictive)";;
    ACCEPT)      warn "vpntun input = ACCEPT -> harden to REJECT (tun0 needs no inbound to the router)";;
    "")          echo "  [--]   vpntun zone not present";;
    *)           warn "vpntun input = $INP (unexpected)";;
esac

echo
echo "== 5) Config listen addresses (static) =="
grep -nE '"listen"|"port"' /etc/xray/config.json 2>/dev/null | sed 's/^/  xray: /' | head -8
grep -nE 'address|port' /etc/hev/config.yaml 2>/dev/null | sed 's/^/  hev:  /'

echo
echo "== 6) Any of our ports open toward WAN? (best-effort) =="
WANDEV="$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')"
echo "  WAN device: ${WANDEV:-unknown}"
echo "  Note: xray binds 127.0.0.1, hev reads tun0 - neither binds the WAN."
echo "  GL.iNet fw4 default is WAN input = REJECT; verify no custom rule opens 10808/12345."

echo
echo "==================== RESULT ===================="
echo "  OK: $OK   WARN: $WARN"
if [ "$WARN" -eq 0 ]; then
    echo "  No exposure findings. Safe to publish."
else
    echo "  Review/harden the WARN items above BEFORE publishing."
fi
