#!/bin/sh
# setup-dns.sh — AdGuard-Upstreams auf IP-fixierte DoH umstellen.
# Captive-Portal-sicher: Tunnel aus -> DoH direkt; Tunnel an -> dieselben IPs via tun0 (kein Leak).
set -u
CFG=/etc/AdGuardHome/config.yaml
log(){ echo "[dns] $*"; }
[ -f "$CFG" ] || { echo "[dns][FEHLER] $CFG nicht gefunden"; exit 1; }

cp "$CFG" "$CFG.bak.$(date +%Y%m%d-%H%M%S)"
log "Backup: $CFG.bak.*"

awk '
/^  upstream_dns:/ {print; print "    - https://1.1.1.1/dns-query"; print "    - https://9.9.9.9/dns-query"; b="up"; next}
/^  fallback_dns:/ {print; print "    - 1.1.1.1"; print "    - 9.9.9.9"; b="fb"; next}
b!="" && /^    - / {next}
b!="" && !/^    - / {b=""}
{print}
' "$CFG" > "$CFG.new" && mv "$CFG.new" "$CFG"
log "upstream_dns -> IP-fixierte DoH (1.1.1.1, 9.9.9.9); fallback_dns -> 1.1.1.1, 9.9.9.9"
log "(bootstrap_dns unveraendert)"

echo "--- neue Werte ---"
sed -n '/upstream_dns:/,/upstream_mode/p' "$CFG"

SVC=""
for c in $(ls /etc/init.d/ 2>/dev/null | grep -i guard); do SVC=$c; break; done
if [ -n "$SVC" ]; then
    /etc/init.d/"$SVC" restart >/dev/null 2>&1 && log "AdGuard-Service '$SVC' neu gestartet."
else
    log "WARN: kein AdGuard-Init unter /etc/init.d gefunden."
fi
echo "AGH_SERVICE=${SVC:-UNBEKANNT}"
