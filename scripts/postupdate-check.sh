#!/bin/sh
# postupdate-check.sh — run this AFTER a GL.iNet firmware update.
# Checks what survived the update and prints exactly what to re-run.
# Read-only: it changes nothing, it only advises.
set -u
OK=0; MISS=0
ok()   { echo "  [OK]   $1"; OK=$((OK+1)); }
miss() { echo "  [MISS] $1"; MISS=$((MISS+1)); }

echo "== Binaries =="
[ -x /usr/bin/xray ] && ok "/usr/bin/xray" || miss "/usr/bin/xray"
[ -x /usr/bin/hev-socks5-tunnel ] && ok "/usr/bin/hev-socks5-tunnel" || miss "/usr/bin/hev-socks5-tunnel"

echo "== Config & secrets =="
if [ -f /etc/xray/secrets.env ]; then ok "/etc/xray/secrets.env (your server details)"
else miss "/etc/xray/secrets.env  <-- NOT in the repo! restore from your own backup"; fi
[ -f /etc/xray/config.json ] && ok "/etc/xray/config.json (rendered)" || miss "/etc/xray/config.json"
[ -f /etc/hev/config.yaml ] && ok "/etc/hev/config.yaml" || miss "/etc/hev/config.yaml"

echo "== Services & commands =="
[ -f /etc/init.d/xray ] && ok "/etc/init.d/xray" || miss "/etc/init.d/xray"
[ -f /etc/init.d/hev ] && ok "/etc/init.d/hev" || miss "/etc/init.d/hev"
[ -x /usr/sbin/xray-on ] && ok "/usr/sbin/xray-on" || miss "/usr/sbin/xray-on"
[ -x /usr/sbin/xray-off ] && ok "/usr/sbin/xray-off" || miss "/usr/sbin/xray-off"

echo "== kmod-tun (CRITICAL - bound to the kernel version) =="
if ip tuntap add mode tun dev tuncheck0 2>/dev/null; then
    ip tuntap del mode tun dev tuncheck0 2>/dev/null
    ok "TUN works (kmod-tun present for this kernel)"
else
    miss "TUN does NOT work -> kmod-tun missing/incompatible with the new kernel"
fi

echo "== Firewall zone =="
uci -q get firewall.vpntun >/dev/null 2>&1 && ok "firewall zone 'vpntun'" || miss "firewall zone 'vpntun'"

echo "== AdGuard upstreams (DNS through tunnel) =="
AGH=/etc/AdGuardHome/config.yaml
if [ -f "$AGH" ]; then
    if sed -n '/^  upstream_dns:/,/^  upstream_dns_file/p' "$AGH" | grep -q '^    - 1\.1\.1\.1$'; then
        ok "AdGuard upstream = plain 1.1.1.1 (our tunneled DNS)"
    else
        miss "AdGuard upstreams changed/reset by firmware -> re-run setup-dns.sh"
    fi
else
    echo "  [--]   no AdGuard config found (skip)"
fi

echo
echo "==================== RESULT ===================="
echo "  OK: $OK   MISSING: $MISS"
echo
if [ "$MISS" -eq 0 ]; then
    echo "Everything survived. Nothing to do."
    echo "Verify anyway with:  sh scripts/selftest.sh"
else
    echo "Re-run the installers below to restore what's missing."
    echo "They are idempotent and verify every download by SHA256 - safe to run again."
    echo
    if [ ! -f /etc/xray/secrets.env ]; then
        echo "  # FIRST restore /etc/xray/secrets.env from your backup"
        echo "  #   (it is the ONLY piece not in the repo)."
        echo "  #   template: config/secrets.env.example ; then: chmod 600 /etc/xray/secrets.env"
        echo
    fi
    echo "  sh scripts/install.sh        # xray core + rendered config (needs secrets.env)"
    echo "  sh scripts/install-hev.sh    # hev + kmod-tun + firewall zone"
    echo "  sh scripts/setup-dns.sh      # AdGuard upstreams (only if flagged above)"
    echo
    echo "Then verify:  sh scripts/selftest.sh"
fi
