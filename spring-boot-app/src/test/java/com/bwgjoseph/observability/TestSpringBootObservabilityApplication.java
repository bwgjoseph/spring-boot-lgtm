package com.bwgjoseph.observability;

import org.springframework.boot.SpringApplication;

public class TestSpringBootObservabilityApplication {

	public static void main(String[] args) {
		SpringApplication.from(SpringBootObservabilityApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
