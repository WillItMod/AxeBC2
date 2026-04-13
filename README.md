# AxeBC2 Release (public)

## License (READ THIS FIRST)

This repository is source-available under the **Business Source License 1.1
(BSL 1.1)**. It is **NOT** an open source repository.

- No resale / no redistributed packages or release bundles without a commercial
  license: [COMMERCIAL_LICENSE.md](COMMERCIAL_LICENSE.md)
- No public forks, mirrors, or derivative redistributions without explicit
  written permission: [NO_FORK_POLICY.md](NO_FORK_POLICY.md)
- License: [LICENSE](LICENSE)
- Branding: [TRADEMARK.md](TRADEMARK.md)

This repo contains the **public** app recipe files for AxeBC2 (built for 5tratumOS and compatible self-hosted app platforms).

It must **not** contain any application source code.

The private build repo publishes the UI image to GHCR; the recipe points at that image and at the node/pool images.

## Current status

- Current dev-store package version: `0.1.6-dev`
- Public repo package path here: `willitmod-dev-btc2/`
- Mirrored dev-store package: `WillItMod/umbrel-dev-community-store/willitmod-dev-bc2`
- Miner endpoint: `stratum+tcp://<host-ip>:2345`
- For the cross-project version matrix and release/changelog pointers, see `https://github.com/WillItMod/AxeSuite/blob/main/docs/releases.md`.
- BitcoinII Core (BC2) is bundled as a simple multi-arch Docker build in `willitmod-dev-btc2/data/bitcoiniid`.
