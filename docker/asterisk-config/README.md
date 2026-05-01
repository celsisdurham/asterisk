# VoIP.ms + dialplan in Docker

These files are **baked into the image** at build time and also **bind-mounted** at runtime for live reloads.

| Path | Role |
|------|------|
| [pjsip.d/00-transport-udp.conf](pjsip.d/00-transport-udp.conf) | UDP `transport-udp`; reads `ASTERISK_PUBLIC_IP` from env |
| [pjsip.d/50-voipms.conf](pjsip.d/50-voipms.conf) | VoIP.ms sub-account, registration, endpoint; reads all credentials from env |
| [extensions.d/10-from-voipms.conf](extensions.d/10-from-voipms.conf) | `from-voipms` context; plays `hello-world` for a quick test (swap in `AudioSocket` later) |

## 1) Create your `.env` file

Credentials and your public IP are **never** stored in config files or git. They live in `docker/.env`, which is gitignored.

```bash
cp docker/.env.example docker/.env
# edit docker/.env and fill in your real values
```

| Variable | What to set |
|---|---|
| `VOIPMS_USERNAME` | Sub-account username (e.g. `123456_mypbx`) |
| `VOIPMS_PASSWORD` | Sub-account SIP password |
| `VOIPMS_HOST` | VoIP.ms PoP hostname (e.g. `houston1.voip.ms`) |
| `VOIPMS_NET` | VoIP.ms signaling subnet for that PoP (see [wiki.voip.ms/article/Servers](https://wiki.voip.ms/article/Servers)) |
| `ASTERISK_PUBLIC_IP` | Your server's public IPv4 (run `curl -s -4 https://ifconfig.me`) |

Asterisk reads these at startup via `${ENV(VARNAME)}` in the PJSIP config files.

## 2) Build and start

```bash
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml up -d
```

## 3) Reload config without rebuilding

The `pjsip.d/` and `extensions.d/` directories are bind-mounted, so you can edit them and reload without a rebuild:

```bash
docker compose -f docker/docker-compose.yml exec asterisk /usr/sbin/asterisk -rx "pjsip reload"
docker compose -f docker/docker-compose.yml exec asterisk /usr/sbin/asterisk -rx "dialplan reload"
```

> **Note:** `${ENV(VAR)}` is evaluated at config load time, so if you change `.env` you must restart the container (not just reload).

## 4) Check registration (VoIP.ms)

```bash
docker compose -f docker/docker-compose.yml exec asterisk /usr/sbin/asterisk -rx "pjsip show registrations"
```

You should see a **Registered** line for your VoIP.ms PoP. If not, see [docs/voipms-asterisk.md](../../docs/voipms-asterisk.md) (wrong username/password, wrong PoP, firewall, NAT).
