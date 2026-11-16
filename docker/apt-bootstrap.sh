#!/bin/sh
# Configure USTC apt mirror, run update/install with timestamped log lines.
# Pair with BuildKit apt cache mounts and `docker build --progress=plain`.
set -eu

log() {
	printf '\n[apt %s] %s\n' "$(date -u +%H:%M:%S)" "$*"
}

log "apply USTC mirror (HTTP)"
/usr/local/bin/apt-use-ustc-mirror.sh

log "apt-get update"
apt-get \
	-o Acquire::Retries=3 \
	-o Acquire::http::Timeout=120 \
	-o Acquire::https::Timeout=120 \
	update

if [ "$#" -eq 0 ]; then
	log "no packages to install"
	exit 0
fi

log "apt-get install: $*"
apt-get install -y --no-install-recommends "$@"
apt-get install -y xz-utils
log "apt-get install finished"
