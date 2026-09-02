#!/bin/sh
set -eu

# The app sees these as /data/node/*; the node volume is mounted at /data in
# this container. AXEBC2_NODE_DIR is used only by the wrapper regression tests.
node_dir="${AXEBC2_NODE_DIR:-/data}"
reindex_chainstate_flag="${node_dir}/.reindex-chainstate"
reindex_flag="${node_dir}/.reindex"
migration_required="${node_dir}/.core31-full-reindex-required.json"
migration_started="${node_dir}/.core31-full-reindex-started.json"
migration_complete="${node_dir}/.core31-full-reindex-complete.json"
migration_name="bitcoinii-shockwave-core31-full-reindex"
checkpoint_height=57752
checkpoint_hash="000000000000000013ceffe797280c57f75a5b9f1d9e70c3503584058c322576"
minimum_chainwork="0000000000000000000000000000000000000000000000959028194ff1139272"

validate_common_marker() {
  marker="$1"
  marker_label="$2"

  if [ ! -f "$marker" ]; then
    return 1
  fi

  if ! jq -e --arg migration "$migration_name" '
    type == "object" and
    .schema == 1 and
    .migration == $migration and
    .minimum_core_major == 31 and
    .activation_height == 57750
  ' "$marker" >/dev/null 2>&1; then
    echo "[axebc2] invalid ${marker_label}: marker schema does not match" >&2
    exit 78
  fi
}

