#!/usr/bin/env bash
# Build-time only: import services/ into an OctoBus data directory for offline images.
set -euo pipefail

octobus="${1:?octobus binary path required}"
services_root="${2:?services root path required}"
data_dir="${3:?data dir path required}"
addr="${4:-127.0.0.1:19001}"
bootstrap_token="${OCTOBUS_OFFLINE_BAKE_ADMIN_TOKEN:-octobus-offline-bake-token}"

mkdir -p "$data_dir"
chmod 700 "$data_dir"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

export OCTOBUS_BOOTSTRAP_ADMIN_TOKEN="$bootstrap_token"
"$octobus" serve --data-dir "$data_dir" --addr "$addr" >>"$log" 2>&1 &
daemon_pid=$!
trap 'kill "$daemon_pid" 2>/dev/null || true; wait "$daemon_pid" 2>/dev/null || true; rm -f "$log"' EXIT

deadline=$((SECONDS + 300))
until OCTOBUS_ADMIN_TOKEN="$bootstrap_token" "$octobus" --addr "$addr" service list >/dev/null 2>&1; do
	if ! kill -0 "$daemon_pid" 2>/dev/null; then
		cat "$log" >&2
		exit 1
	fi
	if (( SECONDS >= deadline )); then
		cat "$log" >&2
		echo "daemon did not become ready at $addr" >&2
		exit 1
	fi
	sleep 0.5
done

echo "importing tentacles from $services_root (offline)..." >&2
OCTOBUS_ADMIN_TOKEN="$bootstrap_token" \
	"$octobus" --addr "$addr" \
	service import --recursive --offline --build auto "$services_root"

count="$(sqlite3 "$data_dir/octobus.db" 'SELECT COUNT(*) FROM services;')"
echo "imported $count services" >&2

kill "$daemon_pid" 2>/dev/null || true
wait "$daemon_pid" 2>/dev/null || true
trap - EXIT
rm -f "$log"

db="$data_dir/octobus.db"
if [[ ! -f "$db" ]]; then
	echo "missing $db after import" >&2
	exit 1
fi

# Do not ship build-time admin credentials in the image seed.
sqlite3 "$db" 'DELETE FROM admin_tokens;'

# Drop staging trees left by import; committed artifacts remain under artifacts/.
rm -rf "$data_dir/artifacts/services/"staging-* 2>/dev/null || true
