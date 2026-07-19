# After a GL.iNet firmware update

> 🇬🇧 English below · 🇩🇪 Deutsch weiter unten

A firmware update can overwrite files and reset packages. This project is built so that
**recovery is one pass of the (idempotent) installers** — but you need to know what to re-run.

---

## 🇬🇧 English

### The one rule

After any firmware update, run the check and follow its advice:

```sh
# get the repo again (/tmp is wiped on reboot)
curl -fL https://codeload.github.com/ChiliApple/mudi7-xray-reality/tar.gz/refs/heads/main -o /tmp/r.tgz
mkdir -p /tmp/repo && tar -xzf /tmp/r.tgz -C /tmp/repo && cd "$(ls -d /tmp/repo/*/ | head -1)"

sh scripts/postupdate-check.sh
```

It checks every component read-only and prints the exact commands to restore anything missing.

### What survives, what doesn't

| Element | Location | Survives update? |
|---|---|---|
| `xray` / `hev` binaries | `/usr/bin/` | usually (overlay), not guaranteed |
| configs, init services, `xray-on/off` | `/etc/…`, `/usr/sbin/` | usually, if **"Keep Settings"** was on |
| firewall zone `vpntun` | `uci firewall` | yes (settings) |
| AdGuard upstreams | `/etc/AdGuardHome/config.yaml` | **may be reset** by the firmware |
| **`kmod-tun`** | opkg / kernel module | **often NO** — kernel modules are bound to the exact kernel version |
| **`/etc/xray/secrets.env`** | `/etc/xray/` | usually, but it is the **only piece not in the repo** |

### The two things to remember

1. **`kmod-tun` is the classic trap.** Kernel modules only match the exact kernel they were built
   for. After a firmware update with a new kernel, the old module is unusable → `xray-on` fails
   because `tun0` cannot be created. `install-hev.sh` reinstalls the matching `kmod-tun`.

2. **`secrets.env` is the only irreplaceable file.** It holds *your* server address, UUID and keys
   and is deliberately **not** in the repo. Back it up somewhere safe. If it is gone after an update,
   restore it (template: `config/secrets.env.example`) before running `install.sh`.

### Before you update (optional but nice)

- In the GL.iNet update dialog, enable **"Keep Settings"**.
- Copy `/etc/xray/secrets.env` somewhere off-device as a backup.
- `setup-dns.sh` already writes a timestamped backup of the AdGuard config each time it runs.

### Recovery in short

```sh
# (restore /etc/xray/secrets.env first if the check flagged it missing)
sh scripts/install.sh        # xray core + rendered config
sh scripts/install-hev.sh    # hev + kmod-tun + firewall zone
sh scripts/setup-dns.sh      # AdGuard upstreams (only if the check flagged them)
sh scripts/selftest.sh       # verify
```

Default after recovery is **off** (tunnel enabled on demand with `xray-on`).

---

## 🇩🇪 Deutsch

### Die eine Regel

Nach jedem Firmware-Update den Check laufen lassen und seinem Rat folgen:

```sh
# Repo erneut holen (/tmp ist nach Reboot leer)
curl -fL https://codeload.github.com/ChiliApple/mudi7-xray-reality/tar.gz/refs/heads/main -o /tmp/r.tgz
mkdir -p /tmp/repo && tar -xzf /tmp/r.tgz -C /tmp/repo && cd "$(ls -d /tmp/repo/*/ | head -1)"

sh scripts/postupdate-check.sh
```

Er prüft jede Komponente rein lesend und gibt die exakten Befehle aus, um Fehlendes wiederherzustellen.

### Was überlebt, was nicht

| Element | Ort | Überlebt Update? |
|---|---|---|
| `xray` / `hev` Binaries | `/usr/bin/` | meist (overlay), nicht garantiert |
| Configs, Init-Services, `xray-on/off` | `/etc/…`, `/usr/sbin/` | meist, wenn **"Keep Settings"** an war |
| Firewall-Zone `vpntun` | `uci firewall` | ja (Settings) |
| AdGuard-Upstreams | `/etc/AdGuardHome/config.yaml` | **evtl. zurückgesetzt** durch die Firmware |
| **`kmod-tun`** | opkg / Kernel-Modul | **oft NEIN** — Kernel-Module sind an die exakte Kernel-Version gebunden |
| **`/etc/xray/secrets.env`** | `/etc/xray/` | meist, aber das **einzige Teil, das nicht im Repo** liegt |

### Die zwei Dinge, die man wissen muss

1. **`kmod-tun` ist die klassische Falle.** Kernel-Module passen nur zum exakten Kernel, für den sie
   gebaut wurden. Nach einem Firmware-Update mit neuem Kernel ist das alte Modul unbrauchbar →
   `xray-on` scheitert, weil `tun0` nicht angelegt werden kann. `install-hev.sh` installiert das
   passende `kmod-tun` neu.

2. **`secrets.env` ist die einzige unersetzliche Datei.** Sie enthält *deine* Server-Adresse, UUID
   und Keys und liegt bewusst **nicht** im Repo. Sichere sie an einem sicheren Ort. Ist sie nach
   einem Update weg, stelle sie (Vorlage: `config/secrets.env.example`) vor `install.sh` wieder her.

### Vor dem Update (optional, aber sinnvoll)

- Im GL.iNet-Update-Dialog **"Keep Settings"** aktivieren.
- `/etc/xray/secrets.env` als Backup vom Gerät wegkopieren.
- `setup-dns.sh` legt bei jedem Lauf ohnehin ein zeitgestempeltes Backup der AdGuard-Config an.

### Wiederherstellung in Kurzform

```sh
# (zuerst /etc/xray/secrets.env wiederherstellen, falls der Check es als fehlend meldet)
sh scripts/install.sh        # Xray-core + gerenderte Config
sh scripts/install-hev.sh    # hev + kmod-tun + Firewall-Zone
sh scripts/setup-dns.sh      # AdGuard-Upstreams (nur wenn der Check es meldet)
sh scripts/selftest.sh       # verifizieren
```

Default nach der Wiederherstellung ist **aus** (Tunnel bei Bedarf mit `xray-on`).
