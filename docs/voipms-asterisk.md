# VoIP.ms + Asterisk (PJSIP) — what you need and how to configure

This is a **checklist and template** for a VoIP.ms DID (number) and sub-account, connecting to this Asterisk tree. Official VoIP.ms examples may differ by Asterisk version; if something fails, align with the current wiki: [Asterisk PJSIP (VoIP.ms)](https://wiki.voip.ms/article/Asterisk_PJSIP).

## 1. On your VoIP.ms account (customer portal)

### Sub-account (required)

- **Sub-Account** is what Asterisk will register. Do **not** use the main “customer” login for SIP; create a sub-account.
- In **Sub-Accounts » Create Sub-Account** (or **Manage Sub-Accounts**), set at least:
  - **Device type** — choose something like *Asterisk, IP PBX, Gateway* (wording in the portal may vary), not a “hard phone” if that’s still offered.
  - **Username** — usually of the form `MAINACCOUNT_something` (e.g. `100000_abc`). You will use this as the PJSIP **SIP user**.
  - **Password** — strong secret; you will use it in PJSIP `auth`.
  - **Point of presence (PoP) / server** — pick a host near you (e.g. `chicago1.voip.ms`, `toronto2.voip.ms`). **Use the same host you put in `pjsip.conf`** in `client_uri` / `server_uri` and `from_domain` (see below). If inbound fails, a common problem is a mismatch between the server you register to and the server your DID is homed to—VoIP.ms documents this under **DID** and **Servers** in their wiki.

### DID (your new number)

- In **DID Number » Manage** (or “Route / Mapping”), set the DID to the **sub-account** you created (route inbound calls to that sub-account, not a random trunk name).
- If the portal has **E911 / Caller ID** for the DID, complete what your region requires; not required for basic SIP to Asterisk, but some routes enforce it for outbound.
- For **inbound to Asterisk** to work, your sub-account must be **successfully registered** to VoIP.ms (Asterisk must show a valid registration) unless you are using a special IP-based setup (uncommon for a home/small server).

### Codecs (recommended to match this project)

- Prefer **G.711 µ-law (ulaw)** and **G.711 A-law (alaw)** on both VoIP.ms and Asterisk, so the media path is predictable (good for the AudioSocket / voicebot pipeline in [asterisk-voicebot-pipeline.md](asterisk-voicebot-pipeline.md)).
- Disable exotic codecs for that sub-account if the portal offers per-sub-account codec limits and you have dropouts (optional tuning).

### IP restriction (optional)

- If the portal can **restrict the sub-account to your public IP**, use it to reduce account scanning. You must use a **static** IP or re-open the rule when your ISP changes the address.

### Write down (you will need these on Asterisk)

| Item                | Where it comes from |
| ------------------ | -------------------- |
| Sub-account user   | e.g. `100000_mypbx`  |
| Sub-account secret | sub-account password |
| SIP server         | e.g. `chicago1.voip.ms` (your chosen PoP) |
| Port               | **5060** / UDP (TLS **5061** if you configure TLS) |

## 2. On the Ubuntu / Asterisk host

### Firewall (same as [ubuntu-asterisk.md](ubuntu-asterisk.md))

- Allow **UDP 5060** (SIP) and **RTP** (commonly a range, e.g. **10000–20000/udp**; match `rtp.conf` and VoIP.ms expectations).
- Do **not** open the internal voicebot AudioSocket port (e.g. 9092) to the public internet.

### NAT / public IP (if the server is behind a router or cloud SNAT)

- In `pjsip.conf`, set the correct **`external_signaling_address`** and **`external_media_address`** on the transport, or the equivalent in `pjsip.conf` / `rtp.conf` for your Asterisk version, to your **public** IP/hostname, and map RTP in your firewall. VoIP.ms must send RTP to an address:port you actually receive. See Asterisk: [PJSIP NAT and public IP](https://docs.asterisk.org/Configuration/Channel-Drivers/SIP/Configuring-res_pjsip/PJSIP-NAT-Settings/).

## 3. `pjsip.conf` example (placeholders)

Place **your** `USERNAME`, `SECRET`, and `VOIPMS_HOST` (e.g. `chicago1.voip.ms`). The section names (`voipms-…`) are arbitrary but must be consistent.

**Do not** commit real passwords; use `pjsip.d/` includes or a file not in git with permissions `600`.

```ini
; /etc/asterisk/pjsip.d/voipms.conf
;
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0
; If behind NAT, set your public address (uncomment and edit):
; external_media_address=203.0.113.7
; external_signaling_address=203.0.113.7
; local_net=192.168.0.0/16

; ---- VoIP.ms auth
[voipms-auth]
type=auth
auth_type=userpass
username=USERNAME
password=SECRET

; ---- Registration to VoIP.ms
[voipms-reg]
type=registration
transport=transport-udp
outbound_auth=voipms-auth
client_uri=sip:USERNAME@VOIPMS_HOST:5060
server_uri=sip:VOIPMS_HOST:5060
endpoint=voipms
; Required in current Asterisk if endpoint= is set (associates the registration with that endpoint)
line=yes
retry_interval=60
; Some providers behave better with shorter expiry; VoIP.ms users sometimes use 120–180:
expiration=120

; ---- AOR
[voipms-aor]
type=aor
max_contacts=1
remove_existing=yes
qualify_frequency=60

; ---- Endpoint: inbound and outbound to VoIP.ms
[voipms]
type=endpoint
transport=transport-udp
context=from-voipms
disallow=all
allow=ulaw,alaw
auth=voipms-auth
outbound_auth=voipms-auth
aors=voipms-aor
from_user=USERNAME
from_domain=VOIPMS_HOST
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
dtmf_mode=rfc4733
```

If your install wants **separate** `inbound` vs `outbound` auth in newer Asterisk, follow the [VoIP.ms wiki](https://wiki.voip.ms/article/Asterisk_PJSIP) exactly—they sometimes show `auth=…` and `outbound_auth=…` on different object names.

### `identify` (optional, if inbound doesn’t map to the endpoint)

If inbound calls are not associated with the right endpoint, you can add a match on VoIP.ms signaling addresses (or debug with `pjsip set logger on` and then match the source that sends INVITE). The wiki and forums often add something like:

```ini
[voipms-identify]
type=identify
endpoint=voipms
match=VOIPMS_HOST
```

(Exact `match` may need a subnet or the actual signaling IP; use logs if unsure.)

## 4. `extensions.conf` — receive the call

The **context** must be the same as the endpoint: `from-voipms` in the example.

```ini
[from-voipms]
; VoIP.ms often sends 10+ digits; match any (tune to your country format if needed)
exten => _X.,1,NoOp(Inbound from VoIP.ms DID, dialed ${EXTEN})
 same => n,Answer()
 same => n,Set(UUID=${SHELL(uuidgen | tr -d '\n')})
 same => n,AudioSocket(${UUID},127.0.0.1:9092)
 same => n,Hangup()
```

(Replace the `AudioSocket` line with a simpler `Playback` test until the voicebot is running: e.g. `Answer()` then `Playback(hello-world)` in `sounds/`.)

## 5. Reload and test

```bash
sudo asterisk -rx "pjsip reload"
sudo asterisk -rx "pjsip show registrations"
sudo asterisk -rx "pjsip show endpoint voipms"
```

You want **Registrations** to show **Registered** to VoIP.ms. Then from a cell phone, call your DID. On the Asterisk CLI, `core show channels` or `pjsip set logger on` to see INVITEs and RTP.

- **401 / 403 on register** — wrong `USERNAME`/`SECRET`, or wrong server; double-check the portal and PoP.
- **No audio** — codec mismatch (use ulaw/alaw), or NAT/RTP not forwarded; fix `external_*` and firewall RTP range.
- **Inbound not hitting context** — wrong `context=` on the endpoint, or routing in VoIP.ms still points elsewhere.
- **Busy or instant disconnect on inbound, registration OK** — the Request-URI user for the called DID is often E.164 with a leading `+` (e.g. `+1…`). A dialplan that only has `exten => _X.` (digits 0–9) does not match the `+`, so the call has no valid extension. Add `exten => _+X.,1,…` (and reload `dialplan`), or match your national format. Use `pjsip set logger on` and check the `INVITE` To / Request-URI to see the exact string.
- **PSTN call disconnects immediately, registration is Registered** — very often **NAT**: Asterisk advertises a **private** `Contact` (e.g. `sip:s@192.168.x.x:5060`). The provider may try to send the inbound `INVITE` to that address, so the call never reaches your host. In `pjsip.d/00-transport-udp.conf` (or an override fragment), set **`local_net`** to your LAN CIDR and **`external_signaling_address` / `external_media_address`** to your **public** IPv4. Reload PJSIP. Forward **UDP 5060** and your **RTP range** (e.g. 10000–20000) from the router to this machine. Re-test with `pjsip set logger on` and confirm you see an **`INVITE`** from the VoIP.ms SBC when you call the DID; if there is no `INVITE`, it is not a dialplan problem yet.

## 6. Docker (binding `pjsip.d` and `extensions.d`)

If you run Asterisk in Docker from this tree, credentials and your public IP are kept out of the repo entirely. Copy the env template, fill it in, then start:

```bash
cp docker/.env.example docker/.env   # set VOIPMS_USERNAME, VOIPMS_PASSWORD, VOIPMS_HOST, VOIPMS_NET, ASTERISK_PUBLIC_IP
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml exec asterisk /usr/sbin/asterisk -rx "pjsip show registrations"
```

The config files (`50-voipms.conf`, `00-transport-udp.conf`) use `${ENV(VARNAME)}` to read those values at startup — no credentials are stored in any file that could be committed. `docker/.env` is gitignored.

Details: [docker/asterisk-config/README.md](../docker/asterisk-config/README.md) and [docker-asterisk.md](docker-asterisk.md).

## 7. Files in this repo (optional)

- [docker/.env.example](../docker/.env.example) — **safe to commit**; placeholder values for all five env vars. Copy to `docker/.env` and fill in.
- `docker/.env` — **gitignored**; your real credentials and public IP. Never commit this.
- [contrib/asterisk-config/voipms.local.conf.example](../contrib/asterisk-config/voipms.local.conf.example) — PJSIP snippet with placeholders for a bare-metal (non-Docker) install.
- `contrib/asterisk-config/voipms.local.conf` — if present, **gitignored**; install as `/etc/asterisk/pjsip.d/50-voipms.conf` (mode `600`, root) for bare-metal.
- [contrib/asterisk-config/README.md](../contrib/asterisk-config/README.md) — bare-metal install one-liner.

## 8. What you have vs what’s left

| You have in VoIP.ms      | You still need on Asterisk |
| ------------------------- | --------------------------- |
| DID + sub-account         | `pjsip` auth + reg + endpoint + `extensions` context |
| Working registration      | Firewall + (if NAT) public IP in PJSIP/RTP        |
| Test call to DID          | Running Asterisk, optional voicebot on `127.0.0.1:9092` per your pipeline doc |

## References

- [VoIP.ms — Asterisk PJSIP](https://wiki.voip.ms/article/Asterisk_PJSIP)
- [VoIP.ms — Sub Accounts](https://wiki.voip.ms/article/Sub_Accounts)
- [VoIP.ms — Servers / PoP](https://wiki.voip.ms/article/Servers)
- [Asterisk — PJSIP](https://docs.asterisk.org/Configuration/Channel-Drivers/SIP/Configuring-res_pjsip/)
