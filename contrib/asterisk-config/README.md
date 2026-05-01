# Optional Asterisk snippets for this checkout

- **`voipms.local.conf.example`** — template for VoIP.ms PJSIP (placeholders; safe to commit).
- **`voipms.local.conf`** — real credentials, **gitignored**; copy to the server with restrictive permissions.
- For portal steps and concepts, see [docs/voipms-asterisk.md](../../docs/voipms-asterisk.md).

Install (Ubuntu / typical layout):

```bash
# Example: pjsip.conf should include: #include pjsip.d/*.conf
sudo install -m 600 -o root -g root /path/to/voipms.local.conf /etc/asterisk/pjsip.d/50-voipms.conf
sudo asterisk -rx "pjsip reload"
sudo asterisk -rx "pjsip show registrations"
```

Ensure a `[from-voipms]` (or your chosen) context exists in `extensions.conf` and matches the endpoint `context=`.
