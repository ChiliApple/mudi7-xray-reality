# mudi7-xray-reality

Reproduzierbares Setup fuer einen **Xray-core VLESS+REALITY+Vision Client** auf dem
**GL.iNet Mudi 7 (GL-E5800)** unter OpenWrt 23.05 (aarch64/musl).

Zweck: Der Mudi tunnelt seinen Traffic ueber einen selbst gehosteten
REALITY-Server (DPI-Bypass in restriktiven Netzen). Ziel ist ein Setup, das nach
einem GL.iNet-Firmware-Update in **einem Befehl** wiederhergestellt ist.

> **Warum Xray-core statt sing-box?**
> Ab xray-core **26.7.11** setzen REALITY-*Server* per Default `minClientVer=26.3.27`
> und weisen aeltere Clients ab. sing-box meldet eine `1.x`-Version und faellt damit
> **strukturell** durch diese Huerde — egal welche sing-box-Version. Xray-core meldet
> `26.x` und nimmt die Huerde **nativ**, ohne dass der Server aufgeweicht werden muss.
> Bonus: Xrays Linux-Builds sind statisch (reines Go) und laufen ohne glibc/musl-Drama.

---

## Sicherheit

- **Keine Secrets im Repo.** UUID, REALITY-Keys, Server-Adresse liegen ausschliesslich
  in `/etc/xray/secrets.env` auf dem Geraet (per `.gitignore` ausgeschlossen).
- `secrets.env` gehoert in deinen Passwortmanager / auf einen USB-Stick — **nicht** ins Git.
- `config.json` und `secrets.env` werden mit `chmod 600` geschrieben.
- Das Binary wird gegen die offizielle `.dgst`-Pruefsumme von XTLS verifiziert.

---

## Struktur

| Pfad | Zweck |
|------|-------|
| `scripts/install.sh`   | Installer: Binary laden+verifizieren, Config rendern, Service einrichten |
| `scripts/uninstall.sh` | Sauberes Entfernen |
| `config/config.template.json` | Xray-Client-Config mit Platzhaltern (keine Secrets) |
| `config/secrets.env.example`  | Vorlage fuer die lokale Secrets-Datei |
| `etc/init.d/xray`      | procd-Service |
| `VERSION`              | gepinnte Xray-core-Version |

---

## Erstinstallation

1. `unzip` sicherstellen: `opkg update && opkg install unzip`
2. Repo aufs Geraet holen (z. B. nach `/root/mudi7-xray-reality`).
3. Secrets anlegen:
   ```
   mkdir -p /etc/xray
   cp config/secrets.env.example /etc/xray/secrets.env
   vi /etc/xray/secrets.env      # Werte eintragen
   chmod 600 /etc/xray/secrets.env
   ```
4. Installieren:
   ```
   sh scripts/install.sh
   ```
5. Testen:
   ```
   curl --socks5-hostname 127.0.0.1:10808 https://api.ipify.org ; echo
   ```
   Erwartung: die oeffentliche IP deines REALITY-Servers.

---

## Wiederherstellung nach GL.iNet-Firmware-Update

Ein Firmware-Update loescht Binary, Config und Service. Wiederherstellung:

1. `opkg update && opkg install unzip`
2. Repo erneut holen.
3. `secrets.env` nach `/etc/xray/` zuruecklegen (aus Passwortmanager/USB).
4. `sh scripts/install.sh`

Das war's — kein Nachbauen von Hand.

---

## Stages

Dieses Setup wird stufenweise aufgebaut; jede Stufe wird erst nach erfolgreichem
Test auf dem Geraet committet.

- **Stage A (dieses Fundament):** Binary + Config + procd-Service. Traffic-Test
  ueber lokalen SOCKS-Inbound (`127.0.0.1:10808`). Beweist REALITY-Handshake und
  nativen `minClientVer`-Durchgang.
- **Stage B (folgt):** Transparent Proxy (nftables/TPROXY) — jedes Geraet am Mudi-WLAN
  tunnelt automatisch, ohne Client-Apps.
- **Stage C (folgt):** Physischer Schalter (an/aus) + finaler Restore-Feinschliff.

---

## Deinstallation

```
sh scripts/uninstall.sh
# komplett inkl. Secrets:  rm -rf /etc/xray
```
