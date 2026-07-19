#!/bin/sh
# uninstall.sh — entfernt den kompletten Stealth-Tunnel-Stack sauber vom Mudi.
# Bringt Router in den Auslieferungszustand zurueck (bzgl. dieses Projekts).
set -u
log(){ echo "[uninstall] $*"; }

# 1) Tunnel sicher aus
[ -x /usr/sbin/xray-off ] && /usr/sbin/xray-off >/dev/null 2>&1

# 2) Dienste stoppen + entfernen
for svc in hev tun2socks xray; do
    [ -f /etc/init.d/$svc ] && { /etc/init.d/$svc stop 2>/dev/null; /etc/init.d/$svc disable 2>/dev/null; rm -f /etc/init.d/$svc; }
done

# 3) Binaries + Configs + Befehle
rm -f /usr/bin/hev-socks5-tunnel /usr/bin/tun2socks /usr/bin/xray
rm -rf /etc/hev /etc/xray
rm -f /usr/sbin/xray-on /usr/sbin/xray-off /usr/sbin/xray-confirm

# 4) Firewall-Zone entfernen
uci -q delete firewall.vpntun
uci -q delete firewall.lan_vpntun
uci commit firewall
fw4 reload >/dev/null 2>&1

# 5) evtl. Rest-Interfaces/Regeln
ip link show tun0 >/dev/null 2>&1 && { ip link set tun0 down 2>/dev/null; ip tuntap del mode tun dev tun0 2>/dev/null; }
nft delete table inet xray 2>/dev/null
ip rule del fwmark 0x1 lookup 100 2>/dev/null
ip route flush table 100 2>/dev/null
ip route flush table 200 2>/dev/null

log "Deinstalliert. hev/xray/tun2socks + Configs + Befehle + Firewall-Zone entfernt."
log "kmod-tun bleibt installiert (Standardmodul, schadet nicht). Bei Bedarf: opkg remove kmod-tun"
