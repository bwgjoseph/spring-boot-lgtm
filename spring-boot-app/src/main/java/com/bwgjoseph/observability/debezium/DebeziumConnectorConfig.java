package com.bwgjoseph.observability.debezium;

import io.debezium.config.CommonConnectorConfig;
import io.debezium.config.Configuration;
import io.debezium.connector.mongodb.MongoDbConnectorConfig;
import io.debezium.embedded.EmbeddedEngineConfig;
import org.springframework.context.annotation.Bean;

@org.springframework.context.annotation.Configuration
public class DebeziumConnectorConfig {
    // based off https://debezium.io/documentation/reference/2.2/connectors/mongodb.html#mongodb-connector-properties

    @Bean
    public Configuration mongodbConnector() {
        String connectionString = System.getenv("DEBEZIUM_MONGODB_CONNECTION_STRING");
        if (connectionString == null || connectionString.isEmpty()) {
            connectionString = "mongodb://admin:password@localhost:27017/source?authSource=admin&replicaSet=mgrs";
        }

        return Configuration.create()
                // engine properties
                .with(EmbeddedEngineConfig.ENGINE_NAME, "sbd-mongodb-cdc")
                .with(EmbeddedEngineConfig.CONNECTOR_CLASS, "io.debezium.connector.mongodb.MongoDbConnector")
                .with(EmbeddedEngineConfig.OFFSET_STORAGE, "org.apache.kafka.connect.storage.FileOffsetBackingStore")
                .with(EmbeddedEngineConfig.OFFSET_STORAGE_FILE_FILENAME, "offsets.dat")
                .with(EmbeddedEngineConfig.OFFSET_FLUSH_INTERVAL_MS, "60000")
                // connector specific properties
                .with(CommonConnectorConfig.TOPIC_PREFIX, "kx-connector")
                .with(CommonConnectorConfig.SNAPSHOT_DELAY_MS, "100")
                // .with(CommonConnectorConfig.SNAPSHOT_FETCH_SIZE, "0") // has default
                .with(CommonConnectorConfig.SCHEMA_NAME_ADJUSTMENT_MODE, "none") // has default
                .with(CommonConnectorConfig.EVENT_PROCESSING_FAILURE_HANDLING_MODE, CommonConnectorConfig.EventProcessingFailureHandlingMode.FAIL)
                // mongo connector specific properties
                .with(MongoDbConnectorConfig.CONNECTION_STRING, connectionString)
                .with(MongoDbConnectorConfig.SSL_ENABLED, "false") // default false
                // .with(MongoDbConnectorConfig.SSL_ALLOW_INVALID_HOSTNAMES, "false") // has default
                .with(MongoDbConnectorConfig.DATABASE_INCLUDE_LIST, "kx") // default empty
                // .with(MongoDbConnectorConfig.DATABASE_EXCLUDE_LIST, "") // has default
                // .with(MongoDbConnectorConfig.COLLECTION_INCLUDE_LIST, "") // has default
                // .with(MongoDbConnectorConfig.COLLECTION_EXCLUDE_LIST, "") // has default
//                 .with(MongoDbConnectorConfig.SNAPSHOT_MODE, "initial") // has default
//                .with(MongoDbConnectorConfig.CAPTURE_MODE, "change_streams_update_full_with_pre_image") // has default
                // .with(MongoDbConnectorConfig.FIELD_EXCLUDE_LIST, "") // has default
                // .with(MongoDbConnectorConfig.FIELD_RENAMES, "") // has default
                // .with(MongoDbConnectorConfig.SNAPSHOT_MAX_THREADS, "1") // has default
                // .with(MongoDbConnectorConfig.TOMBSTONES_ON_DELETE, "true") // has default
                .build();
    }
}