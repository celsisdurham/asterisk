# Asterisk in Docker (this tree)

This replaces a **bare metal Ubuntu install** for many workflows: you build a single image that includes **chan_pjsip** and the **AudioSocket** modules, then run with **host networking** (Linux) so VoIP and RTP behave like a normal server.

## Build and run (Linux)

From the **repository root** (`/path/to/asterisk`):

```bash
cp docker/.env.example docker/.env   # fill in credentials and public IP (see table below)
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml up -d
```

The compose file uses **`network_mode: host`**, so Asterisk sees your host's interfaces and UDP **5060** / **RTP** the same as a non-container install. Your VoIP.ms firewall and NAT rules apply to the **host**, not a Docker bridge.

## Credentials and public IP — `docker/.env`

No passwords or IP addresses are stored in config files or the git repo. They live in **`docker/.env`** (gitignored) and are injected into the container as environment variables. Asterisk reads them at startup via `${ENV(VARNAME)}`.

Copy the template and fill it in:

```bash
cp docker/.env.example docker/.env
```

| Variable | What to set |
|---|---|
| `VOIPMS_USERNAME` | Sub-account username (e.g. `123456_mypbx`) |
| `VOIPMS_PASSWORD` | Sub-account SIP password |
| `VOIPMS_HOST` | VoIP.ms PoP hostname (e.g. `houston1.voip.ms`) |
| `VOIPMS_NET` | VoIP.ms signaling subnet for that PoP (see [wiki.voip.ms/article/Servers](https://wiki.voip.ms/article/Servers)) |
| `ASTERISK_PUBLIC_IP` | Your server's public IPv4 (`curl -s -4 https://ifconfig.me`) |

> If you change `.env`, you must **restart** the container — `pjsip reload` is not enough because env vars are read at config load time, not at SIP reload.

## Configuration and VoIP.ms

- The image **appends** `#include` for [docker/asterisk-config/pjsip.d/](../docker/asterisk-config/pjsip.d/) and [extensions.d/](../docker/asterisk-config/extensions.d/) to the stock `pjsip.conf` and `extensions.conf` at build time.
- [docker/docker-compose.yml](../docker/docker-compose.yml) **bind-mounts** those two directories, so you can edit config and reload without rebuilding (see caveat about `.env` above).
- Step-by-step: [docker/asterisk-config/README.md](../docker/asterisk-config/README.md).
- Trunk and portal: [voipms-asterisk.md](voipms-asterisk.md).
- Check registration:
  `docker compose -f docker/docker-compose.yml exec asterisk /usr/sbin/asterisk -rx "pjsip show registrations"`

## `load-to-ubuntu.sh` and Docker

- [contrib/scripts/load-to-ubuntu.sh](../contrib/scripts/load-to-ubuntu.sh) syncs the **source tree** to a remote host (or builds a **tarball** for offline use). It does not build Docker.
- For "run in Docker on this machine," use **`docker build` / `docker compose`** above, not the Ubuntu rsync script.

## macOS / Windows (Docker Desktop)

`network_mode: host` is **not** available the same way. Publish ports (see comments in [docker/docker-compose.yml](../docker/docker-compose.yml)) and set **external** IP / RTP in `pjsip.conf` / `rtp.conf` to match your host's reachability; expect more SIP/RTP issues than on Linux+host.

## After the container runs

- Register with VoIP.ms: use `asterisk -rx` from the host, or:
  `docker compose -f docker/docker-compose.yml exec asterisk /usr/sbin/asterisk -rx "pjsip show registrations"`
- **Calling the number** still needs **correct** `pjsip` + `extensions` + a reachable public IP; Docker does not change VoIP.ms portal settings.

## Tarball + Docker on another host

1. On the build machine: `./contrib/scripts/load-to-ubuntu.sh --tarball` (writes under `/tmp` by default).
2. Copy the `.tar.gz` to the server, extract, then `docker build -f docker/Dockerfile -t asterisk-voice:local .` from the extracted source.
3. Copy your `docker/.env` to the server separately (never include it in the tarball).
