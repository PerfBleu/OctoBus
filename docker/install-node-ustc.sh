#!/bin/sh
# Official Node.js binary tarball.
#
# USTC's nodejs-release tree is currently empty/unavailable (404). Default base
# URL is Tsinghua; npmmirror layout is also supported via NODE_DIST_BASE.
#
# Under buildx QEMU, any "#!/usr/bin/env node" script (npm, tsc, package bins)
# makes Node report "Security violation: Requested utility env does not match
# executable name". npm/npx/corepack are wrapped, and /usr/bin/env is replaced
# so a node shebang execs /usr/local/bin/node directly.
set -eu

NODE_VERSION="${NODE_VERSION:?NODE_VERSION is required}"
NODE_DIST_BASE="${NODE_DIST_BASE:-https://mirrors.tuna.tsinghua.edu.cn/nodejs-release}"

arch="$(dpkg --print-architecture)"
case "$arch" in
amd64) node_arch=x64 ;;
arm64) node_arch=arm64 ;;
armhf) node_arch=armv7l ;;
*)
	echo "unsupported dpkg architecture: $arch" >&2
	exit 1
	;;
esac

ver="v${NODE_VERSION}"
file="node-${ver}-linux-${node_arch}.tar.xz"
base="${NODE_DIST_BASE%/}"
url="${base}/${ver}/${file}"

printf '\n[node %s] download %s\n' "$(date -u +%H:%M:%S)" "$url"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# -L follows npmmirror redirects; -# prints a progress bar without a TTY.
curl -fSL# "$url" -o "${tmpdir}/node.tar.xz"
printf '\n[node %s] extract to /usr/local\n' "$(date -u +%H:%M:%S)"
tar -xJf "${tmpdir}/node.tar.xz" -C /usr/local --strip-components=1

install_node_wrapper() {
	name="$1"
	target="$2"
	if [ ! -f "$target" ]; then
		echo "missing node entrypoint $target" >&2
		exit 1
	fi
	rm -f "/usr/local/bin/$name"
	cat >"/usr/local/bin/$name" <<EOF
#!/bin/sh
exec /usr/local/bin/node ${target} "\$@"
EOF
	chmod 755 "/usr/local/bin/$name"
}

install_node_wrapper npm /usr/local/lib/node_modules/npm/bin/npm-cli.js
install_node_wrapper npx /usr/local/lib/node_modules/npm/bin/npx-cli.js
if [ -f /usr/local/lib/node_modules/corepack/dist/corepack.js ]; then
	install_node_wrapper corepack /usr/local/lib/node_modules/corepack/dist/corepack.js
fi

if [ ! -e /usr/bin/env.real ]; then
	mv /usr/bin/env /usr/bin/env.real
fi
cat >/usr/bin/env <<'EOF'
#!/bin/sh
if [ "${1:-}" = "node" ] || [ "${1:-}" = "nodejs" ]; then
	shift
	exec /usr/local/bin/node "$@"
fi
exec /usr/bin/env.real "$@"
EOF
chmod 755 /usr/bin/env

node --version
npm --version
