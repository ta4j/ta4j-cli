/*
 * SPDX-License-Identifier: MIT
 */
package org.ta4j.cli.performance;

import java.util.Map;

/**
 * A reusable performance scenario that can be run by
 * {@link PerformanceExperimentRunner}.
 *
 * <p>
 * Implementations should include setup, warmup-sensitive work, the measured
 * operation loop, and a deterministic checksum in {@link #measure(Context)} so
 * before/after comparisons can verify that the candidate exercised equivalent
 * behavior.
 *
 * @since 1.0.0
 */
interface PerformanceScenario {

    /**
     * Stable identifier used in CLI arguments and benchmark artifacts.
     *
     * @return scenario identifier
     * @since 1.0.0
     */
    String id();

    /**
     * Human-readable scenario description.
     *
     * @return scenario description
     * @since 1.0.0
     */
    String description();

    /**
     * Hypothesis this scenario is meant to validate.
     *
     * @return performance hypothesis
     * @since 1.0.0
     */
    String hypothesis();

    /**
     * Optional profiler hint emitted when the runner is invoked with
     * {@code --profile}.
     *
     * @return profiler hint or an empty string
     * @since 1.0.0
     */
    default String profileHint() {
        return "";
    }

    /**
     * Runs this scenario once.
     *
     * @param context run context
     * @return measured scenario result
     * @since 1.0.0
     */
    Measurement measure(Context context);

    /**
     * Immutable context for a single scenario execution.
     *
     * @param barCount   number of bars to construct or process
     * @param repetition one-based measured repetition, or zero for warmup
     * @param profile    whether profiler hints were requested
     * @since 1.0.0
     */
    record Context(int barCount, int repetition, boolean profile) {
        /**
         * Validates the requested bar count and repetition.
         *
         * @since 1.0.0
         */
        public Context {
            if (barCount <= 0) {
                throw new IllegalArgumentException("barCount must be positive");
            }
            if (repetition < 0) {
                throw new IllegalArgumentException("repetition must be non-negative");
            }
        }
    }

    /**
     * Result from one measured scenario execution.
     *
     * @param operations    logical operation count
     * @param durationNanos measured runtime in nanoseconds
     * @param checksum      deterministic checksum for parity checks
     * @param counters      optional scenario-specific counters
     * @since 1.0.0
     */
    record Measurement(long operations, long durationNanos, long checksum, Map<String, Long> counters) {
        /**
         * Validates counters and snapshots the supplied metadata.
         *
         * @since 1.0.0
         */
        public Measurement {
            if (operations < 0) {
                throw new IllegalArgumentException("operations must be non-negative");
            }
            if (durationNanos < 0) {
                throw new IllegalArgumentException("durationNanos must be non-negative");
            }
            counters = counters == null ? Map.of() : Map.copyOf(counters);
        }
    }
}
