# Build from the repository root (context: ..):
#   docker build -f docker/Dockerfile -t asterisk-voice .
#
# Debian 12, install_prereq, PJSIP + AudioSocket + G.711.

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LD_LIBRARY_PATH=/usr/lib

# Do not delete /var/lib/apt/lists here: the next step runs install_prereq, which
# runs apt-get install aptitude without apt-get update, and that fails on a cold index.
RUN apt-get update && \
	apt-get install -y --no-install-recommends ca-certificates gettext-base sudo

WORKDIR /usr/src/asterisk
COPY . /usr/src/asterisk

RUN apt-get update && \
	chmod +x contrib/scripts/install_prereq && \
	./contrib/scripts/install_prereq install && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

RUN ./bootstrap.sh && \
	./configure --with-pjproject-bundled --prefix=/usr --sysconfdir=/etc

RUN chmod +x docker/menuselect-prep.sh && \
	./docker/menuselect-prep.sh

RUN make -j"$(nproc)" && \
	make install && \
	make config && \
	/usr/sbin/asterisk -V

RUN make samples

# VoIP.ms (and overlays): include pjsip.d + extensions.d, then copy fragments.
# pjsip.d templates are copied to pjsip.d.tpl/; the entrypoint renders them to pjsip.d/ at startup.
RUN chmod +x /usr/src/asterisk/docker/install-config-includes.sh && \
	/usr/src/asterisk/docker/install-config-includes.sh && \
	mkdir -p /etc/asterisk/pjsip.d.tpl && \
	cp -a /usr/src/asterisk/docker/asterisk-config/pjsip.d/. /etc/asterisk/pjsip.d.tpl/ && \
	cp -a /usr/src/asterisk/docker/asterisk-config/extensions.d/. /etc/asterisk/extensions.d/

EXPOSE 5060/udp
EXPOSE 10000-20000/udp

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Foreground. For SIP from outside Docker on Linux, use host networking (see docker-compose.yml).
CMD ["/usr/sbin/asterisk", "-f", "-T", "-p", "-vvv"]
