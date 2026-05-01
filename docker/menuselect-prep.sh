#!/bin/sh
# Non-interactive menuselect for Docker image (PJSIP + AudioSocket + ulaw/alaw)
set -e
cd /usr/src/asterisk

make -j"$(nproc)" menuselect.makeopts

# Extended modules: AudioSocket
for m in app_audiosocket chan_audiosocket res_audiosocket; do
	./menuselect/menuselect --enable "$m" menuselect.makeopts
done

# PJSIP stack (load order: res before chan)
for m in res_pjsip chan_pjsip; do
	./menuselect/menuselect --enable "$m" menuselect.makeopts
done

# G.711 (AudioSocket and SIP trunks typically use slin/ulaw in the core path)
for m in codec_alaw codec_ulaw; do
	./menuselect/menuselect --enable "$m" menuselect.makeopts
done

./menuselect/menuselect --check-deps menuselect.makeopts
