# Changelog

## Unreleased

### Added

- Standalone `org.ta4j:ta4j-cli:1.0.0-SNAPSHOT` application with an independent Java 25/Maven build and executable dependency-inclusive JAR.
- Preserved local CSV/JSON strategy backtest, walk-forward, bounded SMA sweep, indicator/rule exploration, forecasting, catalog discovery, completion, and deterministic performance-experiment workflows from ta4j PR #1610.
- Explicit dependencies on `ta4j-core`, `ta4j-data`, `ta4j-charting`, and `ta4j-catalog` at `0.27.1-SNAPSHOT`, with isolated source-ref bootstrap while the shared artifacts remain unpublished.
- Owned regression/demo CSV and JSON fixtures, Maven-native quality checks, Unix/PowerShell quiet gates, and Linux/Windows CI with packaged scalar-workflow smoke coverage.

### Changed

- CLI ownership and release versioning move from the main ta4j reactor to [ta4j/ta4j-cli](https://github.com/ta4j/ta4j-cli). Existing `ta4jexamples.*` library package names remain unchanged in upstream shared artifacts.
- Performance comparisons now use two standalone CLI refs, independently bootstrapped upstream revisions, and isolated per-side Maven repositories, with immutable prerequisite-source evidence retained beside the comparison.

### Breaking

- Build and invoke from the standalone repository root: replace the former reactor command `./mvnw -pl ta4j-cli -am package` with `./mvnw package` after installing the pinned upstream artifacts. The executable is now `target/ta4j-cli-1.0.0-SNAPSHOT-jar-with-dependencies.jar`, not a main-repository `ta4j-cli/target/` path. CLI-owned `@since` versions start at `1.0.0`; command names, options, response schemas, and upstream numerical behavior are preserved.
