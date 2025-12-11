#!/bin/bash
set -e

# Precompile Explorer NIF binaries with glibc 2.28 compatibility (CentOS 8)
# This script builds the binaries inside a CentOS Stream 8 Docker container

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="explorer-centos8-builder"
PRECOMPILED_DIR="$PROJECT_ROOT/precompiled"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Explorer glibc 2.28 Precompilation${NC}"
echo -e "${BLUE}========================================${NC}"

# Ensure precompiled directory exists
mkdir -p "$PRECOMPILED_DIR"

# Build the Docker image for x86_64 platform
echo -e "\n${YELLOW}Building Docker image for x86_64 platform...${NC}"
docker build --platform linux/amd64 -t "$IMAGE_NAME" "$PROJECT_ROOT"

# Check if we should build both default and legacy variants
BUILD_LEGACY="${BUILD_LEGACY:-true}"

# Function to build a specific variant
build_variant() {
    local variant=$1
    local rustflags=$2

    echo -e "\n${GREEN}Building variant: ${variant}${NC}"

    # Run the build inside the container (x86_64 platform)
    # Use less parallelism to avoid segfaults in emulation
    docker run --rm \
        --platform linux/amd64 \
        -v "$PROJECT_ROOT:/build" \
        -v "explorer-cargo-cache:/root/.cargo/registry" \
        -v "explorer-cargo-git:/root/.cargo/git" \
        -v "explorer-target-cache:/build/native/explorer/target" \
        -e EXPLORER_BUILD=1 \
        -e MIX_ENV=prod \
        -e RUSTFLAGS="$rustflags" \
        -e CARGO_BUILD_JOBS=2 \
        -e LC_ALL=C.UTF-8 \
        -e LANG=C.UTF-8 \
        -e ELIXIR_ERL_OPTIONS="+fnu" \
        -w /build \
        "$IMAGE_NAME" \
        bash -c "
            set -e
            echo 'Installing dependencies...'
            mix deps.get

            echo 'Compiling Elixir...'
            mix compile

            echo 'Building Rust NIF...'
            cd native/explorer
            cargo build --release
            cd ../..

            echo 'Packaging binary...'
            VERSION=\$(grep '@version' mix.exs | head -n1 | cut -d'\"' -f2)
            TARGET='x86_64-unknown-linux-gnu'
            NIF_VERSION='2.15'

            if [ '$variant' = 'legacy_cpu' ]; then
                BINARY_NAME=\"libexplorer-v\${VERSION}-nif-\${NIF_VERSION}-\${TARGET}-legacy_cpu.so\"
                TAR_NAME=\"libexplorer-v\${VERSION}-nif-\${NIF_VERSION}-\${TARGET}-legacy_cpu.so.tar.gz\"
            else
                BINARY_NAME=\"libexplorer-v\${VERSION}-nif-\${NIF_VERSION}-\${TARGET}.so\"
                TAR_NAME=\"libexplorer-v\${VERSION}-nif-\${NIF_VERSION}-\${TARGET}.so.tar.gz\"
            fi

            # Find the compiled .so file
            SO_FILE=\$(find native/explorer/target/release -name 'libexplorer.so' -type f | head -n 1)

            if [ -z \"\$SO_FILE\" ]; then
                echo 'Error: Could not find compiled .so file'
                exit 1
            fi

            # Copy and create tarball
            cp \"\$SO_FILE\" \"/build/precompiled/\$BINARY_NAME\"
            cd /build/precompiled
            tar -czf \"\$TAR_NAME\" \"\$BINARY_NAME\"
            rm \"\$BINARY_NAME\"

            echo \"Binary created: \$TAR_NAME\"

            # Generate checksum
            sha256sum \"\$TAR_NAME\" > \"\$TAR_NAME.sha256\"
            echo \"Checksum created: \$TAR_NAME.sha256\"
        "
}

# Build default variant (with modern CPU features)
# Using x86-64 baseline which is compatible with glibc 2.28
echo -e "\n${GREEN}Building default variant...${NC}"
build_variant "default" "-C target-cpu=x86-64 -C target-feature=+sse,+sse2,+sse3,+ssse3,+sse4.1,+sse4.2"

# Build legacy variant (without modern CPU features)
if [ "$BUILD_LEGACY" = "true" ]; then
    echo -e "\n${GREEN}Building legacy CPU variant...${NC}"
    build_variant "legacy_cpu" "-C target-cpu=x86-64"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Build complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nPrecompiled binaries are in: ${BLUE}$PRECOMPILED_DIR${NC}"
echo -e "\nFiles created:"
ls -lh "$PRECOMPILED_DIR"

echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "1. Upload the .tar.gz files to your binary storage (S3, GitHub releases, etc.)"
echo -e "2. Update lib/explorer/polars_backend/native.ex with the new base_url"
echo -e "3. Generate checksums: mix rustler_precompiled.download Explorer.PolarsBackend.Native --all --print"
echo -e "4. Update the checksum file in your project"
