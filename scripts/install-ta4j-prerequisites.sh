#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_repository="${TA4J_SOURCE_REPOSITORY:-ta4j/ta4j}"
source_ref="${TA4J_SOURCE_REF:-}"
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: scripts/install-ta4j-prerequisites.sh [--ref <source-ref>] [-- Maven arguments...]

Fetch the configured ta4j repository/ref into a temporary isolated checkout and
install ta4j-core, ta4j-data, ta4j-charting and ta4j-catalog plus their parent.
No existing ta4j checkout or published SNAPSHOT is assumed. Maven runs the
upstream default tests and verification; no native provider is selected.

TA4J_SOURCE_REPOSITORY defaults to ta4j/ta4j (GitHub owner/repository).
TA4J_SOURCE_REF overrides .github/ta4j-source-ref; --ref takes precedence.
TA4J_SOURCE_EVIDENCE_FILE optionally records the resolved immutable commit.
USAGE
  exit 0
fi
if [[ "${1:-}" == "--ref" ]]; then
  [[ -n "${2:-}" ]] || { echo 'error: --ref requires a source ref' >&2; exit 2; }
  source_ref="$2"
  shift 2
fi
if [[ "${1:-}" == "--" ]]; then
  shift
fi
if [[ -z "$source_ref" ]]; then
  IFS= read -r source_ref < "$repo_root/.github/ta4j-source-ref"
fi
if [[ ! "$source_repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ || -z "$source_ref" || "$source_ref" == -* ]]; then
  echo 'error: use a GitHub owner/repository and a non-empty source ref (not an option)' >&2
  exit 2
fi
checkout="$(mktemp -d "${TMPDIR:-/tmp}/ta4j-cli-prerequisites.XXXXXX")"
trap 'rm -rf "$checkout"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$checkout" init --quiet
git -C "$checkout" remote add origin "https://github.com/$source_repository.git"
git -C "$checkout" fetch --depth=1 origin "$source_ref"
git -C "$checkout" checkout --quiet --detach FETCH_HEAD
source_commit="$(git -C "$checkout" rev-parse HEAD)"
printf 'ta4j prerequisite: %s@%s (requested %s)\n' "$source_repository" "$source_commit" "$source_ref"
if [[ -n "${TA4J_SOURCE_EVIDENCE_FILE:-}" ]]; then
  mkdir -p "$(dirname "$TA4J_SOURCE_EVIDENCE_FILE")"
  printf 'repository=%s\nrequestedRef=%s\ncommit=%s\n' "$source_repository" "$source_ref" "$source_commit" > "$TA4J_SOURCE_EVIDENCE_FILE"
fi
for module in ta4j-core ta4j-data ta4j-charting ta4j-catalog; do
  if [[ ! -f "$checkout/$module/pom.xml" ]]; then
    printf 'error: %s@%s lacks %s; select a revision containing the shared-library extraction\n' \
      "$source_repository" "$source_commit" "$module" >&2
    exit 1
  fi
done
(
  cd "$checkout"
  ./mvnw -B -ntp -pl ta4j-core,ta4j-data,ta4j-charting,ta4j-catalog -am install "$@"
)
