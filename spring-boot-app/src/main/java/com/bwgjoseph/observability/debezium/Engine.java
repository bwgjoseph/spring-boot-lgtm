package com.bwgjoseph.observability.debezium;

import io.debezium.config.Configuration;
import io.debezium.embedded.Connect;
import io.debezium.engine.DebeziumEngine;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@Slf4j
@Component
@ConditionalOnProperty(name = "debezium.enabled", havingValue = "true", matchIfMissing = true)
public class Engine {

    private final ExecutorService executor;
    private final DebeziumEngine<?> engine;

    public Engine(Configuration mongodbConnector) {
        this.executor = Executors.newSingleThreadExecutor();
        this.engine = DebeziumEngine.create(Connect.class)
                .using(mongodbConnector.asProperties())
                .notifying(record -> {
                    String eventContent = record.value().toString();
                    if (eventContent.contains("last_test_id")) {
                        log.info("CDC Event captured: {}", eventContent);
                    }
                    log.debug("Received Change Event: {}", record);
                })
                .build();
    }

    @PostConstruct
    public void start() {
        log.info("Starting Debezium Embedded Engine...");
        executor.execute(engine);
    }

    @PreDestroy
    public void stop() throws IOException {
        if (this.engine != null) {
            log.info("Stopping Debezium Embedded Engine...");
            this.engine.close();
        }
        executor.shutdown();
    }
}
