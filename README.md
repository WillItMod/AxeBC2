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

- Current dev-store package version: `0.1.7-dev`
- Public repo package path here: `willitmod-dev-bc2/`
- Mirrored dev-store package: `WillItMod/umbrel-dev-community-store/willitmod-dev-bc2`
- Miner endpoint: `stratum+tcp://<host-ip>:2345`
- For the cross-project version matrix and release/changelog pointers, see `https://github.com/WillItMod/AxeSuite/blob/main/docs/releases.md`.
- BitcoinII Core (BC2) is consumed from the pinned GHCR image in the recipe.

## Staged BitcoinII Core 31 pipeline

The manual `Publish BitcoinII Core image` workflow stages the official
BitcoinII Core v31.1.0 source at upstream commit
`8daaf7b12e71d3646eed787f040bf2899a69dc1c`. Phase 1 deliberately leaves the
live app recipe on Core 29.1.0. A Core 31 candidate is built natively for
amd64 and arm64, smoke-tested by its exact architecture digest, combined into
a commit-bound candidate manifest, and checked for provenance, SBOM, and
anonymous public pull access. Production promotion retags that tested digest
without rebuilding it and refuses to overwrite any existing stable tag.

The image uses a digest-pinned Debian base and Debian package indexes frozen at
the `20260830T000000Z` snapshot. It retains the upstream `COPYING`, `README.md`,
and `src/pow.cpp` notices in the runtime image. The written scope clarification
for unmodified official BitcoinII-network use is recorded in
[`willitmod-dev-bc2/SHOCKWAVE_AUTHORIZATION.md`](willitmod-dev-bc2/SHOCKWAVE_AUTHORIZATION.md).

### Mandatory post-fork reindex contract

A later app-recipe phase will create
`/data/node/.core31-full-reindex-required.json` for existing node data. The
Core container mounts that node directory at `/data`. On the first Core 31
start, its wrapper validates the marker and launches one full `-reindex`. Only
after Core has recorded its internal continuation state does the wrapper
atomically write the matching `started` marker. A restart after that point lets
Core resume its persisted reindex state instead of discarding progress.

Only the app may write the `complete` marker and remove `required`, after it has
verified Core 31, mainnet, full synchronization, the post-activation height,
the pinned height-57,752 checkpoint, and minimum chainwork. The wrapper also
validates that full completion evidence before trusting the marker. Manual
`.reindex` and legacy `.reindex-chainstate` requests both become a full reindex
under Core 31, and both request files are cleared together when consumed.
