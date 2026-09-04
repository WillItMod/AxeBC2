#!/bin/sh
set -eu

expected_core_version="31.1.0"
expected_core_tag="v31.1.0"
expected_core_commit="8daaf7b12e71d3646eed787f040bf2899a69dc1c"
expected_snapshot="20260830T000000Z"
expected_scope="official-bitcoinii-network"
expected_migration="bitcoinii-shockwave-core31-full-reindex"
expected_app_version="0.1.10-dev"
expected_app_tag="0.1.10-candidate.6e4ef58218e8"
expected_app_commit="6e4ef58218e8cd5a4d1113196f9872a7f501f52e"
expected_app_digest="sha256:b7ba2df2f48389d145ad18a927b099f32b5aa7708a0ea617a1b04e25c8e7f961"
expected_core_candidate="31.1.0-rc.cdf44542dde2"
expected_core_pipeline_commit="cdf44542dde255648008249d187fafc15f3a2f09"
expected_core_digest="sha256:8875917ece57668fe9925d40a256ce8d429a3071511bb555d4ace1fa4370afc6"
expected_ckpool_digest="sha256:8a9a7f10c8138d0f55533132ee7710a06715a42a49f75efb39be3350ada4fa6e"
expected_os_bundle="11a35e68ab169eb0446485992a57b33fae018a92020b7d86bbf9a005571377af"

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
init_script="$recipe_dir/data/init/init.sh"
node_template="$recipe_dir/data/templates/bitcoinII.conf.template"
release_record="$recipe_dir/CORE31-DEV-RELEASE.md"
acceptance_evidence="$recipe_dir/DEV-ACCEPTANCE-EVIDENCE.json"
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

# The public recipe mirrors the exact DEV candidate that completed live
# acceptance. MAIN retags these same tested digests without rebuilding them.
app_ref="ghcr.io/willitmod/axebc2-app-umbrel-dev:${expected_app_tag}@${expected_app_digest}"
core_ref="ghcr.io/willitmod/bitcoinii-core:${expected_core_candidate}@${expected_core_digest}"
ckpool_ref="ghcr.io/willitmod/docker-ckpool-solo:590fb2a@${expected_ckpool_digest}"
alpine_ref="alpine:3.22.1@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1"

test "$(grep -Fc "$app_ref" "$compose_file")" -eq 1
test "$(grep -Fc "$core_ref" "$compose_file")" -eq 2
test "$(grep -Fc "$ckpool_ref" "$compose_file")" -eq 2
test "$(grep -Fc "$alpine_ref" "$compose_file")" -eq 1
grep -Fq "version: \"$expected_app_version\"" "$manifest_file"
grep -Fq 'Requires 5tratumOS 0.7.12 or newer' "$manifest_file"
grep -Fq 'nodes must perform a full reindex' "$manifest_file"
grep -Fq 'APP_CHANNEL: "ALPHA"' "$compose_file"
grep -Fq 'APP_VERSION_SUFFIX: "-dev"' "$compose_file"
grep -Fq 'SUPPORT_CHECKIN_ENABLED: "false"' "$compose_file"
grep -Fq '"2345:3333/tcp"' "$compose_file"
test "$(grep -Fc 'create_host_path: false' "$compose_file")" -eq 9
if grep -Eq '^[[:space:]]+-[[:space:]]+"?8338:' "$compose_file"; then
  echo "The BitcoinII P2P port must remain outbound-only" >&2
  exit 1
fi

test -s "$init_script"
test -s "$node_template"
test -s "$release_record"
test -s "$acceptance_evidence"
sh -n "$init_script"
grep -Fq 'minimum_os="0.7.12"' "$init_script"
grep -Fq 'minimum_app="0.1.10"' "$init_script"
grep -Fq '.5tratumos-rollback-policy.json' "$init_script"
grep -Fq '.core31-full-reindex-required.json' "$init_script"
grep -Fq "$expected_migration" "$init_script"
grep -Fq 'natpmp=0' "$init_script"
grep -Fq 'natpmp=0' "$node_template"
if grep -Fq 'upnp=1' "$node_template"; then
  echo "The released node template must not enable UPnP" >&2
  exit 1
