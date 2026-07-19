#!/bin/sh
# uninstall.sh — cleanly removes the whole tunnel stack from the router.
# Returns the router to its stock state (with respect to this project).
set -u
log(){ echo "[uninstall] $*"; }

# 1) tunnel safely off
[ -x /usr/sbin/xray-off ] && /usr/sbin/xray-off >/dev/null 2>&1

# 2) stop + remove services
for svc in hev tun2socks xray; do
    [ -f /etc/init.d/$svc ] && { /etc/init.d/$svc stop 2>/dev/null; /etc/init.d/$svc disable 2>/dev/null; rm -f /etc/init.d/$svc; }
done

# 3) binaries + configs + commands
rm -f /usr/bin/hev-socks5-tunnel /usr/bin/tun2socks /usr/bin/xray
rm -rf /etc/hev /etc/xray
rm -f /usr/sbin/xray-on /usr/sbin/xray-off /usr/sbin/xray-confirm

# 4) remove firewall zone
uci -q delete firewall.vpntun
uci -q delete firewall.lan_vpntun
uci commit firewall
fw4 reload >/dev/null 2>&1

# 5) leftover interfaces/rules
ip link show tun0 >/dev/null 2>&1 && { ip link set tun0 down 2>/dev/null; ip tuntap del mode tun dev tun0 2>/dev/null; }
nft delete table inet xray 2>/dev/null
ip rule del fwmark 0x1 lookup 100 2>/dev/null
ip route flush table 100 2>/dev/null
ip route flush table 200 2>/dev/null

log "Uninstalled. hev/xray/tun2socks + configs + commands + firewall zone removed."
log "kmod-tun stays installed (standard module, harmless). If desired: opkg remove kmod-tun"
