#!/bin/sh
# Render environment variables into PJSIP config templates before Asterisk starts.
#
# Templates live in /etc/asterisk/pjsip.d.tpl/ (bind-mounted from docker/asterisk-config/pjsip.d/).
# Rendered configs are written to /etc/asterisk/pjsip.d/ (read by Asterisk).
#
# Only the listed variables are substituted; all other ${...} patterns (e.g. Asterisk
# dialplan variables in extensions.conf) are left untouched.
set -e

VARS='${VOIPMS_USERNAME} ${VOIPMS_PASSWORD} ${VOIPMS_HOST} ${VOIPMS_NET} ${ASTERISK_PUBLIC_IP}'

mkdir -p /etc/asterisk/pjsip.d

for tpl in /etc/asterisk/pjsip.d.tpl/*.conf; do
    [ -f "$tpl" ] || continue
    dest="/etc/asterisk/pjsip.d/$(basename "$tpl")"
    envsubst "$VARS" < "$tpl" > "$dest"
done

exec "$@"
