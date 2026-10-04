# virtiofsd-static

Static builds of [virtiofsd](https://gitlab.com/virtio-fs/virtiofsd), the
vhost-user daemon that shares a host directory with a virtual machine over
virtio-fs, for x86_64 and aarch64 Linux.

virtiofsd publishes no release binaries, and not every distribution packages
it: Debian 12 and Ubuntu 22.04 do not, and their QEMU's own
`/usr/lib/qemu/virtiofsd` is the older C virtiofsd, with other options. These
builds have no dependencies on the host's libraries, so one binary runs on any
Linux distribution of its architecture.

## Using it

Download it from the latest
[release](https://github.com/konradasb/virtiofsd-static/releases/latest), and
check it against the release's `SHA256SUMS`:

```console
$ curl -fsSLO https://github.com/konradasb/virtiofsd-static/releases/download/v1.14.0-1/virtiofsd-x86_64
$ curl -fsSLO https://github.com/konradasb/virtiofsd-static/releases/download/v1.14.0-1/SHA256SUMS
$ sha256sum --check --ignore-missing SHA256SUMS
$ sudo install -m 755 virtiofsd-x86_64 /usr/local/bin/virtiofsd
```

On arm64, use `virtiofsd-aarch64`.

## What it is

- **Source:** the [crates.io](https://crates.io/crates/virtiofsd) release in
  [`virtiofsd.env`](virtiofsd.env), checked against its SHA-256, and built
  with its own `Cargo.lock`.
- **Build:** `cargo build --release --locked` for the architecture's
  `-unknown-linux-musl` target, with virtiofsd's default features, in the
  Rust on Alpine image `virtiofsd.env` pins, linking musl, libcap-ng and
  libseccomp statically. The build fails if the binary is not static.

Each release carries the binaries, the crate they were built from,
virtiofsd's licences, and `SHA256SUMS`, signed with cosign by the release
workflow.

## Verifying a release

```console
cosign verify-blob SHA256SUMS \
  --bundle SHA256SUMS.sigstore.json \
  --certificate-identity https://github.com/konradasb/virtiofsd-static/.github/workflows/build.yaml@refs/tags/v1.14.0-1 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
sha256sum --check --ignore-missing SHA256SUMS
```

## Building

With Docker, for the machine's own architecture:

```console
./build.sh x86_64 out   # or aarch64
```

## Releasing

A release is tagged `v<virtiofsd version>-<build>`: `v1.14.0-1`, then
`v1.14.0-2` for a new build of the same virtiofsd, such as a newer Rust image.

1. Update `virtiofsd.env` to the new virtiofsd release and its crate's
   SHA-256, the `checksum` in
   `https://crates.io/api/v1/crates/virtiofsd/<version>`, or update the Rust
   image and its digest.
2. Merge it once CI has built both architectures.
3. Tag `main` and push the tag. The workflow builds, signs and publishes the
   release.

## Licence

The scripts and workflow here are MIT licensed; see [LICENSE](LICENSE).
virtiofsd is Apache-2.0 and BSD-3-Clause, as the licences attached to each
release say.