validate_timestamp_field() {
  marker="$1"
  marker_label="$2"
  field="$3"
  if ! jq -e --arg field "$field" '
    def normalized_utc:
      sub("[.][0-9]+Z$"; "Z")
      | sub("[.][0-9]+[+]00:00$"; "Z")
      | sub("[+]00:00$"; "Z");
    .[$field] as $timestamp |
    ($timestamp | type == "string") and
    ($timestamp | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?(Z|[+]00:00)$")) and
    ($timestamp | try (normalized_utc | fromdateiso8601 | type == "number") catch false)
  ' "$marker" >/dev/null 2>&1; then
    echo "[axebc2] invalid ${marker_label}: ${field} is not a UTC timestamp" >&2
    exit 78
  fi
}

# Any marker that exists must be recognizable. Corrupt state fails closed
# instead of silently trusting a potentially pre-ShockWave chain index.
if [ -f "$migration_required" ]; then
  validate_common_marker "$migration_required" "required migration marker"
fi
if [ -f "$migration_started" ]; then
  validate_common_marker "$migration_started" "started migration marker"
  validate_timestamp_field "$migration_started" "started migration marker" "started_at"
fi
if [ -f "$migration_complete" ]; then
  validate_common_marker "$migration_complete" "complete migration marker"
  validate_timestamp_field "$migration_complete" "complete migration marker" "completed_at"
  if ! jq -e \
    --argjson checkpoint_height "$checkpoint_height" \
    --arg checkpoint_hash "$checkpoint_hash" \
    --arg minimum_chainwork "$minimum_chainwork" '
    (.validated_height | type == "number" and floor == . and . >= 57750) and
    (.best_block_hash | type == "string" and test("^[0-9a-f]{64}$")) and
    (.core_version | type == "number" and floor == . and . >= 310000) and
    .checkpoint_height == $checkpoint_height and
    .checkpoint_hash == $checkpoint_hash and
    (.validated_chainwork |
      type == "string" and
      test("^[0-9a-f]{64}$") and
      . >= $minimum_chainwork)
  ' "$migration_complete" >/dev/null 2>&1; then
    echo "[axebc2] invalid complete migration marker: Core/checkpoint/chainwork evidence does not match" >&2
    exit 78
  fi
fi

# These relationships are part of the app/wrapper hand-off. A complete marker
# can only follow a started migration, and required must remain present until
# complete is durable. Reject impossible combinations instead of bypassing the
# mandatory reindex on malformed or partially edited state.
if [ -f "$migration_complete" ] && [ ! -f "$migration_started" ]; then
  echo "[axebc2] invalid migration state: complete exists without started" >&2
  exit 78
fi
if [ -f "$migration_started" ] && \
   [ ! -f "$migration_required" ] && \
   [ ! -f "$migration_complete" ]; then
  echo "[axebc2] invalid migration state: required was removed before completion" >&2
  exit 78
fi

manual_reindex=0
if [ -f "$reindex_flag" ]; then
  echo "[axebc2] full reindex requested" >&2
  manual_reindex=1
fi
if [ -f "$reindex_chainstate_flag" ]; then
  # Core v31 rejects -reindex-chainstate whenever prune mode is configured.
  # Promote the legacy app request to the safer full reindex operation.
  echo "[axebc2] chainstate reindex requested; using full reindex for Core v31" >&2
  manual_reindex=1
fi

migration_reindex=0
if [ -f "$migration_required" ] && [ ! -f "$migration_complete" ]; then
  if [ ! -f "$migration_started" ]; then
    core_major="$(bitcoinII-d --version | sed -n '1s/.*v\([0-9][0-9]*\).*/\1/p')"
    if [ "$core_major" != "31" ]; then
      echo "[axebc2] refusing Core 31 migration with Core major ${core_major:-unknown}" >&2
      exit 78
    fi
    echo "[axebc2] starting mandatory Core 31 ShockWave full reindex" >&2
    migration_reindex=1
  else
    echo "[axebc2] mandatory Core 31 reindex already started; Core will resume its persisted reindex state" >&2
    # A manual marker left behind during the tiny started-marker/cleanup window
    # is redundant. Never reset an already-running mandatory migration.
    if [ "$manual_reindex" -eq 1 ]; then
      if ! rm -f "$reindex_flag" "$reindex_chainstate_flag"; then
        echo "[axebc2] cannot clear redundant reindex request markers" >&2
        exit 78
      fi
      manual_reindex=0
    fi
  fi
fi

if [ "$manual_reindex" -eq 1 ] || [ "$migration_reindex" -eq 1 ]; then
  acceptance_log="${node_dir}/.core31-reindex-bootstrap.log"
  if ! : >"$acceptance_log"; then
    echo "[axebc2] cannot create the Core reindex acceptance log" >&2
    exit 78
  fi

  write_started_marker() {
    started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    started_tmp="${migration_started}.tmp.$$"
    umask 077
    if ! printf '%s\n' \
      "{\"schema\":1,\"migration\":\"${migration_name}\",\"minimum_core_major\":31,\"activation_height\":57750,\"started_at\":\"${started_at}\"}" \
      >"$started_tmp"; then
      rm -f "$started_tmp"
      return 1
    fi
    if ! mv "$started_tmp" "$migration_started"; then
      rm -f "$started_tmp"
      return 1
    fi
  }

  child_pid=""
  # Invoked indirectly by the three traps below.
  # ShellCheck versions before 0.11 use SC2317 for this trap-only function;
  # 0.11 and later use SC2329.
  # shellcheck disable=SC2317,SC2329
  forward_signal() {
    forwarded_signal="$1"
    if [ -n "$child_pid" ] && kill -0 "$child_pid" 2>/dev/null; then
      kill "-$forwarded_signal" "$child_pid" 2>/dev/null || true
    fi
  }
  trap 'forward_signal TERM' TERM
  trap 'forward_signal INT' INT
  trap 'forward_signal HUP' HUP

  # Supervise the first launch. In the pinned Core v31.1.0 source, the
  # "Loading block index" init message is emitted only after BlockManager has
  # opened its block-index DB and recorded reindex continuation via
  # WriteReindexing(true). Until this evidence appears, request markers remain
  # untouched so an exec/argument/startup failure is retried safely.
  bitcoinII-d "$@" -reindex -daemon=0 -printtoconsole=1 \
    -debuglogfile="$acceptance_log" &
  child_pid=$!

  (
    record_acceptance() {
      if [ "$migration_reindex" -eq 1 ] && ! write_started_marker; then
        echo "[axebc2] cannot persist the Core 31 migration started marker" >&2
        kill -TERM "$child_pid" 2>/dev/null || true
        return 78
      fi
      if ! rm -f "$reindex_flag" "$reindex_chainstate_flag"; then
        echo "[axebc2] cannot clear consumed reindex request markers" >&2
        kill -TERM "$child_pid" 2>/dev/null || true
        return 78
      fi
      echo "[axebc2] Core accepted and persisted the full reindex request" >&2
    }

    while kill -0 "$child_pid" 2>/dev/null; do
      if grep -Fq 'init message: Loading block index' "$acceptance_log" 2>/dev/null; then
        record_acceptance
        exit $?
      fi
      sleep 0.2
    done

    # Cover the race where Core emitted the evidence immediately before exit.
    if grep -Fq 'init message: Loading block index' "$acceptance_log" 2>/dev/null; then
      record_acceptance
      exit $?
    fi
    echo "[axebc2] Core exited before accepting the full reindex request; it will be retried" >&2
    exit 75
  ) &
  monitor_pid=$!

  # wait(1) can be interrupted after a forwarded signal. Keep waiting until
  # the actual child is reaped, then return its real exit status.
  while :; do
    set +e
    wait "$child_pid"
    child_status=$?
    set -e
    if ! kill -0 "$child_pid" 2>/dev/null; then
      break
    fi
  done

  set +e
  wait "$monitor_pid"
  monitor_status=$?
  set -e
  trap - TERM INT HUP

  if [ "$monitor_status" -ne 0 ]; then
    if [ "$child_status" -ne 0 ]; then
      exit "$child_status"
    fi
    exit "$monitor_status"
  fi
  exit "$child_status"
fi

exec bitcoinII-d "$@"
