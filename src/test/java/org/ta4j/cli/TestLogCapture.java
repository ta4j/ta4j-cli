/*
 * SPDX-License-Identifier: MIT
 */
package org.ta4j.cli;

import java.io.StringWriter;
import java.util.ArrayList;
import java.util.List;

import org.apache.logging.log4j.Level;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.core.Appender;
import org.apache.logging.log4j.core.LoggerContext;
import org.apache.logging.log4j.core.appender.WriterAppender;
import org.apache.logging.log4j.core.config.LoggerConfig;
import org.apache.logging.log4j.core.layout.PatternLayout;

/**
 * Captures expected diagnostics without depending on ta4j's internal test JAR.
 */
final class TestLogCapture implements AutoCloseable {

    private final StringWriter output = new StringWriter();
    private final List<Appender> detachedAppenders = new ArrayList<>();
    private LoggerContext context;
    private LoggerConfig root;
    private Level originalLevel;
    private Appender appender;

    void open() {
        context = (LoggerContext) LogManager.getContext(false);
        root = context.getConfiguration().getRootLogger();
        originalLevel = root.getLevel();
        detachedAppenders.addAll(root.getAppenders().values());
        for (Appender existing : detachedAppenders) {
            root.removeAppender(existing.getName());
        }
        appender = WriterAppender.newBuilder()
                .setTarget(output)
                .setLayout(PatternLayout.newBuilder().withPattern("%msg%n").build())
                .setName("CliTestCapture")
                .build();
        appender.start();
        root.setLevel(Level.TRACE);
        root.addAppender(appender, Level.TRACE, null);
        context.updateLoggers();
    }

    String getLogOutput() {
        return output.toString();
    }

    @Override
    public void close() {
        if (context == null) {
            return;
        }
        root.removeAppender(appender.getName());
        appender.stop();
        for (Appender existing : detachedAppenders) {
            root.addAppender(existing, null, null);
        }
        detachedAppenders.clear();
        root.setLevel(originalLevel);
        context.updateLoggers();
        context = null;
    }

    @Override
    public String toString() {
        return output.toString();
    }
}