fi

grep -Fq "$expected_app_commit" "$release_record"
grep -Fq "$expected_core_pipeline_commit" "$release_record"
grep -Fq 'Live DEV acceptance' "$release_record"
jq -e \
  --arg app_version "$expected_app_version" \
  --arg app_digest "$expected_app_digest" \
  --arg app_revision "$expected_app_commit" \
  --arg core_digest "$expected_core_digest" \
  --arg core_revision "$expected_core_pipeline_commit" \
  --arg os_bundle "$expected_os_bundle" '
    .schema == 1 and .result == "passed" and
    .app_version == $app_version and .app_digest == $app_digest and
    .source_revision == $app_revision and .core_digest == $core_digest and
    .core_source_revision == $core_revision and
    .tested_os_version == "v0.7.12-dev" and
    .tested_os_bundle_sha256 == $os_bundle and
    .acceptance.core_version == 310100 and
    .acceptance.migration_required_marker_absent == true and
    .acceptance.migration_started_marker_valid == true and
    .acceptance.migration_complete_marker_valid == true and
    .acceptance.checkpoint_height == 57752 and
    .acceptance.verifychain_level == 4 and
    .acceptance.verifychain_passed == true and
    .acceptance.payout_preserved == true and
    .acceptance.pool_stratum_result == "passed" and
    .acceptance.app_ui_privacy_passed == true and
    .acceptance.telemetry_disabled == true and
    .acceptance.p2p_port_unpublished == true and
    .acceptance.natpmp_disabled == true and
    .acceptance.post_completion_restart_passed == true and
    .acceptance.reindex_not_repeated == true and
    .acceptance.app_rollback_rejected == true and
    .acceptance.os_rollback_rejected == true
  ' "$acceptance_evidence" >/dev/null

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
# Pinned BuildKit v0.26.2 emits the SLSA v0.2-style predicate exposed by
# imagetools under `.SLSA`. Keep both candidate and promotion verification
# locked to that exact schema and fail if an unreviewed v1-style path returns.
# shellcheck disable=SC2016  # jq variables below are intentional literals.
{
  test "$(grep -Fc 'def valid($p; $platform):' "$workflow")" -eq 2
  test "$(grep -Fc '$p.SLSA.buildType == "https://mobyproject.org/buildkit@v1"' "$workflow")" -eq 2
  test "$(grep -Fc '$p.SLSA.metadata["https://mobyproject.org/buildkit@v1#metadata"].vcs.revision == $revision' "$workflow")" -eq 2
  test "$(grep -Fc '$p.SLSA.metadata["https://mobyproject.org/buildkit@v1#metadata"].vcs.source' "$workflow")" -eq 2
  test "$(grep -Fc '$p.SLSA.invocation.environment.github_workflow_sha == $revision' "$workflow")" -eq 2
  test "$(grep -Fc '$p.SLSA.invocation.environment.github_repository == $repository' "$workflow")" -eq 2
  test "$(grep -Fc '$p.SLSA.invocation.environment.platform == $platform' "$workflow")" -eq 2
  test "$(grep -Fc '$p.SLSA.invocation.parameters.args["label:org.opencontainers.image.revision"] == $revision' "$workflow")" -eq 2
  test "$(grep -Fc '$p.SLSA.invocation.parameters.args["label:org.opencontainers.image.source"]' "$workflow")" -eq 2
  test "$(grep -Fc '$p.SLSA.invocation.parameters.args["label:org.opencontainers.image.version"] == $version' "$workflow")" -eq 2
  test "$(grep -Fc 'valid(.["linux/amd64"]; "linux/amd64")' "$workflow")" -eq 2
  test "$(grep -Fc 'valid(.["linux/arm64"]; "linux/arm64")' "$workflow")" -eq 2
}
if grep -Eq 'SLSA\.(buildDefinition|runDetails)' "$workflow"; then
  echo "Provenance verification uses a schema not emitted by pinned BuildKit v0.26.2" >&2
  exit 1
fi
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

echo "AxeBC2 $expected_app_version / BitcoinII Core $expected_core_version public release inputs are consistent"
