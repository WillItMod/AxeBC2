#!/bin/sh
set -eu

expected_core_version="31.1.0"
expected_core_tag="v31.1.0"
expected_core_commit="8daaf7b12e71d3646eed787f040bf2899a69dc1c"
expected_snapshot="20260830T000000Z"
expected_scope="official-bitcoinii-network"
expected_migration="bitcoinii-shockwave-core31-full-reindex"
expected_app_version="0.1.11-dev"
expected_app_tag="0.1.11-candidate.ecf6e2c8cfd0"
expected_app_commit="ecf6e2c8cfd0e42ea53d3cc146b18cd6d4c4b563"
expected_app_digest="sha256:23a7962e223da5549eba52697c6f4cfa16ab74cba935c68c48148a4c515302b4"
expected_app_candidate_run="33895447789"
expected_app_promotion_run="33898645561"
expected_dev_store_revision="249ab61506dc09c2151d39e2b210f5f18d75ff21"
expected_dev_compose_sha256="93ceba92069947f47d650a5fb32205836fe070d83707f36912a2e0e83beb1244"
expected_acceptance_timestamp="2026-09-04T17:22:22Z"
expected_acceptance_hash="00000000000000001e6ee54b268e62f3f1306a04cdb8f08a30c712e3e1cc3996"
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
readme="$repo_root/README.md"

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

# The public recipe mirrors the exact accepted DEV candidate and recipe. The
# evidence gate below binds those bytes to the completed live test; MAIN reuses
# the same tested application digest without rebuilding it.
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
grep -Fq 'beginning with 1, 3, or bc1' "$manifest_file"
grep -Fq 'misleading payout warning from MAIN builds' "$manifest_file"
grep -Fq 'conditional CKPool /www ownership repair' "$manifest_file"
grep -Fq 'trigger another blockchain reindex' "$manifest_file"
grep -Fq 'APP_CHANNEL: "ALPHA"' "$compose_file"
grep -Fq 'APP_VERSION_SUFFIX: "-dev"' "$compose_file"
grep -Fq 'SUPPORT_CHECKIN_ENABLED: "false"' "$compose_file"
grep -Fq '"2345:3333/tcp"' "$compose_file"
# shellcheck disable=SC2016  # literal Compose interpolation syntax
test "$(grep -Fc '$$(stat -c' "$compose_file")" -eq 3
grep -Fq 'chown -R 1000:1000 /data/pool/config' "$compose_file"
grep -Fq 'chown -R 1000:1000 /data/pool/www' "$compose_file"
grep -Fq 'previously seeded init script' "$compose_file"
config_repair_line="$(grep -nF 'chown -R 1000:1000 /data/pool/config' "$compose_file" | cut -d: -f1)"
sharelog_repair_line="$(grep -nF 'chown -R 1000:1000 /data/pool/www' "$compose_file" | cut -d: -f1)"
exec_line="$(grep -nF 'exec /bin/sh /opt/axebc2/init.sh' "$compose_file" | cut -d: -f1)"
test "$config_repair_line" -lt "$exec_line"
test "$sharelog_repair_line" -lt "$exec_line"
# shellcheck disable=SC2016  # reject the unescaped literal form
if grep -Fq '"$(stat -c' "$compose_file"; then
  echo "Compose must escape init-command substitutions from host interpolation" >&2
  exit 1
fi
# shellcheck disable=SC2016  # config must not use the conditional stat pattern
if grep -Fq '$$(stat -c '\''%u:%g'\'' /data/pool/config' "$compose_file"; then
  echo "The small CKPool config tree must be repaired on every init run" >&2
  exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
  observed_dev_compose_sha256="$(sha256sum "$compose_file" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  observed_dev_compose_sha256="$(shasum -a 256 "$compose_file" | awk '{print $1}')"
else
  echo "A SHA-256 checksum utility is required" >&2
  exit 1
