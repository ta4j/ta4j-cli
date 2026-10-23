#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validate_only=false
custom_goals=false
goals=(clean license:format spotless:apply verify)
maven_args=()
while (($#)); do
  case "$1" in
    --validate-only) validate_only=true; shift ;;
    --goals)
      [[ -n "${2:-}" ]] || { echo 'error: --goals requires a value' >&2; exit 2; }
      read -r -a goals <<< "$2"
      custom_goals=true
      shift 2
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/run-full-build-quiet.sh [--validate-only] [--goals "goals..."] [-- Maven arguments...]
Default: clean license:format spotless:apply verify.
--validate-only: clean verify (Maven verify binds license/format checks, SpotBugs,
unit tests and JaCoCo reporting). --goals runs an explicit focused Maven goal set.
QUIET_BUILD_TIMEOUT_SECONDS defaults to 180; 0 disables the timeout.
QUIET_BUILD_HEARTBEAT_SECONDS defaults to 30.
Full Maven output is retained under .agents/logs/; WARN/ERROR lines and the final
elapsed time, test totals and available coverage are printed to stdout.
USAGE
      exit 0
      ;;
    --) shift; maven_args+=("$@"); break ;;
    *) maven_args+=("$1"); shift ;;
  esac
done
if [[ "$validate_only" == true && "$custom_goals" == true ]]; then
  echo 'error: --validate-only cannot be combined with --goals' >&2
  exit 2
fi
if [[ "$validate_only" == true ]]; then
  goals=(clean verify)
fi
timeout_seconds="${QUIET_BUILD_TIMEOUT_SECONDS:-180}"
heartbeat_seconds="${QUIET_BUILD_HEARTBEAT_SECONDS:-30}"
if [[ ! "$timeout_seconds" =~ ^[0-9]+$ || ! "$heartbeat_seconds" =~ ^[1-9][0-9]*$ ]]; then
  echo 'error: timeout must be non-negative and heartbeat must be positive integer seconds' >&2
  exit 2
fi
mkdir -p "$repo_root/.agents/logs"
log_file="$(mktemp "$repo_root/.agents/logs/full-build-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
start_time="$(date +%s)"
build_pid=''
cleanup() {
  if [[ -n "$build_pid" ]] && kill -0 "$build_pid" 2>/dev/null; then
    kill -TERM -- "-$build_pid" 2>/dev/null || true
    sleep 1
    kill -KILL -- "-$build_pid" 2>/dev/null || true
    wait "$build_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
cd "$repo_root"
printf 'Maven goals: %s\n' "${goals[*]}" >> "$log_file"
# Job control gives Maven and its children their own process group so timeout
# termination does not leave a Surefire JVM running after the gate exits.
set -m
./mvnw -B -ntp -Dstyle.color=never "${goals[@]}" "${maven_args[@]}" >> "$log_file" 2>&1 &
build_pid=$!
set +m
last_heartbeat="$start_time"
timed_out=false
while kill -0 "$build_pid" 2>/dev/null; do
  now="$(date +%s)"
  elapsed=$((now - start_time))
  if ((timeout_seconds > 0 && elapsed >= timeout_seconds)); then
    timed_out=true
    cleanup
    break
  fi
  if ((now - last_heartbeat >= heartbeat_seconds)); then
    printf '[WARN] quiet build still running after %ss; log: %s\n' "$elapsed" "$log_file"
    last_heartbeat="$now"
  fi
  sleep 1
done
if [[ "$timed_out" == true ]]; then
  status=124
else
  set +e
  wait "$build_pid"
  status=$?
  set -e
fi
build_pid=''
awk '/\[(WARNING|WARN|ERROR)\]/ || /(^|[[:space:]])(WARN|WARNING|ERROR|FATAL)([[:space:]:]|$)/ { print }' "$log_file"
awk '
  /^\[(INFO|WARNING)\] Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+, Skipped: [0-9]+[[:space:]]*$/ {
    run += $4; failures += $6; errors += $8; skipped += $10; found = 1
  }
  END { if (found) printf "Tests run: %d, Failures: %d, Errors: %d, Skipped: %d\n", run, failures, errors, skipped }
' "$log_file"
coverage_file="$repo_root/target/site/jacoco/jacoco.csv"
if [[ -f "$coverage_file" ]]; then
  awk -F, 'NR > 1 { lm += $8; lc += $9; bm += $6; bc += $7 }
    END {
      if (lm + lc > 0) printf "Coverage: lines %.2f%% (%d/%d)", 100 * lc / (lm + lc), lc, lm + lc;
      if (bm + bc > 0) printf ", branches %.2f%% (%d/%d)", 100 * bc / (bm + bc), bc, bm + bc;
      if (lm + lc + bm + bc > 0) printf "\n";
    }' "$coverage_file"
fi
if [[ "$timed_out" == true ]]; then
  printf 'Build: timed out after %ss\n' "$timeout_seconds"
elif ((status == 0)); then
  printf 'Build: GREEN in %ss\n' "$(($(date +%s) - start_time))"
else
  printf 'Build: FAILED (Maven exit %s) in %ss\n' "$status" "$(($(date +%s) - start_time))"
fi
printf 'Log: %s\n' "$log_file"
exit "$status"
