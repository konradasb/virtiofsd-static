#!/usr/bin/env bash
# Copyright 2026 The virtiofsd-static Authors
# SPDX-License-Identifier: MIT
#
# Builds a static virtiofsd for one architecture: the crates.io release in
# virtiofsd.env, linked against musl, libcap-ng and libseccomp statically, in
# the Rust image virtiofsd.env pins.
#
#   ./build.sh x86_64|aarch64 OUT
#
# OUT receives the binary, virtiofsd-x86_64 or virtiofsd-aarch64. It needs only
# Docker, and builds natively: run it on a machine of the architecture it
# builds for.
set -euo pipefail

arch=${1:?usage: build.sh x86_64|aarch64 OUT}
out=${2:?usage: build.sh x86_64|aarch64 OUT}
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=virtiofsd.env
source "$here/virtiofsd.env"

case $arch in
x86_64) platform=linux/amd64 ;;
aarch64) platform=linux/arm64 ;;
*) echo "unknown architecture $arch: want x86_64 or aarch64" >&2; exit 1 ;;
esac

mkdir -p "$out"
out=$(cd "$out" && pwd)

# The crate is fetched and checked inside the container, so that the host
# needs nothing but Docker. The binary is handed back owned by the caller.
docker run --rm --platform "$platform" \
  -e VIRTIOFSD_VERSION="$VIRTIOFSD_VERSION" -e VIRTIOFSD_SHA256="$VIRTIOFSD_SHA256" -e ARCH="$arch" \
  -e OWNER="$(id -u):$(id -g)" \
  -v "$out:/out" \
  "$RUST_IMAGE" sh -euc '
    apk add --no-cache binutils libcap-ng-dev libcap-ng-static \
      libseccomp-dev libseccomp-static >/dev/null

    cd /tmp
    crate=virtiofsd-$VIRTIOFSD_VERSION.crate
    wget -q -O "$crate" "https://static.crates.io/crates/virtiofsd/$crate"
    echo "$VIRTIOFSD_SHA256  $crate" | sha256sum -c -s
    tar -xzf "$crate"
    cd "virtiofsd-$VIRTIOFSD_VERSION"

    # The crates find libseccomp and libcap-ng through these, and link them
    # statically when told to; musl itself is static by default.
    LIBSECCOMP_LINK_TYPE=static LIBSECCOMP_LIB_PATH=/usr/lib \
      LIBCAPNG_LINK_TYPE=static LIBCAPNG_LIB_PATH=/usr/lib \
      cargo build --release --locked --target "$ARCH-unknown-linux-musl"
    bin=target/$ARCH-unknown-linux-musl/release/virtiofsd

    # A binary with a program interpreter would need the host'"'"'s loader and
    # libraries, which is what this build exists to avoid.
    if readelf -l "$bin" | grep -q INTERP; then
      echo "$bin is not static" >&2
      exit 1
    fi
    "$bin" --version

    install -m 755 "$bin" "/out/virtiofsd-$ARCH"
    chown "$OWNER" "/out/virtiofsd-$ARCH"
  '
echo "built $out/virtiofsd-$arch"