fi
if [ "$observed_dev_compose_sha256" != "$expected_dev_compose_sha256" ]; then
  echo "Public Compose does not exactly match the accepted DEV recipe" >&2
  exit 1
fi
test "$(grep -Fc 'create_host_path: false' "$compose_file")" -eq 9
if grep -Eq '^[[:space:]]+-[[:space:]]+"?8338:' "$compose_file"; then
  echo "The BitcoinII P2P port must remain outbound-only" >&2
  exit 1
fi

test -s "$init_script"
test -s "$node_template"
test -s "$release_record"
test -s "$acceptance_evidence"
test -s "$readme"
sh -n "$init_script"
grep -Fq 'minimum_os="0.7.12"' "$init_script"
grep -Fq 'minimum_app="0.1.10"' "$init_script"
# shellcheck disable=SC2016  # literal init-script variable reference
grep -Fq 'chown -R 1000:1000 "${data_dir}/pool/config"' "$init_script"
grep -Fq 'cannot assign CKPool config data to the app user' "$init_script"
grep -Fq 'repair_sharelog_ownership' "$init_script"
grep -Fq 'cannot assign CKPool sharelog data to the app user' "$init_script"
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
grep -Fq 'Live 0.1.11 DEV acceptance' "$release_record"
for release_document in "$readme" "$release_record"; do
  grep -Fq "$expected_app_promotion_run" "$release_document"
  grep -Fq "$expected_dev_store_revision" "$release_document"
  grep -Fq "$expected_dev_compose_sha256" "$release_document"
  grep -Fq "$expected_acceptance_timestamp" "$release_document"
  grep -Fq '58,444' "$release_document"
  grep -Fq "$expected_acceptance_hash" "$release_document"
done
python3 - \
  "$acceptance_evidence" \
  "$expected_app_version" \
  "$expected_app_tag" \
  "$expected_app_digest" \
  "$expected_app_commit" \
  "$expected_app_candidate_run" \
  "$expected_dev_store_revision" \
  "$expected_dev_compose_sha256" \
  "$expected_core_candidate" \
  "$expected_core_digest" \
  "$expected_core_pipeline_commit" \
  "$expected_os_bundle" \
  "$expected_acceptance_timestamp" \
  "$expected_acceptance_hash" <<'PY'
import datetime
import json
import re
import sys

(
    evidence_path,
    app_version,
    app_tag,
    app_digest,
    app_revision,
    app_candidate_run,
    dev_store_revision,
    dev_compose_sha256,
    core_candidate,
    core_digest,
    core_revision,
    os_bundle,
    acceptance_timestamp,
    acceptance_hash,
) = sys.argv[1:]

try:
    with open(evidence_path, encoding="utf-8") as handle:
        evidence = json.load(handle)
except (OSError, ValueError) as exc:
    raise SystemExit(f"invalid DEV acceptance evidence: {exc}")

expected = {
    "schema": 1,
    "result": "passed",
    "app_image": f"ghcr.io/willitmod/axebc2-app-umbrel-dev:{app_tag}",
    "app_digest": app_digest,
    "app_candidate_run": int(app_candidate_run),
    "app_version": app_version,
    "source_revision": app_revision,
    "dev_store_revision": dev_store_revision,
    "dev_compose_sha256": dev_compose_sha256,
    "core_image": f"ghcr.io/willitmod/bitcoinii-core:{core_candidate}",
    "core_digest": core_digest,
    "core_source_revision": core_revision,
    "core_candidate_run": 33675068951,
    "tested_os_version": "v0.7.12-dev",
    "tested_os_bundle_sha256": os_bundle,
    "tested_at": acceptance_timestamp,
}
for key, value in expected.items():
    if evidence.get(key) != value:
        raise SystemExit(f"DEV acceptance evidence {key!r} must equal {value!r}")

if evidence.get("tested_on") != "10.10.10.235":
    raise SystemExit("DEV acceptance evidence must identify the accepted test node")

