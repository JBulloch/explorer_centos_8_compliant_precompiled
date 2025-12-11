# CentOS Stream 8 build environment for glibc 2.28 compatible binaries
FROM quay.io/centos/centos:stream8

# Fix CentOS Stream 8 repository URLs (mirrorlist.centos.org is deprecated)
RUN sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/CentOS-Stream-*.repo && \
    sed -i 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Stream-*.repo

# Install development tools and dependencies
RUN dnf update -y && \
    dnf groupinstall -y "Development Tools" && \
    dnf install -y \
    gcc \
    gcc-c++ \
    make \
    cmake \
    git \
    openssl-devel \
    ncurses-devel \
    wget \
    curl \
    tar \
    gzip \
    unzip && \
    dnf clean all

# Install Rust using rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain none
ENV PATH="/root/.cargo/bin:${PATH}"

# Install the specific Rust nightly version required by Explorer
RUN rustup toolchain install nightly-2025-06-23 --profile minimal --component rustfmt --component clippy && \
    rustup default nightly-2025-06-23

# Install Erlang 27.3.4 from source
RUN curl -fSL --retry 5 --retry-delay 5 -o otp_src_27.3.4.tar.gz https://github.com/erlang/otp/releases/download/OTP-27.3.4/otp_src_27.3.4.tar.gz && \
    tar -xzf otp_src_27.3.4.tar.gz && \
    cd otp_src_27.3.4 && \
    ./configure --without-javac && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf otp_src_27.3.4 otp_src_27.3.4.tar.gz

# Install Elixir 1.18.4-otp-27
RUN curl -fSL -o elixir-1.18.4.zip https://github.com/elixir-lang/elixir/archive/refs/tags/v1.18.4.zip && \
    unzip elixir-1.18.4.zip && \
    cd elixir-1.18.4 && \
    make clean && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf elixir-1.18.4 elixir-1.18.4.zip

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /build

# Copy the entire project
COPY . .

# Set environment variables for building
ENV EXPLORER_BUILD=1
ENV RUSTFLAGS="-C target-cpu=x86-64"
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV ELIXIR_ERL_OPTIONS="+fnu"
# Reduce parallel compilation to avoid segfaults in emulation
ENV MAKEFLAGS="-j2"

# Default command
CMD ["/bin/bash"]
