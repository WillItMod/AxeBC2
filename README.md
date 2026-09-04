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

- Current MAIN-store package version: `0.1.10`
- Current DEV-store package version: `0.1.10-dev`
- Public repo package path here: `willitmod-dev-bc2/`
- Mirrored DEV-store package: `WillItMod/5tratStore-dev/willitmod-dev-bc2`
- MAIN-store package: `WillItMod/5tratStore-main/willitmod-dev-bc2`
- Miner endpoint: `stratum+tcp://<host-ip>:2345`
- For the cross-project version matrix and release/changelog pointers, see `https://github.com/WillItMod/AxeSuite/blob/main/docs/releases.md`.
- Both stores consume the same tested application and Core image digests. DEV
  retains commit-bound candidate tags while MAIN uses the promoted stable tags.

## BitcoinII Core 31 release

The `Publish BitcoinII Core image` workflow builds the official BitcoinII Core
v31.1.0 source at upstream commit
`8daaf7b12e71d3646eed787f040bf2899a69dc1c`. The Core 31 candidate was built
natively for amd64 and arm64, smoke-tested by exact architecture digest,
combined into a commit-bound candidate manifest, and checked for provenance,
SBOM, and anonymous public pull access. Production promotion retagged that
tested digest without rebuilding it and refused to overwrite an existing
stable tag.

The public recipe mirrors the released DEV package and pins Core candidate
`31.1.0-rc.cdf44542dde2` at
`sha256:8875917ece57668fe9925d40a256ce8d429a3071511bb555d4ace1fa4370afc6`.
The MAIN store's stable `31.1.0` tag resolves to that exact digest. The DEV and
MAIN application tags likewise resolve to the same tested application digest.

The image uses a digest-pinned Debian base and Debian package indexes frozen at
the `20260830T000000Z` snapshot. It retains the upstream `COPYING`, `README.md`,
and `src/pow.cpp` notices in the runtime image. The written scope clarification
for unmodified official BitcoinII-network use is recorded in
[`willitmod-dev-bc2/SHOCKWAVE_AUTHORIZATION.md`](willitmod-dev-bc2/SHOCKWAVE_AUTHORIZATION.md).

### Mandatory post-fork reindex contract

When an existing installation has block or chainstate data but no completed
Core 31 migration, the released init service atomically creates
`/data/node/.core31-full-reindex-required.json`. The same existing node data is
mounted at `/data`; it is not replaced with a new application data directory.
On the first Core 31 start, the wrapper validates the marker and launches one
full `-reindex`. Only after Core records its internal continuation state does
the wrapper atomically write the matching `started` marker. A restart after
that point resumes Core's persisted reindex instead of beginning again.

Only the app may write the `complete` marker and remove `required`, after it has
verified Core 31, mainnet, full synchronization, the post-activation height,
the pinned height-57,752 checkpoint, and minimum chainwork. The wrapper also
validates that full completion evidence before trusting the marker. Manual
`.reindex` and legacy `.reindex-chainstate` requests both become a full reindex
under Core 31, and both request files are cleared together when consumed.

The upgrade requires 5tratumOS 0.7.12 or newer and installs a rollback floor so
the migrated node cannot subsequently be started by an incompatible older app
or OS. Wallet, payout, and application settings remain in their existing data
directory. A pruned node may need to redownload historical blocks that are no
longer present locally, so mining and sync data remain unavailable until the
validation completes.

### Activation and older miners

Block 57,750 is the first mainnet block whose required work is calculated with
ShockWave. Blocks before that height retain the historical rules. From that
height onward, a miner connected to an old Core 29 node risks working on an
invalid or minority fork; a locally reported find is only a canonical network
block if the upgraded network accepts it.

### Live acceptance

The exact DEV recipe published here was installed and tested on
`10.10.10.235` with the checksum-pinned 5tratumOS `v0.7.12-dev` bundle. The
one-time full reindex completed, the height-57,752 checkpoint and minimum
chainwork were verified, a level-4 `verifychain` passed, and the node matched
the BitcoinII explorer at height 58,433. A subsequent full app restart did not
repeat the reindex.

The test also verified Core 31 peers, Stratum subscribe/authorize/job flow,
payout preservation, UI privacy, disabled support telemetry, outbound-only P2P,
and rejection of app and OS rollback. Sanitized machine-readable evidence is
published in
[`DEV-ACCEPTANCE-EVIDENCE.json`](willitmod-dev-bc2/DEV-ACCEPTANCE-EVIDENCE.json).
