#!/bin/sh
set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(dirname -- "$script_dir")"
wrapper="$repo_root/willitmod-dev-bc2/data/bitcoiniid/bitcoinIId-wrapper.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/bitcoinII-d" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then
  printf 'BitcoinII Core version v%s.0\n' "${FAKE_CORE_MAJOR:-31}"
  exit 0
fi
printf '%s\n' "$@" >"$BITCOINII_TEST_LOG"

reindex=0
acceptance_log=""
for arg in "$@"; do
  case "$arg" in
    -reindex)
      reindex=1
      ;;
    -debuglogfile=*)
      acceptance_log="${arg#-debuglogfile=}"
      ;;
  esac
done

if [ "$reindex" -eq 1 ]; then
  case "${FAKE_REINDEX_MODE:-accept}" in
    accept)
      test -n "$acceptance_log"
      printf '2026-09-02T18:00:00Z init message: Loading block index\342\200\246\n' \
        >>"$acceptance_log"
      ;;
    fail-before-acceptance)
      exit 42
      ;;
    exit-before-acceptance)
      exit 0
      ;;
    *)
      echo "Unknown FAKE_REINDEX_MODE: ${FAKE_REINDEX_MODE}" >&2
      exit 64
      ;;
  esac
fi
EOF
chmod 0755 "$fake_bin/bitcoinII-d"

common_required='{"schema":1,"migration":"bitcoinii-shockwave-core31-full-reindex","minimum_core_major":31,"activation_height":57750}'
common_started='{"schema":1,"migration":"bitcoinii-shockwave-core31-full-reindex","minimum_core_major":31,"activation_height":57750,"started_at":"2026-09-02T18:00:00Z"}'
common_complete='{"schema":1,"migration":"bitcoinii-shockwave-core31-full-reindex","minimum_core_major":31,"activation_height":57750,"completed_at":"2026-09-02T19:00:00Z","validated_height":58127,"best_block_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","core_version":310100,"checkpoint_height":57752,"checkpoint_hash":"000000000000000013ceffe797280c57f75a5b9f1d9e70c3503584058c322576","validated_chainwork":"0000000000000000000000000000000000000000000000959028194ff1139272"}'

new_case() {
  case_name="$1"
  case_dir="$test_root/$case_name"
  mkdir -p "$case_dir"
  : >"$case_dir/daemon.log"
}

run_wrapper() {
  wrapper_mode="${1:-accept}"
  wrapper_major="${2:-31}"
  PATH="$fake_bin:$PATH" \
    AXEBC2_NODE_DIR="$case_dir" \
    BITCOINII_TEST_LOG="$case_dir/daemon.log" \
    FAKE_CORE_MAJOR="$wrapper_major" \
    FAKE_REINDEX_MODE="$wrapper_mode" \
    "$wrapper" -datadir="$case_dir" -server=1
}

assert_reindex_arg() {
  test "$(grep -cx -- '-reindex' "$case_dir/daemon.log")" -eq 1
}

assert_no_reindex_arg() {
  if grep -Fxq -- '-reindex' "$case_dir/daemon.log"; then
    echo "Unexpected -reindex in $case_dir/daemon.log" >&2
    exit 1
  fi
}

new_case normal_start
run_wrapper
assert_no_reindex_arg

new_case mandatory_first_start
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
run_wrapper
assert_reindex_arg
test -f "$case_dir/.core31-full-reindex-required.json"
test -f "$case_dir/.core31-full-reindex-started.json"
jq -e '
  .schema == 1 and
  .migration == "bitcoinii-shockwave-core31-full-reindex" and
  .minimum_core_major == 31 and
  .activation_height == 57750 and
  (.started_at | type == "string" and length > 0)
' "$case_dir/.core31-full-reindex-started.json" >/dev/null

# A restart after Core has persisted its reindex state must resume naturally;
# repeatedly supplying -reindex would discard progress on every app restart.
: >"$case_dir/daemon.log"
run_wrapper
assert_no_reindex_arg
test -f "$case_dir/.core31-full-reindex-required.json"
test -f "$case_dir/.core31-full-reindex-started.json"

