#!/bin/sh
# setup-fw.sh — Firewall-Zone fuer tun0 (masq + mtu_fix) + lan->vpntun Forwarding.
# Noetig, weil fw4 Traffic zu/von zonenlosen Interfaces verwirft.
set -u
log(){ echo "[fw] $*"; }

# LAN-Zone-Namen ermitteln (meist 'lan')
LANZONE="$(uci show firewall 2>/dev/null | sed -n "s/.*\.name='\(lan\)'/\1/p" | head -1)"
[ -n "$LANZONE" ] || LANZONE=lan
log "LAN-Zone: $LANZONE"

uci -q delete firewall.vpntun
uci set firewall.vpntun=zone
uci set firewall.vpntun.name='vpntun'
uci set firewall.vpntun.input='ACCEPT'
uci set firewall.vpntun.output='ACCEPT'
uci set firewall.vpntun.forward='ACCEPT'
uci set firewall.vpntun.masq='1'
uci set firewall.vpntun.mtu_fix='1'
uci add_list firewall.vpntun.device='tun0'

uci -q delete firewall.lan_vpntun
uci set firewall.lan_vpntun=forwarding
uci set firewall.lan_vpntun.src="$LANZONE"
uci set firewall.lan_vpntun.dest='vpntun'

uci commit firewall
fw4 reload >/dev/null 2>&1 && log "Zone 'vpntun' aktiv (tun0: masq+mtu_fix, ${LANZONE}->vpntun erlaubt)."
echo "--- Kontrolle ---"
uci show firewall.vpntun; uci show firewall.lan_vpntun