def require_utc_timestamp(value, label):
    if not isinstance(value, str) or not value.endswith("Z"):
        raise SystemExit(f"{label} must be an ISO-8601 UTC timestamp")
    try:
        parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise SystemExit(f"{label} must be an ISO-8601 UTC timestamp") from exc
    if parsed.utcoffset() != datetime.timedelta(0):
        raise SystemExit(f"{label} must be UTC")

require_utc_timestamp(evidence.get("tested_at"), "tested_at")
acceptance = evidence.get("acceptance")
if not isinstance(acceptance, dict):
    raise SystemExit("DEV acceptance evidence requires structured acceptance observations")
require_utc_timestamp(acceptance.get("observed_at"), "acceptance observed_at")
if acceptance.get("observed_at") != acceptance_timestamp:
    raise SystemExit("acceptance observed_at does not identify the accepted DEV run")

true_gates = (
    "migration_required_marker_absent",
    "migration_started_marker_valid",
    "migration_complete_marker_valid",
    "verifychain_passed",
    "payout_configured",
    "payout_preserved",
    "app_ui_privacy_passed",
    "payout_validation_passed",
    "invalid_payout_rejected_without_mutation",
    "rpc_unavailable_rejected_without_mutation",
    "pending_payout_revalidation_passed",
    "main_payout_banner_hidden",
    "pool_config_directory_writable",
    "ckpool_sharelog_ownership_repaired",
    "telemetry_disabled",
    "p2p_port_unpublished",
    "natpmp_disabled",
    "post_completion_restart_passed",
    "reindex_not_repeated",
    "app_rollback_rejected",
    "os_rollback_rejected",
)
if any(acceptance.get(key) is not True for key in true_gates):
    raise SystemExit("all required DEV acceptance gates must be true")

if acceptance.get("chain") != "main" or acceptance.get("competing_valid_tips") != 0:
    raise SystemExit("main chain must have no competing valid tips")
if acceptance.get("core_version") != 310100:
    raise SystemExit("exact Core 31.1.0 version was not observed")
if (
    acceptance.get("checkpoint_height") != 57752
    or acceptance.get("checkpoint_hash")
    != "000000000000000013ceffe797280c57f75a5b9f1d9e70c3503584058c322576"
):
    raise SystemExit("official checkpoint observation is invalid")

hex64 = lambda value: isinstance(value, str) and bool(re.fullmatch(r"[0-9a-f]{64}", value))
minimum_chainwork = "0000000000000000000000000000000000000000000000959028194ff1139272"
if not hex64(acceptance.get("chainwork")) or acceptance["chainwork"] < minimum_chainwork:
    raise SystemExit("observed chainwork is below the required minimum")
progress = acceptance.get("verification_progress")
if (
    acceptance.get("ibd") is not False
    or isinstance(progress, bool)
    or not isinstance(progress, (int, float))
    or progress < 0.999999
):
    raise SystemExit("node synchronization evidence is incomplete")
blocks = acceptance.get("blocks")
if (
    isinstance(blocks, bool)
    or not isinstance(blocks, int)
    or blocks != 58444
    or blocks != acceptance.get("headers")
    or blocks != acceptance.get("explorer_common_height")
):
    raise SystemExit("node and Explorer heights do not match")
if (
    not hex64(acceptance.get("best_block_hash"))
    or acceptance["best_block_hash"] != acceptance_hash
    or acceptance["best_block_hash"] != acceptance.get("explorer_common_hash")
):
    raise SystemExit("node and Explorer hashes do not match")
peers = acceptance.get("outbound_core31_peers")
if isinstance(peers, bool) or not isinstance(peers, int) or peers < 3:
    raise SystemExit("fewer than three outbound Core 31 peers were observed")
if acceptance.get("verifychain_level") != 4:
    raise SystemExit("verifychain level 4 was not recorded")
if acceptance.get("pool_stratum_result") != "passed":
    raise SystemExit("pool and Stratum acceptance did not pass")
PY

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
