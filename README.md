# mudi7-xray-reality

Transparent, DPI-resistant tunnel for a **GL.iNet Mudi 7 (GL-E5800)** travel router:
**Xray VLESS + REALITY + Vision** client with a **transparent proxy** (`hev-socks5-tunnel`)
so every device on the router's Wi-Fi is tunneled automatically — no per-device apps.
On-demand (`xray-on` / `xray-off`), default off.

> 🇬🇧 English below · 🇩🇪 Deutsch weiter unten

---

## 🇬🇧 English

### What this is

A reproducible, headless setup that turns a Mudi 7 into a stealth travel router:

- **Xray-core** (native, statically linked) as a **VLESS+REALITY+Vision** client to your own REALITY server.
- **hev-socks5-tunnel** (lwIP) as the transparent-proxy layer: LAN client traffic is policy-routed
  into a `tun0` device and relayed through Xray's local SOCKS inbound.
- **On-demand control**: `xray-on` enables the tunnel, `xray-off` disables it. Default after reboot: off.
- **DNS through the tunnel** (optional helper): the router's resolver upstreams are 
  fixed public resolvers (plain DNS) and routed through `tun0`, so DNS exits where the tunnel exits (no leak),
  while staying captive-portal-safe when the tunnel is off.

### Why hev / tun2socks instead of TPROXY

