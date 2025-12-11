# Precompiled Binaries - glibc 2.28 Compatible

This directory contains pre-compiled NIF (Native Implemented Function) binaries for the `x86_64-unknown-linux-gnu` target, compiled with glibc 2.28 compatibility for CentOS 8.

## What's Different

This fork ONLY replaces the pre-compiled binaries for:
- `x86_64-unknown-linux-gnu` (default variant)
- `x86_64-unknown-linux-gnu-legacy_cpu` (legacy CPU variant)

All other platform binaries are downloaded from the upstream Explorer repository.

## File Names

The binaries in this directory follow the standard Explorer naming convention:

```
libexplorer-v{VERSION}-nif-2.15-x86_64-unknown-linux-gnu.so.tar.gz
libexplorer-v{VERSION}-nif-2.15-x86_64-unknown-linux-gnu-legacy_cpu.so.tar.gz
```

## Rebuilding Binaries

To rebuild the precompiled binaries:

```bash
./scripts/prebuild.sh
```

This builds both variants inside a CentOS Stream 8 Docker container with glibc 2.28.

## Checksums

Each binary has an accompanying `.sha256` file for integrity verification.