# A daemon/argument/startup failure before Core has accepted -reindex must not
# advance the wrapper marker. The same request has to be retried next start.
new_case mandatory_failure_before_acceptance
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
set +e
run_wrapper fail-before-acceptance >"$case_dir/wrapper.out" 2>&1
status=$?
set -e
test "$status" -eq 42
assert_reindex_arg
test -f "$case_dir/.core31-full-reindex-required.json"
test ! -e "$case_dir/.core31-full-reindex-started.json"
test ! -e "$case_dir/.core31-full-reindex-complete.json"
grep -Fq 'Core exited before accepting the full reindex request; it will be retried' \
  "$case_dir/wrapper.out"
: >"$case_dir/daemon.log"
run_wrapper
assert_reindex_arg
test -f "$case_dir/.core31-full-reindex-required.json"
test -f "$case_dir/.core31-full-reindex-started.json"

# A zero exit without the pinned Core acceptance evidence is also a failed
# bootstrap, not permission to consume the request.
new_case mandatory_zero_exit_before_acceptance
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
set +e
run_wrapper exit-before-acceptance >"$case_dir/wrapper.out" 2>&1
status=$?
set -e
test "$status" -eq 75
assert_reindex_arg
test -f "$case_dir/.core31-full-reindex-required.json"
test ! -e "$case_dir/.core31-full-reindex-started.json"

new_case explicit_full_reindex
touch "$case_dir/.reindex" "$case_dir/.reindex-chainstate"
run_wrapper
assert_reindex_arg
test ! -e "$case_dir/.reindex"
test ! -e "$case_dir/.reindex-chainstate"

# Manual requests have the same retry guarantee: neither spelling is cleared
# until Core has persisted its own reindex continuation flag.
new_case explicit_failure_before_acceptance
touch "$case_dir/.reindex" "$case_dir/.reindex-chainstate"
set +e
run_wrapper fail-before-acceptance >"$case_dir/wrapper.out" 2>&1
status=$?
set -e
test "$status" -eq 42
assert_reindex_arg
test -f "$case_dir/.reindex"
test -f "$case_dir/.reindex-chainstate"
: >"$case_dir/daemon.log"
run_wrapper
assert_reindex_arg
test ! -e "$case_dir/.reindex"
test ! -e "$case_dir/.reindex-chainstate"

new_case legacy_chainstate_reindex
touch "$case_dir/.reindex-chainstate"
run_wrapper
assert_reindex_arg
test ! -e "$case_dir/.reindex"
test ! -e "$case_dir/.reindex-chainstate"

# A stale manual marker after the mandatory-start marker must be consumed
# without supplying -reindex again and resetting in-progress Core work.
new_case started_with_stale_manual_flags
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
printf '%s\n' "$common_started" >"$case_dir/.core31-full-reindex-started.json"
touch "$case_dir/.reindex" "$case_dir/.reindex-chainstate"
run_wrapper
assert_no_reindex_arg
test -f "$case_dir/.core31-full-reindex-required.json"
test -f "$case_dir/.core31-full-reindex-started.json"
test ! -e "$case_dir/.reindex"
test ! -e "$case_dir/.reindex-chainstate"

# A verified completion marker wins over the small atomic-write/removal window
# in which the required marker may still coexist with it. The wrapper never
# removes the required marker; only the app's completion path may do that.
new_case completed_migration
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
printf '%s\n' "$common_started" >"$case_dir/.core31-full-reindex-started.json"
printf '%s\n' "$common_complete" >"$case_dir/.core31-full-reindex-complete.json"
run_wrapper
assert_no_reindex_arg
test -f "$case_dir/.core31-full-reindex-required.json"

new_case invalid_required
printf '%s\n' '{"schema":1,"migration":"wrong","minimum_core_major":31,"activation_height":57750}' \
  >"$case_dir/.core31-full-reindex-required.json"
set +e
run_wrapper >/dev/null 2>&1
status=$?
set -e
test "$status" -eq 78
test ! -s "$case_dir/daemon.log"

new_case invalid_started_timestamp
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
printf '%s\n' "$common_started" | \
  jq '.started_at = "not-a-timestamp"' \
  >"$case_dir/.core31-full-reindex-started.json"
