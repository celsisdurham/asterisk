#!/bin/sh
# Used at image build time: wire sample pjsip.conf / extensions.conf to include *.d snippets.
set -e
PJSIP=/etc/asterisk/pjsip.conf
EXT=/etc/asterisk/extensions.conf

if [ -f "$PJSIP" ] && ! grep -q 'pjsip\.d' "$PJSIP" 2>/dev/null; then
	printf '\n; Added by docker/install-config-includes.sh\n#include "pjsip.d/*.conf"\n' >> "$PJSIP"
fi

if [ -f "$EXT" ] && ! grep -q 'extensions\.d' "$EXT" 2>/dev/null; then
	printf '\n; Added by docker/install-config-includes.sh\n#include "extensions.d/*.conf"\n' >> "$EXT"
fi

mkdir -p /etc/asterisk/pjsip.d /etc/asterisk/extensions.d
