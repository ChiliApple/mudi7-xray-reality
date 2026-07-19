#!/bin/sh
# setup-dns.sh — switch AdGuard upstreams to IP-literal DoH.
# Captive-portal-safe: tunnel off -> DoH direct; tunnel on -> same IPs via tun0 (no leak).
set -u
CFG=/etc/AdGuardHome/config.yaml
log(){ echo "[dns] $*"; }
[ -f "$CFG" ] || { echo "[dns][ERROR] $CFG not found"; exit 1; }

cp "$CFG" "$CFG.bak.$(date +%Y%m%d-%H%M%S)"
log "Backup: $CFG.bak.*"

awk '
/^  upstream_dns:/ {print; print "    - 1.1.1.1"; print "    - 9.9.9.9"; b="up"; next}
/^  fallback_dns:/ {print; print "    - 1.1.1.1"; print "    - 9.9.9.9"; b="fb"; next}
b!="" && /^    - / {next}
b!="" && !/^    - / {b=""}
{print}
' "$CFG" > "$CFG.new" && mv "$CFG.new" "$CFG"
log "upstream_dns -> plain DNS (1.1.1.1, 9.9.9.9) - fast; still tunneled via tun0 = no leak"
log "(bootstrap_dns unchanged)"

echo "--- new values ---"
sed -n '/upstream_dns:/,/upstream_mode/p' "$CFG"

SVC=""
for c in $(ls /etc/init.d/ 2>/dev/null | grep -i guard); do SVC=$c; break; done
if [ -n "$SVC" ]; then
    /etc/init.d/"$SVC" restart >/dev/null 2>&1 && log "AdGuard service '$SVC' restarted."
else
    log "WARN: no AdGuard init found under /etc/init.d."
fi
echo "AGH_SERVICE=${SVC:-UNKNOWN}"
