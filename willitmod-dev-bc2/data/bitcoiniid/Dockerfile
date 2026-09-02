FROM debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132 AS builder

ARG BITCOINII_TAG=v31.1.0
ARG BITCOINII_COMMIT=8daaf7b12e71d3646eed787f040bf2899a69dc1c
ARG DEBIAN_SNAPSHOT=20260830T000000Z

RUN set -eux; \
    printf '%s\n' \
      'Types: deb' \
      "URIs: http://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}/" \
      'Suites: trixie' \
      'Components: main' \
      'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg' \
      > /etc/apt/sources.list.d/debian.sources; \
    printf '%s\n' \
      'Types: deb' \
      "URIs: http://snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT}/" \
      'Suites: trixie-security' \
      'Components: main' \
      'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg' \
      > /etc/apt/sources.list.d/debian-security.sources; \
    printf 'Acquire::Check-Valid-Until "false";\nAcquire::Retries "3";\n' \
      > /etc/apt/apt.conf.d/99snapshot; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      git \
      libboost-dev \
      libevent-dev \
      libsqlite3-dev \
      libzmq3-dev \
      ninja-build \
      pkgconf \
      python3; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    git clone --depth 1 --branch "${BITCOINII_TAG}" \
      https://github.com/Bitcoin-II/BitcoinII-Core.git /src/bitcoinii; \
    test "$(git -C /src/bitcoinii rev-parse HEAD)" = "${BITCOINII_COMMIT}"; \
    cmake -S /src/bitcoinii -B /src/bitcoinii/build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_FLAGS_RELEASE="-O2 -g0 -DNDEBUG" \
      -DCMAKE_CXX_FLAGS_RELEASE="-O2 -g0 -DNDEBUG" \
      -DBUILD_BITCOINII_BIN=OFF \
      -DBUILD_CLI=ON \
      -DBUILD_DAEMON=ON \
      -DBUILD_GUI=OFF \
      -DBUILD_TESTS=OFF \
      -DBUILD_BENCH=OFF \
      -DBUILD_FUZZ_BINARY=OFF \
      -DENABLE_WALLET=ON \
      -DENABLE_IPC=OFF \
      -DENABLE_EXTERNAL_SIGNER=OFF \
      -DINSTALL_MAN=OFF \
      -DWITH_ZMQ=ON; \
    cmake --build /src/bitcoinii/build --parallel "$(nproc)" --target bitcoinII-d bitcoinII-cli; \
    install -Dm0755 /src/bitcoinii/build/bin/bitcoinII-d /out/bitcoinII-d; \
    install -Dm0755 /src/bitcoinii/build/bin/bitcoinII-cli /out/bitcoinII-cli

FROM debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132

ARG BITCOINII_VERSION=31.1.0
ARG DEBIAN_SNAPSHOT=20260830T000000Z

RUN set -eux; \
    printf '%s\n' \
      'Types: deb' \
      "URIs: http://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}/" \
      'Suites: trixie' \
      'Components: main' \
      'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg' \
      > /etc/apt/sources.list.d/debian.sources; \
    printf '%s\n' \
      'Types: deb' \
      "URIs: http://snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT}/" \
      'Suites: trixie-security' \
      'Components: main' \
      'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg' \
      > /etc/apt/sources.list.d/debian-security.sources; \
    printf 'Acquire::Check-Valid-Until "false";\nAcquire::Retries "3";\n' \
      > /etc/apt/apt.conf.d/99snapshot; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      jq \
      libevent-2.1-7t64 \
      libevent-extra-2.1-7t64 \
      libevent-pthreads-2.1-7t64 \
      libsqlite3-0 \
      libstdc++6 \
      libzmq5 \
      tini; \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/bitcoinII-d /usr/local/bin/bitcoinII-d
COPY --from=builder /out/bitcoinII-cli /usr/local/bin/bitcoinII-cli
COPY --from=builder /src/bitcoinii/COPYING /usr/share/doc/bitcoinii-core/COPYING
COPY --from=builder /src/bitcoinii/README.md /usr/share/doc/bitcoinii-core/README.md
COPY --from=builder /src/bitcoinii/src/pow.cpp /usr/share/doc/bitcoinii-core/src/pow.cpp
COPY bitcoinIId-wrapper.sh /usr/local/bin/bitcoinIId-wrapper.sh

RUN set -eux; \
    ln -s /usr/local/bin/bitcoinII-d /usr/local/bin/bitcoinIId; \
    chmod 0755 /usr/local/bin/bitcoinIId-wrapper.sh; \
    install -d -m 0755 -o 1000 -g 1000 /data; \
    test "$(bitcoinII-d --version | sed -n '1s/.*v\([0-9][0-9.]*\).*/\1/p')" = "${BITCOINII_VERSION}"; \
    bitcoinII-cli --version

LABEL org.opencontainers.image.source="https://github.com/WillItMod/AxeBC2" \
      org.opencontainers.image.version="31.1.0" \
      org.opencontainers.image.description="BitcoinII Core v31.1.0 node for AxeBC2"

ENV HOME=/data

WORKDIR /data

EXPOSE 8337 8338 28336

ENTRYPOINT ["tini", "--", "/usr/local/bin/bitcoinIId-wrapper.sh"]
CMD ["-datadir=/data", "-conf=/data/bitcoinII.conf"]
