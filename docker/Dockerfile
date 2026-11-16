# The octobus binary is not compiled here. Compile it for the target platform
# first (scripts/build-octobus.sh, GOOS=linux GOARCH=<arch>) and put the result
# in dist/ in the build context — the image only packages it. Keeping the
# toolchain out of the image lets CI build linux/arm64 natively instead of
# running the whole toolchain under QEMU.
#
# syntax=docker/dockerfile:1.4
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive \
	OCTOBUS_ADDR=0.0.0.0:9000 \
	OCTOBUS_DATA_DIR=/var/lib/octobus

ARG NODE_VERSION=22.13.1
ARG NODE_DIST_BASE=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release
COPY docker/apt-use-ustc-mirror.sh /usr/local/bin/apt-use-ustc-mirror.sh
COPY docker/apt-bootstrap.sh /usr/local/bin/apt-bootstrap.sh
COPY docker/install-node-ustc.sh /usr/local/bin/install-node-ustc.sh
RUN chmod +x /usr/local/bin/apt-use-ustc-mirror.sh \
		/usr/local/bin/apt-bootstrap.sh \
		/usr/local/bin/install-node-ustc.sh

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked \
	/usr/local/bin/apt-bootstrap.sh \
		ca-certificates \
		curl \
		git \
		protobuf-compiler \
		libprotobuf-dev \
	&& rm -rf /var/lib/apt/lists/* \
	&& NODE_VERSION="${NODE_VERSION}" NODE_DIST_BASE="${NODE_DIST_BASE}" /usr/local/bin/install-node-ustc.sh \
	&& groupadd --system octobus \
	&& useradd --system --gid octobus --home-dir /var/lib/octobus --create-home --shell /usr/sbin/nologin octobus

ARG TARGETARCH
COPY dist/octobus-linux-${TARGETARCH} /usr/local/bin/octobus

USER octobus
WORKDIR /var/lib/octobus
VOLUME ["/var/lib/octobus"]
EXPOSE 9000

ENTRYPOINT ["octobus"]
CMD ["serve"]
