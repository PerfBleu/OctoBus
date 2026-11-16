#!/bin/sh
# Run npm with phases visible in plain BuildKit logs.
set -eu

prefix="${1:?npm prefix (directory) is required}"
shift

log() {
	printf '\n[npm %s | %s] %s\n' "$(date -u +%H:%M:%S)" "$prefix" "$*"
}

if [ "$#" -eq 0 ]; then
	echo "usage: npm-with-progress.sh <prefix> <npm-args...>" >&2
	exit 2
fi

log "npm $*"
npm --prefix "$prefix" "$@"
log "done"
