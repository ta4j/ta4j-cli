# CLI operations

## Build provenance and compatibility

`1.0.0-SNAPSHOT` uses JDK 25 as its build/quality-tool baseline and exactly `0.27.1-SNAPSHOT` of `ta4j-core`, `ta4j-data`, `ta4j-charting`, and `ta4j-catalog`. Shared-module extraction is currently an explicit upstream source prerequisite. No older release or GPU execution is qualified here.

For an isolated checkout without installed artifacts:

```bash
TA4J_SOURCE_EVIDENCE_FILE=.agents/logs/ta4j-prerequisite-source.txt \
  bash scripts/install-ta4j-prerequisites.sh --ref <upstream-commit-containing-the-shared-modules>
QUIET_BUILD_TIMEOUT_SECONDS=1200 bash scripts/run-full-build-quiet.sh --validate-only
```

Omit `--ref` to use `.github/ta4j-source-ref`, or set `TA4J_SOURCE_REF`. `--ref` wins over the environment, which wins over the checked-in file. `TA4J_SOURCE_REPOSITORY` defaults to `ta4j/ta4j` and accepts an explicit GitHub owner/repository. The bootstrap fetches and builds an isolated temporary source checkout, prints its immutable commit, and optionally records repository/requested ref/commit in the evidence file. It does not depend on a neighboring checkout. Forward a non-default local Maven repository with `-- -Dmaven.repo.local=<path>` and use that same repository for the subsequent CLI build.

GitHub CI follows this bootstrap before the independent CLI build. The workflow-dispatch source-ref input is an explicit override; normal builds use the checked-in file. Bind that file to a published immutable prerequisite commit before presenting an exact-head integration result. When a compatible upstream release becomes available, deliberately update the pinned versions and compatibility documentation rather than relying on whichever SNAPSHOT happens to exist locally.

## Packaged invocation

The executable is `target/ta4j-cli-1.0.0-SNAPSHOT-jar-with-dependencies.jar`. Use the complete filename on every platform; PowerShell does not expand a Java argument's wildcard like Bash does.

```bash
java -jar target/ta4j-cli-1.0.0-SNAPSHOT-jar-with-dependencies.jar --version
java -jar target/ta4j-cli-1.0.0-SNAPSHOT-jar-with-dependencies.jar catalog > target/catalog.json
java -Djava.awt.headless=true -jar target/ta4j-cli-1.0.0-SNAPSHOT-jar-with-dependencies.jar \
  strategy backtest \
  --data-file fixtures/AAPL-PT1D-20130102_20131231.csv \
  --strategy 'SMA(7,21)' \
  --output target/backtest.json \
  --chart target/backtest.jpg \
  --reproducible --error-format JSON
```

`catalog` emits JSON directly to stdout; unlike backtest workflows, it does not accept `--output` or `--reproducible`. Charts are opt-in JPEG files and do not open a display. The CSV and JSON fixtures are fixed owned demo/regression inputs, not live feeds. Keep real input files and output destinations separate; the CLI rejects collisions, including symlink aliases. No CLI command requires the main ta4j repository's dataset paths.

Use stdin explicitly as `--data-file - --data-format csv` or `json`. The CLI remains local-file-first; it is not a broker connection, service daemon, or data downloader. The shared artifact packages have intentionally retained `ta4jexamples.*` names, but no examples runtime artifact is required.

## Automation and failure handling

Use `--error-format JSON` for a single structured error envelope on stderr. Use `--reproducible` on workflows that expose it to omit volatile run metadata. Stdout is reserved for command output; `--output` writes the workflow response to the selected file instead. Do not discard a non-zero exit just because a diagnostic response file exists.

- Exit 0: the workflow completed; inspect `status` for an explicitly requested partial result.
- Exit 2: usage/validation failure, including malformed input and unsupported parameter combinations.
- Exit 74: unreadable input or another I/O failure.
- Exit 1: execution/software failure, including an all-failed batch or a rejected performance-comparison gate.

Batch execution does not silently ignore invalid input: opt into `--invalid-input skip` only when a partial result is acceptable. An all-failed execution still records available per-member failures and exits non-zero. Bounds on sweep size, forecast work, and performance measurements are part of the CLI contract, not performance promises.

## Performance comparisons

`scripts/benchmark-performance-experiment.sh` compares two **standalone CLI** Git refs. Both must contain root `pom.xml` and the prerequisite bootstrap. It builds two temporary worktrees with separate local Maven repositories and installs each side's explicit upstream source ref before either measurement. Temporary worktrees/repositories are removed; native build failures propagate and generated measurement/comparison artifacts remain in the selected output directory.

For an upstream library comparison with one CLI harness, point both CLI refs at the same CLI commit and use `BENCHMARK_BASE_TA4J_REF` and `BENCHMARK_CANDIDATE_TA4J_REF`. The resolved upstream commits are recorded beside the base/candidate artifacts. `BENCHMARK_ORDER=base-first` is the default; repeat borderline results with `candidate-first`. Preserve the order file, source evidence, checksums, host/JVM metadata, and comparison JSON. The Kalman experiment synthesizes deterministic input internally; it does not read a main-repository dataset.

## Troubleshooting

- Missing `org.ta4j` artifacts or parent POM: bootstrap the explicitly configured source revision into the same local Maven repository. A revision without all shared modules is incompatible, even if its version string matches.
- Compiler release 25 or enforcer failure: select JDK 25 and rerun with the repository wrapper. Later JDKs can exceed the pinned JaCoCo/SpotBugs class-file support even when the compiler target is 25.
- Gate timeout: inspect the retained `.agents/logs/` output; exit 124 is not success. Increase the explicit timeout for cold dependency resolution rather than skipping checks. All unit-test and coverage evidence comes from native Maven reports.
- Missing JPEG: inspect the command's error envelope, ensure the destination is writable, and use `-Djava.awt.headless=true` for displayless operation.
- Provider/driver errors in separate native library use: follow the upstream acceleration artifact's installation and hardware qualification instructions. This CLI bundles no acceleration provider and does not claim to accelerate its scalar commands.