set +e
run_wrapper >/dev/null 2>&1
status=$?
set -e
test "$status" -eq 78
test ! -s "$case_dir/daemon.log"

new_case invalid_complete
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
printf '%s\n' "$common_started" >"$case_dir/.core31-full-reindex-started.json"
printf '%s\n' '{"schema":1,"migration":"bitcoinii-shockwave-core31-full-reindex","minimum_core_major":31,"activation_height":57750,"completed_at":"now","validated_height":1,"best_block_hash":"bad"}' \
  >"$case_dir/.core31-full-reindex-complete.json"
set +e
run_wrapper >/dev/null 2>&1
status=$?
set -e
test "$status" -eq 78
test ! -s "$case_dir/daemon.log"

new_case invalid_complete_timestamp
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
printf '%s\n' "$common_started" >"$case_dir/.core31-full-reindex-started.json"
printf '%s\n' "$common_complete" | \
  jq '.completed_at = "not-a-timestamp"' \
  >"$case_dir/.core31-full-reindex-complete.json"
set +e
run_wrapper >/dev/null 2>&1
status=$?
set -e
test "$status" -eq 78
test ! -s "$case_dir/daemon.log"

# Old/weak completion records with only tip evidence must not suppress the
# mandatory migration when the image is launched outside the app initializer.
new_case weak_complete_missing_trust_anchors
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
printf '%s\n' "$common_started" >"$case_dir/.core31-full-reindex-started.json"
printf '%s\n' '{"schema":1,"migration":"bitcoinii-shockwave-core31-full-reindex","minimum_core_major":31,"activation_height":57750,"completed_at":"2026-09-02T19:00:00Z","validated_height":58127,"best_block_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}' \
  >"$case_dir/.core31-full-reindex-complete.json"
set +e
run_wrapper >/dev/null 2>&1
status=$?
set -e
test "$status" -eq 78
test ! -s "$case_dir/daemon.log"

new_case complete_with_wrong_checkpoint
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
printf '%s\n' "$common_started" >"$case_dir/.core31-full-reindex-started.json"
printf '%s\n' "$common_complete" | \
  jq '.checkpoint_hash = ("0" * 64)' \
  >"$case_dir/.core31-full-reindex-complete.json"
set +e
run_wrapper >/dev/null 2>&1
status=$?
set -e
test "$status" -eq 78
test ! -s "$case_dir/daemon.log"

new_case complete_with_low_chainwork
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
printf '%s\n' "$common_started" >"$case_dir/.core31-full-reindex-started.json"
printf '%s\n' "$common_complete" | \
  jq '.validated_chainwork = ("0" * 64)' \
  >"$case_dir/.core31-full-reindex-complete.json"
set +e
run_wrapper >/dev/null 2>&1
status=$?
set -e
test "$status" -eq 78
test ! -s "$case_dir/daemon.log"

new_case complete_with_old_core
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
printf '%s\n' "$common_started" >"$case_dir/.core31-full-reindex-started.json"
printf '%s\n' "$common_complete" | \
  jq '.core_version = 290000' \
  >"$case_dir/.core31-full-reindex-complete.json"
set +e
run_wrapper >/dev/null 2>&1
status=$?
set -e
test "$status" -eq 78
test ! -s "$case_dir/daemon.log"

new_case complete_without_started
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
printf '%s\n' "$common_complete" >"$case_dir/.core31-full-reindex-complete.json"
set +e
run_wrapper >/dev/null 2>&1
status=$?
set -e
test "$status" -eq 78
test ! -s "$case_dir/daemon.log"

new_case required_removed_before_complete
printf '%s\n' "$common_started" >"$case_dir/.core31-full-reindex-started.json"
set +e
run_wrapper >/dev/null 2>&1
status=$?
set -e
test "$status" -eq 78
test ! -s "$case_dir/daemon.log"

new_case wrong_core_major
printf '%s\n' "$common_required" >"$case_dir/.core31-full-reindex-required.json"
set +e
run_wrapper accept 29 >/dev/null 2>&1
status=$?
set -e
test "$status" -eq 78
test ! -e "$case_dir/.core31-full-reindex-started.json"
test ! -s "$case_dir/daemon.log"

echo "BitcoinII Core wrapper migration tests passed"
