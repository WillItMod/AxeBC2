#!/bin/sh
set -eu

expected_core_version="31.1.0"
expected_core_tag="v31.1.0"
expected_core_commit="8daaf7b12e71d3646eed787f040bf2899a69dc1c"
expected_snapshot="20260830T000000Z"
expected_scope="official-bitcoinii-network"
expected_migration="bitcoinii-shockwave-core31-full-reindex"

core_version="${1:-}"
official_network_only="${2:-false}"

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(dirname -- "$script_dir")"
recipe_dir="$repo_root/willitmod-dev-bc2"
authorization_record="$recipe_dir/SHOCKWAVE_AUTHORIZATION.md"
licenses_record="$recipe_dir/LICENSES.md"
dockerfile="$recipe_dir/data/bitcoiniid/Dockerfile"
wrapper="$recipe_dir/data/bitcoiniid/bitcoinIId-wrapper.sh"
compose_file="$recipe_dir/docker-compose.yml"
manifest_file="$recipe_dir/umbrel-app.yml"
workflow="$repo_root/.github/workflows/publish-bitcoinii-core.yml"

if [ "$core_version" != "$expected_core_version" ]; then
  echo "Expected BitcoinII Core version $expected_core_version, got ${core_version:-<empty>}" >&2
  exit 1
fi

if [ "$official_network_only" != "true" ]; then
  echo "Release must be confirmed as official-BitcoinII-network-only" >&2
  exit 1
fi

test -s "$authorization_record"
test -s "$licenses_record"
grep -Fq "Authorization status: \`confirmed\`" "$authorization_record"
grep -Fq "Authorized scope: \`$expected_scope\`" "$authorization_record"
grep -Fq "$expected_core_commit" "$authorization_record"
grep -Fq 'src/pow.cpp' "$authorization_record"
grep -Fq "$expected_core_commit" "$licenses_record"
grep -Fq 'That clarification does not authorize reuse of ShockWave' "$licenses_record"

grep -Fq "ARG BITCOINII_TAG=$expected_core_tag" "$dockerfile"
grep -Fq "ARG BITCOINII_COMMIT=$expected_core_commit" "$dockerfile"
grep -Fq "ARG BITCOINII_VERSION=$expected_core_version" "$dockerfile"
grep -Fq "ARG DEBIAN_SNAPSHOT=$expected_snapshot" "$dockerfile"
grep -Fq "snapshot.debian.org/archive/debian/\${DEBIAN_SNAPSHOT}" "$dockerfile"
grep -Fq 'COPY --from=builder /src/bitcoinii/COPYING' "$dockerfile"
grep -Fq 'COPY --from=builder /src/bitcoinii/README.md' "$dockerfile"
grep -Fq 'COPY --from=builder /src/bitcoinii/src/pow.cpp' "$dockerfile"
grep -Fq "org.opencontainers.image.version=\"$expected_core_version\"" "$dockerfile"

grep -Fq ".core31-full-reindex-required.json" "$wrapper"
grep -Fq ".core31-full-reindex-started.json" "$wrapper"
grep -Fq ".core31-full-reindex-complete.json" "$wrapper"
grep -Fq "$expected_migration" "$wrapper"
grep -Fq 'activation_height == 57750' "$wrapper"
grep -Fq 'checkpoint_height=57752' "$wrapper"
grep -Fq '000000000000000013ceffe797280c57f75a5b9f1d9e70c3503584058c322576' "$wrapper"
grep -Fq '0000000000000000000000000000000000000000000000959028194ff1139272' "$wrapper"
grep -Fq 'bitcoinII-d "$@" -reindex -daemon=0 -printtoconsole=1' "$wrapper"
grep -Fq 'init message: Loading block index' "$wrapper"
grep -Fq 'Core exited before accepting the full reindex request; it will be retried' "$wrapper"
if grep -Eq 'rm -f .*migration_required|rm -f .*core31-full-reindex-required' "$wrapper"; then
  echo "The node wrapper must not remove the mandatory migration marker" >&2
  exit 1
fi

# Phase 1 publishes only the immutable Core candidate. Protect the live recipe
# from accidentally pointing at an image that has not completed DEV acceptance.
grep -Fq 'image: ghcr.io/willitmod/bitcoinii-core:29.1.0' "$compose_file"
grep -Fq 'image: ghcr.io/willitmod/axebc2-app-umbrel-dev:0.1.7' "$compose_file"
grep -Fq 'version: "0.1.7-dev"' "$manifest_file"
if grep -Fq 'image: ghcr.io/willitmod/bitcoinii-core:31.1.0' "$compose_file"; then
  echo "Phase 1 must not change the live recipe to Core 31" >&2
  exit 1
fi

test -s "$workflow"
grep -Fq "pull_request:" "$workflow"
grep -Fq "pr-verify:" "$workflow"
grep -Fq "if: github.event_name == 'workflow_dispatch'" "$workflow"
if unpinned_actions="$(grep -E '^[[:space:]]+uses:' "$workflow" | grep -Ev '@[0-9a-f]{40}$' || true)" && [ -n "$unpinned_actions" ]; then
  echo "Every workflow action must be pinned to a full commit SHA:" >&2
  echo "$unpinned_actions" >&2
  exit 1
fi
if awk '$1 == "FROM" && $2 !~ /@sha256:[0-9a-f]{64}$/ { exit 1 }' "$dockerfile"; then
  :
else
  echo "Every external Dockerfile base must be digest pinned" >&2
  exit 1
fi
if grep -Fq 'tonistiigi/binfmt' "$workflow"; then
  echo "Native release jobs must not depend on a mutable binfmt helper" >&2
  exit 1
fi
grep -Fq 'push-by-digest=true' "$workflow"
grep -Fq 'provenance: mode=max' "$workflow"
grep -Fq 'sbom: true' "$workflow"
test "$(grep -Fc 'uses: docker/setup-buildx-action@8d2750c68a42422c14e847fe6c8ac0403b4cbd6f' "$workflow")" -eq 3
test "$(grep -Fc 'version: v0.30.1' "$workflow")" -eq 3
test "$(grep -Fc 'image=docker.io/moby/buildkit:v0.26.2@sha256:de10faf919fc71ba4eb1dd7bd6449566d012b0c9436b1c61bfee21d621b009aa' "$workflow")" -eq 3
grep -Fq 'Refusing to overwrite existing candidate tag' "$workflow"
grep -Fq 'Refusing to overwrite existing stable tag' "$workflow"
grep -Fq "git merge-base --is-ancestor \"\$SOURCE_REVISION\" \"\$main_revision\"" "$workflow"
grep -Fq 'environment: axebc2-production' "$workflow"
grep -Fq "docker stop --time 20 \"\$container\"" "$workflow"
grep -Fq 'make_test_data_readable' "$workflow"
grep -Fq ": >\"\$test_data/restart-debug.log\"" "$workflow"
grep -Fq "chmod 0666 \"\$test_data/restart-debug.log\"" "$workflow"
grep -Fq "test -r \"\$test_data/.core31-full-reindex-started.json\"" "$workflow"
grep -Fq "mount \"type=bind,source=\$test_data,target=/cleanup\"" "$workflow"
test "$(grep -Fc -- '--read-only' "$workflow")" -eq 2
test "$(grep -Fc -- '--security-opt no-new-privileges' "$workflow")" -eq 2
grep -Fq 'docker logout ghcr.io' "$workflow"
grep -Fq 'ubuntu-24.04-arm' "$workflow"

echo "AxeBC2 BitcoinII Core $expected_core_version phase-1 release inputs are consistent"
