#!/usr/bin/env bash
#
# Sync this Asterisk source tree to a remote Ubuntu host (or pack a tarball).
# See docs/ubuntu-asterisk.md for build steps after the tree is on the server.
#
# Examples:
#   ./contrib/scripts/load-to-ubuntu.sh user@ubuntubox
#   ./contrib/scripts/load-to-ubuntu.sh --bootstrap user@ubuntubox
#   ./contrib/scripts/load-to-ubuntu.sh --identity ~/.ssh/id_ed25519 --bootstrap --configure user@ubuntubox
#   ./contrib/scripts/load-to-ubuntu.sh --tarball
#   ./contrib/scripts/load-to-ubuntu.sh --with-git user@ubuntubox ~/src/asterisk
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_NAME="$(basename "${REPO_ROOT}")"

IDENTITY_FILE=""
DO_TARBALL=0
DO_BOOTSTRAP=0
DO_CONFIGURE=0
DRY_RUN=0
INCLUDE_GIT=0

# Rsync -e string (must be one word or a quoted command line)
rsh_e_arg() {
	if [[ -n ${IDENTITY_FILE} ]]; then
		printf 'ssh -i %q -o ConnectTimeout=10 -o ServerAliveInterval=5' "${IDENTITY_FILE}"
	else
		printf 'ssh -o ConnectTimeout=10 -o ServerAliveInterval=5'
	fi
}
ssh_r() {
	if [[ -n ${IDENTITY_FILE} ]]; then
		ssh -i "${IDENTITY_FILE}" -o ConnectTimeout=10 -o ServerAliveInterval=5 "$@"
	else
		ssh -o ConnectTimeout=10 -o ServerAliveInterval=5 "$@"
	fi
}

usage() {
	cat <<'USAGE'
Sync this Asterisk tree to a remote Ubuntu host, or create a .tar.gz to copy manually.

Usage:
  load-to-ubuntu.sh [options] user@host [REMOTE_DIR]
  load-to-ubuntu.sh --tarball

  user@host     SSH target (Ubuntu 22.04/24.04; account needs sudo for --bootstrap)
  REMOTE_DIR    Destination on remote (default: ~/asterisk-src). Use abs path if in doubt.

Options:
  --tarball      Write /tmp/asterisk-ubuntu-*.tar.gz (or \$TMPDIR) so the archive is not inside the tree
  --with-git     Include .git in rsync or tarball (larger)
  --bootstrap    After rsync: sudo ./contrib/scripts/install_prereq install
  --configure    After that: ./bootstrap.sh && ./configure --with-pjproject-bundled
                 You still need: make menuselect && make (see docs/ubuntu-asterisk.md)
  --identity F   Use this private key for ssh and rsync
  --dry-run      rsync -n; print remote steps; do not mkdir or run remote build
  -h, --help     This help
USAGE
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--tarball) DO_TARBALL=1; shift ;;
		--with-git) INCLUDE_GIT=1; shift ;;
		--bootstrap) DO_BOOTSTRAP=1; shift ;;
		--configure) DO_CONFIGURE=1; shift ;;
		--dry-run) DRY_RUN=1; shift ;;
		--identity)
			[[ $# -ge 2 ]] || { echo "missing path for --identity" >&2; exit 1; }
			IDENTITY_FILE="$2"
			[[ -f "${IDENTITY_FILE}" ]] || { echo "not a file: ${IDENTITY_FILE}" >&2; exit 1; }
			shift 2
			;;
		-h|--help) usage; exit 0 ;;
		-*) echo "unknown option: $1" >&2; usage; exit 1 ;;
		*) break ;;
	esac
done

