# AxeBC2 0.1.11 / Core 31 public release gates

The public recipe mirrors the DEV store ID `willitmod-dev-bc2`, which maps to
canonical 5tratumOS app ID `axebc2`. Its preserved data path is
`/var/lib/5tratumos/apps/axebc2`, matching the `app_id` in
`.5tratumos-rollback-policy.json`. The protected consensus rollback floor remains
`0.1.10`; this application-only maintenance release must not change that floor
or repeat the completed Core 31 reindex.

Every host bind uses `create_host_path: false`. The recipe contains the runtime
directories staged before Compose validation, so Docker must not silently create
a misspelled or missing source path. The digest-pinned Alpine init container's
dependency installation still fails before persistent data mutation if its
repositories are unavailable.

## Immutable release inputs

The application candidate is pinned to
`ghcr.io/willitmod/axebc2-app-umbrel-dev:0.1.11-candidate.ecf6e2c8cfd0@sha256:23a7962e223da5549eba52697c6f4cfa16ab74cba935c68c48148a4c515302b4`,
built from source revision `ecf6e2c8cfd0e42ea53d3cc146b18cd6d4c4b563` by
candidate workflow run `33895447789`. Promotion workflow run `33898645561`
copied that exact multi-architecture digest to the DEV and MAIN application tags
without rebuilding it.

The already accepted BitcoinII Core 31 image remains pinned twice to
`ghcr.io/willitmod/bitcoinii-core:31.1.0-rc.cdf44542dde2@sha256:8875917ece57668fe9925d40a256ce8d429a3071511bb555d4ace1fa4370afc6`.
Its source revision is `cdf44542dde255648008249d187fafc15f3a2f09`, built by
candidate workflow run `33675068951`. CKPool remains pinned twice to
`ghcr.io/willitmod/docker-ckpool-solo:590fb2a@sha256:8a9a7f10c8138d0f55533132ee7710a06715a42a49f75efb39be3350ada4fa6e`.

The Core image compiles official BitcoinII Core `v31.1.0` at upstream commit
`8daaf7b12e71d3646eed787f040bf2899a69dc1c` without patching ShockWave. The
authorization and upstream notices remain recorded alongside the recipe.

The test platform remains fixed to the DEV-only `v0.7.12-dev` bundle with
SHA-256
`11a35e68ab169eb0446485992a57b33fae018a92020b7d86bbf9a005571377af`.

The accepted package is bound to DEV store commit
`249ab61506dc09c2151d39e2b210f5f18d75ff21`. Its exact Compose SHA-256 is
`93ceba92069947f47d650a5fb32205836fe070d83707f36912a2e0e83beb1244`;
the public recipe is required to match those Compose bytes.

## Retained Core 31 acceptance

The unchanged Core digest previously completed its mandatory full reindex and
protected migration-marker checks on `10.10.10.235`. A subsequent full restart
did not repeat the reindex. Core reported version `310100`, passed level-4
`verifychain`, matched the official BitcoinII explorer, maintained at least
three outbound Core 31 peers, and had no competing valid tip at or beyond the
ShockWave checkpoint.

## Live 0.1.11 DEV acceptance

The exact application candidate and corrected DEV recipe were installed and
accepted on `10.10.10.235` at `2026-09-04T17:22:22Z`. The node remained on mainnet,
fully synchronized at height 58,444, and matched the official BitcoinII explorer
at block hash
`00000000000000001e6ee54b268e62f3f1306a04cdb8f08a30c712e3e1cc3996`.
Core 31 reported version `310100`, retained valid migration markers and minimum
chainwork, passed level-4 `verifychain`, maintained at least three outbound Core
31 peers, and had no competing valid tip at or beyond the ShockWave checkpoint.
A post-update restart did not repeat the reindex.

The update retained the existing node chain, pool configuration, configured
payout, and rollback policy. The non-submitting Stratum probe, private UI checks,
telemetry and port controls, plus app and OS rollback rejection all passed.
Core-accepted mainnet `1...`, `3...`, and `bc1...` payout families validated;
invalid, wrong-network, RPC-unavailable, and malformed-RPC cases did not mutate
saved configuration or payout history. Bounded pending-address recovery and the
MAIN banner correction also passed.

The corrected versioned Compose command repairs the small CKPool `/config` tree
on every init before executing any preserved, previously seeded init script. The
live app, running as uid/gid 1000, successfully created and atomically replaced a
file in that directory. The potentially large `/www` sharelog tree remains a
separate conditional ownership repair, and the current pool configuration was
not rewritten. The exact observations are recorded in
`DEV-ACCEPTANCE-EVIDENCE.json` and bound to the accepted DEV commit and Compose
checksum above.