The Mudi 7 (Qualcomm SDX72 platform) uses **IPA hardware datapath offload** for LAN↔5G forwarding,
which bypasses netfilter. Classic nftables **TPROXY never sees the forwarded packets**. Routing
traffic into a **software `tun0`** forces the Linux path (IPA can't offload a software interface),
so the transparent proxy works regardless of the hardware accelerator.

A firewall zone for `tun0` (with masquerade + MSS clamping) is required — without it, `fw4` drops
the return path for the (otherwise zone-less) tunnel interface.

### Requirements

- GL.iNet Mudi 7 (GL-E5800), OpenWrt 23.05 based firmware, `aarch64`/musl.
- `kmod-tun` (installed automatically).
- Your own **Xray VLESS+REALITY server** with a public IP (e.g. a Synology/Docker box at home).
- `curl`, `unzip` on the router.

### Install

```sh
# 1) Get the repo onto the router
curl -fL https://codeload.github.com/ChiliApple/mudi7-xray-reality/tar.gz/refs/heads/main -o /tmp/r.tgz
mkdir -p /tmp/repo && tar -xzf /tmp/r.tgz -C /tmp/repo && cd "$(ls -d /tmp/repo/*/ | head -1)"

# 2) Create your secrets file (NOT committed) from the example and fill in your server
cp config/secrets.env.example /etc/xray/secrets.env
vi /etc/xray/secrets.env

# 3) Stage A — Xray core + REALITY client
sh scripts/install.sh

# 4) Stage B — transparent proxy (hev + firewall zone)
sh scripts/install-hev.sh

# 5) Optional — route the router's DNS upstreams through the tunnel (AdGuard Home setups)
sh scripts/setup-dns.sh
```

### Usage

```sh
xray-on      # enable the tunnel (stays on until xray-off)
xray-off     # disable — traffic goes direct (fail-safe)
sh scripts/selftest.sh    # verify the full path from the router itself
```

Default after reboot is **off**. To remove everything:

```sh
sh scripts/uninstall.sh
```

### Secrets & safety

- Real server address / UUID / keys live **only** in `/etc/xray/secrets.env` on the device
  (git-ignored). The repo ships only `config/config.template.json` with placeholders.
- Never commit `secrets.env`, your AdGuard config, or anything with real IPs/keys.

### Known gaps

- **IPv6** for clients is currently untunneled (blocked in the on-state to avoid leaks; refine as needed).
- The DNS helper targets an **AdGuard Home** setup; adapt for plain dnsmasq.

---

## 🇩🇪 Deutsch

### Was das ist

Ein reproduzierbares, headless Setup, das einen Mudi 7 in einen Stealth-Reise-Router verwandelt:

- **Xray-core** (nativ, statisch gelinkt) als **VLESS+REALITY+Vision**-Client zu deinem eigenen REALITY-Server.
- **hev-socks5-tunnel** (lwIP) als Transparent-Proxy-Schicht: LAN-Client-Traffic wird per Policy-Routing
  in ein `tun0`-Device geleitet und über Xrays lokalen SOCKS-Inbound getunnelt.
- **On-Demand**: `xray-on` schaltet ein, `xray-off` aus. Default nach Reboot: aus.
- **DNS durch den Tunnel** (optionaler Helfer): Die Resolver-Upstreams werden auf feste öffentliche Resolver (Plain-DNS)
  gesetzt und über `tun0` geroutet — DNS tritt dort aus, wo der Tunnel austritt (kein Leak),
  bleibt aber im Aus-Zustand captive-portal-fähig.

### Warum hev / tun2socks statt TPROXY

Der Mudi 7 (Qualcomm SDX72) nutzt **IPA-Hardware-Offload** für LAN↔5G-Forwarding, das netfilter umgeht.
Klassisches nftables-**TPROXY sieht die geforwardeten Pakete nie**. Traffic in ein **Software-`tun0`**
zu routen erzwingt den Linux-Pfad (IPA kann kein Software-Interface beschleunigen) — der Transparent-Proxy
funktioniert damit unabhängig vom Hardware-Beschleuniger.

Eine Firewall-Zone für `tun0` (mit Masquerade + MSS-Clamping) ist nötig — sonst verwirft `fw4`
den Rückweg des (sonst zonenlosen) Tunnel-Interfaces.

### Voraussetzungen

- GL.iNet Mudi 7 (GL-E5800), OpenWrt-23.05-basierte Firmware, `aarch64`/musl.
- `kmod-tun` (wird automatisch installiert).
- Eigener **Xray-VLESS+REALITY-Server** mit öffentlicher IP (z. B. Synology/Docker zuhause).
- `curl`, `unzip` am Router.

### Installation

```sh
# 1) Repo auf den Router holen
curl -fL https://codeload.github.com/ChiliApple/mudi7-xray-reality/tar.gz/refs/heads/main -o /tmp/r.tgz
mkdir -p /tmp/repo && tar -xzf /tmp/r.tgz -C /tmp/repo && cd "$(ls -d /tmp/repo/*/ | head -1)"

# 2) secrets-Datei (nicht im Repo) aus dem Beispiel anlegen und Server eintragen
cp config/secrets.env.example /etc/xray/secrets.env
vi /etc/xray/secrets.env

# 3) Stage A — Xray-core + REALITY-Client
sh scripts/install.sh

# 4) Stage B — Transparent-Proxy (hev + Firewall-Zone)
sh scripts/install-hev.sh

# 5) Optional — Router-DNS-Upstreams durch den Tunnel (AdGuard-Home-Setups)
sh scripts/setup-dns.sh
```

### Nutzung

```sh
xray-on      # Tunnel an (bleibt an bis xray-off)
xray-off     # aus — Traffic direkt (fail-safe)
sh scripts/selftest.sh    # kompletten Pfad vom Router selbst testen
```

Default nach Reboot ist **aus**. Alles entfernen:

```sh
sh scripts/uninstall.sh
```

### Secrets & Sicherheit

- Echte Server-Adresse / UUID / Keys liegen **nur** in `/etc/xray/secrets.env` auf dem Gerät
  (git-ignored). Im Repo ist nur `config/config.template.json` mit Platzhaltern.
- Niemals `secrets.env`, deine AdGuard-Config oder etwas mit echten IPs/Keys committen.

### Bekannte Lücken

- **IPv6** der Clients ist aktuell ungetunnelt (im An-Zustand geblockt, um Leaks zu vermeiden).
- Der DNS-Helfer zielt auf **AdGuard Home**; für reines dnsmasq anpassen.

---

## Credits

- [XTLS/Xray-core](https://github.com/XTLS/Xray-core) — REALITY protocol & client.
- [heiher/hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) — lwIP transparent proxy.

## License

MIT — see `LICENSE`. No warranty. Use responsibly and only on networks/services you are allowed to use.
