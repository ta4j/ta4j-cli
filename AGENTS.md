# AGENTS instructions for ta4j-cli

## 1) Scope and ownership

- Work from this standalone repository root. Read `JAVA_REVIEW.md` before Java, API, or test changes.
- Reuse published ta4j APIs. Core numerical behavior belongs in `ta4j-core`; reusable loading, charts, and catalogs belong in upstream `ta4j-data`, `ta4j-charting`, and `ta4j-catalog`.
- Keep the existing `ta4jexamples.*` dependency namespaces. Do not add an examples production dependency, a ta4j parent/relativePath, a core internal test JAR, copied library implementations, or a mandatory native provider.
- CLI versioning is independent: current CLI `1.0.0-SNAPSHOT`, pinned upstream `0.27.1-SNAPSHOT`, JDK 25 build/quality-tool baseline.

## 2) Safety and compatibility

- Preserve local-file-first operation, JSON/error envelopes and exit codes, reproducible output, work bounds, path-collision protection, and headless chart saving.
- Tests and documentation use intentional owned fixtures under `fixtures/`; do not assume a sibling ta4j checkout, its target directories, or local unpublished artifacts.
- Prerequisite setup uses `scripts/install-ta4j-prerequisites.sh` and the explicit ref in `.github/ta4j-source-ref`. Record the resolved commit; unmerged SNAPSHOT prerequisites are not released compatibility or GPU qualification.
- Do not commit, push branches, open/merge PRs, or mutate the default branch without the applicable human authorization.

## 3) Building and iteration

- Use the repository Maven Wrapper from the root. Install/bootstrap the explicit upstream prerequisite before building an isolated checkout.
- Focused iteration: `./mvnw -Dtest=<OwnerTest> test`, without `clean` or reactor selectors.
- Preserve MIT headers, the inherited Eclipse formatter, explicit local types, and CLI-owned `@since 1.0.0` versioning.
- Put tests in the 1:1 mapped owner class. New unit/integration test methods are public. Use ordinary published core builders and minimal local test-only fixtures instead of upstream mocks or test JARs.

## 4) Completion evidence

- Final non-mutating gate: `bash scripts/run-full-build-quiet.sh --validate-only`; PowerShell 7+: `./scripts/run-full-build-quiet.ps1 --validate-only`. Cold builds may set `QUIET_BUILD_TIMEOUT_SECONDS=1200` explicitly.
- Default wrapper mode applies license/format fixes before the same Maven `verify` gate. The gate runs actual tests, license/Spotless checks, SpotBugs, and JaCoCo; it does not replace these with source-text checks. Keep coverage-target warnings advisory unless an approved policy change says otherwise.
- Delegated editing workers must not run builds/tests/linters/formatters mid-flight; the integration owner runs the final gate once after all slices land.
- Report only exercised evidence. Keep full logs/native reports and exact prerequisite commits. A successful reactor result alone does not prove the coverage target or native acceleration.

## 5) Documentation

- Update `CHANGELOG.md` under Unreleased for permanent user-facing changes; isolate breaking changes with migration guidance.
- Update README/operator usage with compatibility and prerequisite changes. Preserve the extraction provenance in `NOTICE`, `LICENSE`, and `AUTHORS`.
- Do not add permanent source-string/regex tests for POM, scripts, or workflow wiring; use actual Maven and runtime behavior as proof.
