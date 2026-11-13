# Docker Image

The OctoBus image is built from `ubuntu:26.04` and packages a prebuilt
`octobus` binary plus the runtime tools used by service package workflows:

- `node` and `npm` for JavaScript service packages
- `protoc` for descriptor compilation during service import
- `git` for HTTPS Git service sources
- `ca-certificates` and `curl` for TLS access and container health checks

The image does not compile anything. Build the binary for the target platform
first and put it in `dist/` in the build context — CI cross-compiles both
platforms this way, which keeps arm64 builds off QEMU:

```bash
mkdir -p dist
GOOS=linux GOARCH=amd64 bash ./scripts/build-octobus.sh dist/octobus-linux-amd64
GOOS=linux GOARCH=arm64 bash ./scripts/build-octobus.sh dist/octobus-linux-arm64
docker build -f docker/Dockerfile -t octobus:dev .
```

`docker build` selects the binary matching `TARGETARCH`, so on an arm64 host
omit the amd64 line (and vice versa) if you only need the local architecture.

Run the daemon:

```bash
docker run --rm \
  -p 9000:9000 \
  -e OCTOBUS_BOOTSTRAP_ADMIN_TOKEN=... \
  -v octobus-data:/var/lib/octobus \
  octobus:dev
```

The image listens on `0.0.0.0:9000` by default, so do not pass `serve --dev`
with a published port: `--dev` only starts on a loopback address. Local
development on the host should use `octobus serve --dev` instead.

Do not reuse a data volume that was first started with `--dev`. That writes
the well-known development token into the store; later starts print a warning
and `OCTOBUS_BOOTSTRAP_ADMIN_TOKEN` will not replace it. A leftover
development token is refused on a non-loopback listen address. Use a fresh
volume for production. Do not bake a default token into the image.

When using a host bind mount instead of a named volume, make sure the mounted
directory is owned by the non-root `octobus` user. The UID and GID are image
details, so query them from the exact image you are going to run and apply them
to the host directory:

```bash
mkdir -p ./octobus-data
docker run --rm --entrypoint id octobus:dev -u octobus
docker run --rm --entrypoint id octobus:dev -g octobus
sudo chown -R <uid>:<gid> ./octobus-data
docker run --rm -p 9000:9000 \
  -v "$PWD/octobus-data:/var/lib/octobus" \
  octobus:dev
```

The image defaults to:

```text
OCTOBUS_ADDR=0.0.0.0:9000
OCTOBUS_DATA_DIR=/var/lib/octobus
```

Run CLI commands against the daemon with another container on the same network,
or from the host through the published port:

```bash
docker run --rm --network host octobus:dev status --addr 127.0.0.1:9000
```

For a complete local validation flow that builds the image, starts the daemon,
imports a calculator service fixture using the local SDK package, creates an
instance and capset, then invokes the service through Connect RPC:

```bash
docker/smoke.sh octobus:dev
```

The smoke script compiles the binary for the Docker daemon's architecture
itself, so no manual build step is needed for it.

## Offline image (`Dockerfile.offline`)

`docker/Dockerfile.offline` bakes the whole `services/` tentacles tree into the
image at build time. The builder stage runs `npm install` in `services/` and
`octobus service import --recursive --offline --build auto`, then copies the
resulting registry and artifacts into `/var/lib/octobus` in the runtime image.
No network access is required to **import** those services after the image is
built; you still need `node` at **runtime** to start instances.

Build:

```bash
mkdir -p dist
GOOS=linux GOARCH=amd64 bash ./scripts/build-octobus.sh dist/octobus-linux-amd64
docker build -f docker/Dockerfile.offline -t octobus:offline .
```

The build needs network access to download npm packages and compile descriptors.
`Dockerfile.offline` defaults to the `npmmirror.com` npm registry
(`https://registry.npmmirror.com`); override with
`docker build --build-arg NPM_REGISTRY=https://registry.npmjs.org ...`.
The image is large (all service runtimes and shared `node_modules` trees).

Run on first start with an admin bootstrap token (the baked data directory does
not contain admin tokens):

```bash
docker run --rm \
  -p 9000:9000 \
  -e OCTOBUS_BOOTSTRAP_ADMIN_TOKEN=... \
  -v octobus-offline-data:/var/lib/octobus \
  octobus:offline
```

List pre-imported services without further import:

```bash
docker run --rm \
  -e OCTOBUS_ADMIN_TOKEN=... \
  --network host \
  octobus:offline service list --addr 127.0.0.1:9000
```

Use a named volume or ensure the host bind mount is empty on first run so Docker
copies the baked `/var/lib/octobus` content into the volume. Creating instances
and capsets still requires admin API access; only `service import` is skipped.
