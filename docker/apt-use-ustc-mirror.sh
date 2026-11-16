#!/bin/sh
# Point apt at USTC over HTTP so apt-get update works before ca-certificates
# is installed (HTTPS mirrors fail with certificate verify errors in minimal
# images and under buildx/QEMU).
set -eu

for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list; do
	[ -f "$f" ] || continue
	sed -i \
		-e 's|http://archive.ubuntu.com/ubuntu|http://mirrors.ustc.edu.cn/ubuntu|g' \
		-e 's|https://archive.ubuntu.com/ubuntu|http://mirrors.ustc.edu.cn/ubuntu|g' \
		-e 's|http://security.ubuntu.com/ubuntu|http://mirrors.ustc.edu.cn/ubuntu|g' \
		-e 's|https://security.ubuntu.com/ubuntu|http://mirrors.ustc.edu.cn/ubuntu|g' \
		-e 's|http://ports.ubuntu.com/ubuntu-ports|http://mirrors.ustc.edu.cn/ubuntu-ports|g' \
		-e 's|https://ports.ubuntu.com/ubuntu-ports|http://mirrors.ustc.edu.cn/ubuntu-ports|g' \
		-e 's|https://mirrors.ustc.edu.cn/ubuntu|http://mirrors.ustc.edu.cn/ubuntu|g' \
		-e 's|https://mirrors.ustc.edu.cn/ubuntu-ports|http://mirrors.ustc.edu.cn/ubuntu-ports|g' \
		"$f"
done
