# Running this Asterisk tree on Ubuntu

> **Docker instead?** You can run Asterisk in a container with host networking: [docker-asterisk.md](docker-asterisk.md) (Linux). This page is for a **normal install** on the OS.

Use an **Ubuntu Server LTS** (22.04 or 24.04) as the **primary** host for Asterisk, PJSIP/SIP trunking, and the voicebot stack described in [asterisk-voicebot-pipeline.md](asterisk-voicebot-pipeline.md). Ubuntu has well-tested packages, straightforward `ufw` firewall rules, and matches the assumptions in Asterisk’s own `install_prereq` script.

## 1. Get this source tree onto Ubuntu

- **Rsync/SSH (recommended)**: from your checkout on another machine, run the helper script (defaults to `~/asterisk-src` on the server):

  ```bash
  ./contrib/scripts/load-to-ubuntu.sh user@ubuntubox
  ./contrib/scripts/load-to-ubuntu.sh --bootstrap --configure user@ubuntubox
  # Optional:   ./contrib/scripts/load-to-ubuntu.sh --identity ~/.ssh/id_ed25519 --bootstrap user@ubuntubox
  # Offline:    ./contrib/scripts/load-to-ubuntu.sh --tarball   # then scp the .tar.gz to Ubuntu
  ```

  `REMOTE_DIR` should not contain spaces; a leading `~` (e.g. `~/asterisk-src`) is fine.

- **Architecture**: x86_64 or arm64 both work; ONNX/Moonshine wheels are easier to obtain on **x86_64** if you hit edge issues on ARM.
- **User**: Use a sudo-capable account; avoid building or running Asterisk as root except for `make install` and system paths under `/usr/local` or `/etc/asterisk`.

## 2. Install build prerequisites (official script)

From your clone of this repository on the Ubuntu machine:

```bash
cd /path/to/asterisk
sudo ./contrib/scripts/install_prereq install
```

That pulls in compiler tooling, `libedit`, `jansson`, `uuid`, `libxml2`, `sqlite3`, `libssl`, `bzip2`, `patch`, and other dependencies used by a typical full build. If you prefer a **minimal** set first, install only what `configure` complains about, then re-run `install_prereq` as needed.

For **PJSIP bundled** (`--with-pjproject-bundled`), the script already includes `bzip2` and `patch` for unpacking and patching pjproject.

## 3. Build and install Asterisk

```bash
cd /path/to/asterisk
./bootstrap.sh
./configure --with-pjproject-bundled
make menuselect
```

In `menuselect`, enable at least:

- **Applications**: `app_audiosocket`
- **Channel drivers**: `chan_pjsip`, `chan_audiosocket`
- **Resource modules**: `res_pjsip`, `res_audiosocket`
- **Codecs**: `codec_ulaw`, `codec_alaw`, `codec_slin16`
- **Format modules**: `format_wav`, `format_pcm` (or as needed)

Then:

```bash
make -j"$(nproc)"
sudo make install
sudo make config
sudo make install-logrotate
```

Optional samples (overwrites `/etc/asterisk` sample configs):

```bash
sudo make samples
```

Install the **systemd** unit from upstream if you use it:

```bash
sudo cp contrib/systemd/asterisk.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now asterisk
```

Verify:

```bash
sudo asterisk -rx "core show version"
sudo asterisk -rx "module show like audiosocket"
```

## 4. Firewall (typical SIP + RTP)

Allow SSH first, then SIP and RTP (adjust RTP range to match `rtp.conf` and your provider):

```bash
sudo ufw allow OpenSSH
sudo ufw allow 5060/udp comment 'SIP'
sudo ufw allow 10000:20000/udp comment 'RTP media'
sudo ufw enable
sudo ufw status verbose
```

If you use **SIP over TLS**, add `5061/tcp`. Do **not** expose the voicebot AudioSocket port (e.g. `9092`) to the internet; keep it on `127.0.0.1` only.

## 5. Moving from another machine (e.g. embedded Linux)

1. **Source tree**: `git clone` the same Asterisk revision on Ubuntu, or `rsync` / archive the repo and rebuild on Ubuntu (clean `make` after `configure` is safest).
2. **Configuration**: Copy your custom files from the old host, e.g.  
   `pjsip.conf`, `extensions.conf`, `rtp.conf`, `modules.conf` under `/etc/asterisk/`, and merge with any new samples you need.
3. **Secrets**: Re-enter SIP credentials; do not commit real passwords to git.
4. **Voicebot**: Install `~/workspace/voicebot` (or your layout) on the same Ubuntu host so `AudioSocket(127.0.0.1:9092)` stays loopback-only, or point the dialplan at a **private** IP if the voicebot runs on another VM in the same VPC.

## 6. Ubuntu package Asterisk (not recommended for this project)

`apt install asterisk` is convenient but often **older** and may not match the modules you selected in source (e.g. AudioSocket). For the voicebot pipeline, **building from this tree** on Ubuntu is the supported path.

## 7. VoIP.ms trunk (DID)

If your number is from **VoIP.ms**, use the portal + PJSIP checklist in [voipms-asterisk.md](voipms-asterisk.md) (sub-account, PoP server, registration, firewall, NAT).

## References

- [Asterisk installation (official)](https://docs.asterisk.org/Getting-Started/Installing-Asterisk-From-Source/)
- [Important security considerations](https://docs.asterisk.org/Deployment/Important-Security-Considerations/)
- [AudioSocket](https://docs.asterisk.org/Configuration/Channel-Drivers/AudioSocket/)
