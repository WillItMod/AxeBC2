FROM debian:trixie-slim

ARG BITCOINII_TAG=v29.1.0
ARG BITCOINII_VERSION=29.1.0
ARG TARGETARCH

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends ca-certificates curl libstdc++6 tini; \
  rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  case "${TARGETARCH}" in \
    amd64) bc2_arch="x86_64-linux" ;; \
    arm64) bc2_arch="aarch64-linux" ;; \
    *) echo "Unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
  esac; \
  url="https://github.com/Bitcoin-II/BitcoinII-Core/releases/download/${BITCOINII_TAG}/BitcoinII-${BITCOINII_VERSION}-${bc2_arch}-CLI.tar.gz"; \
  echo "Downloading ${url}"; \
  curl -fsSL "${url}" -o /tmp/bitcoinii.tgz; \
  tar -xzf /tmp/bitcoinii.tgz -C /opt; \
  rm -f /tmp/bitcoinii.tgz; \
  ln -sf "/opt/BitcoinII-${BITCOINII_VERSION}-${bc2_arch}-CLI/bitcoinIId" /usr/local/bin/bitcoinIId; \
  ln -sf "/opt/BitcoinII-${BITCOINII_VERSION}-${bc2_arch}-CLI/bitcoinII-cli" /usr/local/bin/bitcoinII-cli

COPY bitcoinIId-wrapper.sh /usr/local/bin/bitcoinIId-wrapper.sh
RUN chmod 0755 /usr/local/bin/bitcoinIId-wrapper.sh

EXPOSE 8337 8338 28336

ENTRYPOINT ["tini", "--", "/usr/local/bin/bitcoinIId-wrapper.sh"]
CMD ["-datadir=/data", "-conf=/data/bitcoinII.conf"]
