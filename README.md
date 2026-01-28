# AxeBC2 Release (public)

This repo contains the **public** app recipe files for AxeBC2 (built for 5tratumOS and compatible self-hosted app platforms).

It must **not** contain any application source code.

The private build repo publishes the UI image to GHCR; the recipe points at that image and at the node/pool images.

## Current status

- AxeBC2 is distributed via this repo's recipe files (not mirrored into any community store).
- BitcoinII Core (BC2) is bundled as a simple multi-arch Docker build in `willitmod-dev-btc2/data/bitcoiniid`.
