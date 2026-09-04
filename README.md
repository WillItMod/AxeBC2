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

- Current MAIN-store package version: `0.1.11`
- Current DEV-store package version: `0.1.11-dev`
- Public repo package path here: `willitmod-dev-bc2/`
- Mirrored DEV-store package: `WillItMod/5tratStore-dev/willitmod-dev-bc2`
- MAIN-store package: `WillItMod/5tratStore-main/willitmod-dev-bc2`
- Miner endpoint: `stratum+tcp://<host-ip>:2345`
- For the cross-project version matrix and release/changelog pointers, see `https://github.com/WillItMod/AxeSuite/blob/main/docs/releases.md`.
- DEV pins the accepted commit-bound application candidate. MAIN pins the
  stable tag promoted from that exact tested digest without rebuilding.

## AxeBC2 0.1.11 application release

The DEV recipe pins application candidate
`0.1.11-candidate.ecf6e2c8cfd0` at
`sha256:23a7962e223da5549eba52697c6f4cfa16ab74cba935c68c48148a4c515302b4`,
built from private application source revision
`ecf6e2c8cfd0e42ea53d3cc146b18cd6d4c4b563` by workflow run `33895447789`.
Promotion workflow run `33898645561` copied that exact multi-architecture digest,
without rebuilding, to the DEV and MAIN `0.1.11` application tags.
It fixes strict Core-backed payout validation, bounded recovery of older pending
checks, and the misleading MAIN payout banner. Its versioned Compose init command
also keeps the small CKPool `/config` tree writable on every init and conditionally
repairs existing `/www` sharelog ownership when required, before running the
preserved init script from an older installation. Core and CKPool are unchanged;
existing state is retained and this update does not request another blockchain
reindex.

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
The MAIN store's stable `31.1.0` tag resolves to that exact digest. The MAIN
application tag likewise resolves to the exact 0.1.11 DEV-tested application
digest.

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

The exact application candidate and corrected DEV recipe were accepted on
`10.10.10.235` at `2026-09-04T17:22:22Z` with the checksum-pinned 5tratumOS
`v0.7.12-dev` bundle. The tested recipe is DEV store commit
`249ab61506dc09c2151d39e2b210f5f18d75ff21`; its Compose SHA-256 is
`93ceba92069947f47d650a5fb32205836fe070d83707f36912a2e0e83beb1244`.

Core 31 remained fully synchronized, passed level-4 `verifychain`, and matched
the BitcoinII explorer at height 58,444 and block hash
`00000000000000001e6ee54b268e62f3f1306a04cdb8f08a30c712e3e1cc3996`.
The completed migration markers, configured payout, pool configuration, rollback
policy, private UI behavior, and Stratum flow were preserved; a restart did not
repeat the reindex.

Acceptance also covered Core-valid `1...`, `3...`, and `bc1...` payout families,
fail-closed invalid and RPC-unavailable cases, bounded pending-address recovery,
the corrected MAIN banner, and an atomic payout write by uid/gid 1000 in the
fresh-install CKPool config directory. Telemetry, public P2P publication, NAT-PMP,
and incompatible app/OS rollbacks remained disabled or rejected as required.
The sanitized machine-readable evidence is published in
[`DEV-ACCEPTANCE-EVIDENCE.json`](willitmod-dev-bc2/DEV-ACCEPTANCE-EVIDENCE.json).