if [[ ${DO_TARBALL} -eq 1 ]]; then
	if [[ $# -ne 0 ]]; then
		echo "error: --tarball does not take user@host" >&2
		exit 1
	fi
	out="${TMPDIR:-/tmp}/asterisk-ubuntu-$(date +%Y%m%d-%H%M%S).tar.gz"
	echo "Creating ${out} from ${REPO_ROOT}"
	TAR_EX=(--exclude="${REPO_NAME}/core/build" --exclude="${REPO_NAME}/.DS_Store")
	[[ ${INCLUDE_GIT} -eq 0 ]] && TAR_EX+=(--exclude="${REPO_NAME}/.git")
	tar -C "${REPO_ROOT}/.." "${TAR_EX[@]}" -czf "${out}" "${REPO_NAME}"
	echo "Wrote: ${out}"
	bn="$(basename "${out}")"
	echo "On remote host: scp ${out} user@server: && ssh user@server 'tar xzf ${bn} && cd ${REPO_NAME} && sudo ./contrib/scripts/install_prereq install && ./bootstrap.sh && ./configure --with-pjproject-bundled'"
	echo "To build and run in Docker (same tree): see docs/docker-asterisk.md"
	exit 0
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
	usage
	exit 1
fi

REMOTE="$1"
DEST_REMOTE="${2:-~/asterisk-src}"
RSH_E="$(rsh_e_arg)"
RSYNC_RSH=(-e "${RSH_E}")

RSYNC_EXCLUDES=(--exclude 'core/build' --exclude '.DS_Store')
[[ ${INCLUDE_GIT} -eq 0 ]] && RSYNC_EXCLUDES+=(--exclude '.git')
RSYNC_FLAGS=(-az --delete "${RSYNC_EXCLUDES[@]}")
if [[ ${DRY_RUN} -eq 1 ]]; then
	RSYNC_FLAGS+=(-n)
fi

# Remote shell must see tilde unquoted for expansion (e.g. ~/asterisk-src). Avoid spaces in REMOTE_DIR.
run_remote() {
	local cmd=$1
	if [[ ${DRY_RUN} -eq 1 ]]; then
		echo "DRY: ssh -t ${REMOTE} cd ${DEST_REMOTE} '&&' ${cmd}"
		return 0
	fi
	# shellcheck disable=SC2029
	ssh_r -t "${REMOTE}" "cd ${DEST_REMOTE} && ${cmd}"
}

echo "Rsync: ${REPO_ROOT}/ -> ${REMOTE}:${DEST_REMOTE}/"
if [[ ${DRY_RUN} -eq 0 ]]; then
	ssh_r "${REMOTE}" "mkdir -p ${DEST_REMOTE}"
else
	echo "DRY: ssh ${REMOTE} mkdir -p ${DEST_REMOTE}"
fi
rsync "${RSYNC_RSH[@]}" "${RSYNC_FLAGS[@]}" "${REPO_ROOT}/" "${REMOTE}:${DEST_REMOTE}/"

if [[ ${DO_BOOTSTRAP} -eq 0 && ${DO_CONFIGURE} -eq 0 ]]; then
	echo "Done. On the server: cd ${DEST_REMOTE} && see ${REPO_ROOT}/docs/ubuntu-asterisk.md"
	exit 0
fi

if [[ ${DO_BOOTSTRAP} -eq 1 ]]; then
	echo "Running install_prereq on ${REMOTE} (sudo)..."
	run_remote "sudo ./contrib/scripts/install_prereq install"
fi

if [[ ${DO_CONFIGURE} -eq 1 ]]; then
	if [[ ${DO_BOOTSTRAP} -eq 0 ]]; then
		echo "warning: --configure without --bootstrap; ensure build deps are installed" >&2
	fi
	echo "Running bootstrap and configure on ${REMOTE}..."
	run_remote "./bootstrap.sh && ./configure --with-pjproject-bundled"
fi

cat <<EOF

Next on ${REMOTE}:
  cd ${DEST_REMOTE}
  make menuselect    # enable app_audiosocket, chan_pjsip, chan_audiosocket, res_audiosocket, ...
  make -j\$(nproc) && sudo make install && sudo make config
  sudo cp contrib/systemd/asterisk.service /etc/systemd/system/  # optional
  sudo systemctl enable --now asterisk

See ${REPO_ROOT}/docs/ubuntu-asterisk.md
EOF
