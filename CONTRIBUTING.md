# Contributing

The CLI is maintained independently of [ta4j/ta4j](https://github.com/ta4j/ta4j). This repository owns command parsing, local workflow composition, output/error contracts, executable packaging, and the performance runner. Numerical behavior and reusable data, charting, and catalog implementations belong in the upstream libraries. Read [AGENTS.md](AGENTS.md) and [JAVA_REVIEW.md](JAVA_REVIEW.md) before Java or test changes.

## Environment and dependencies

Use JDK 25 and the included Maven Wrapper. Later JDKs are not a qualified build baseline for the pinned JaCoCo/SpotBugs toolchain. The CLI is `org.ta4j:ta4j-cli:1.0.0-SNAPSHOT`; the four upstream dependencies are explicitly pinned to `0.27.1-SNAPSHOT`. They are a source prerequisite, not a released-support claim. Follow the [README bootstrap](README.md#build-and-compatibility) when those artifacts are not already installed/published. The bootstrap installs their parent POM as well and records the resolved source commit when `TA4J_SOURCE_EVIDENCE_FILE` is set.

Do not add parent-relative paths, an examples dependency, a core test JAR, or a required native provider. Shared `ta4jexamples.*` packages retain their upstream namespace; do not copy their production implementations into the CLI. Tests use the two explicitly owned files under `fixtures/`, ordinary published core builders, and a local test-only log capture.

## Maven-native checks

Run from this repository root:

```bash
# Focused iteration; no reactor selectors or clean are required.
./mvnw -Dtest=Ta4jCliTest test

# Apply the inherited MIT header and Eclipse formatter, then run all checks.
bash scripts/run-full-build-quiet.sh

# Non-mutating final/CI gate.
QUIET_BUILD_TIMEOUT_SECONDS=1200 bash scripts/run-full-build-quiet.sh --validate-only
```

PowerShell 7+ supports the same wrapper options via `./scripts/run-full-build-quiet.ps1`; direct Maven commands use `./mvnw.cmd` on Windows. `--goals "<goals>" -- <Maven arguments>` is available for focused diagnostics, not a substitute for the full final gate. The timeout defaults to 180 seconds; zero disables it. Heartbeats default to 30 seconds. A timeout exits 124 and terminates the Maven process tree.

The POM binds actual checks to `verify`: license headers, Spotless, SpotBugs, unit tests, and native JaCoCo reports/checks. The 80% line/branch coverage target is advisory, matching the source project's policy; `BUILD SUCCESS` alone does not establish that threshold was met. Default exclusions retain benchmark, integration/analysis demos, hardware- and display-qualified tags. The explicitly tagged performance-runner test also requires its existing system property before it runs. Do not globally enable test parallelism or remove cases/tags merely to obtain a faster gate.

Evidence is retained in `.agents/logs/`, `target/surefire-reports/`, `target/site/jacoco/`, and `target/spotbugsXml.xml`. Distinguish configured checks from checks actually executed and passed. Retain full reports before running a new clean gate. Never describe an unexecuted gate, a failed timeout, or advisory coverage as passed evidence.

## Behavioral proof

Keep tests in the 1:1 owner test class. Test changes to command results, error categories/exit codes, numerical serialization, path-collision safety, stdin handling, and reproducible output directly through the real CLI/library APIs. New test methods are public. New test fixtures must be deterministic and independent of sibling checkouts or network data. Do not add source-text, manifest-string, or POM-regex tests as a proxy for runtime behavior.

CI uses the same explicit prerequisite bootstrap and full non-mutating gate on Linux and Windows, then runs the packaged executable through catalog discovery, CSV backtest with a headless JPEG, and JSON indicator input. Optional native providers are not installed or qualified by this repository.

Use conventional commits and describe exercised commands, exact heads/prerequisite commits, results, and any missing evidence in the pull request. Update [CHANGELOG.md](CHANGELOG.md) for user-facing changes and the relevant guide whenever usage or compatibility changes. Obtain human approval before merges or default-branch pushes; do not squash away the extraction/source provenance.
