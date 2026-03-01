package com.bwgjoseph.observability.api;

import io.micrometer.observation.Observation;
import io.micrometer.observation.ObservationRegistry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Slf4j
@Service
public class PokemonAPI {
    private final RestClient restClient;
    private final ObservationRegistry observationRegistry;

    public PokemonAPI(RestClient.Builder builder, ObservationRegistry observationRegistry) {
        this.restClient = builder.baseUrl("https://pokeapi.co/api/v2/pokemon/").build();
        this.observationRegistry = observationRegistry;
    }

    public Pokemon getPokemon(String pokemonId) {
        // Manual Observation to capture business-specific metrics/traces for "pokemon.lookup"
        return Observation.createNotStarted("pokemon.lookup", observationRegistry)
                .contextualName("fetch-pokemon-" + pokemonId)
                .lowCardinalityKeyValue("pokemon.id", pokemonId)
                .observe(() -> {
                    log.info("Fetching Pokemon with ID: {}", pokemonId);
                    
                    Pokemon pokemon = this.restClient.get()
                            .uri("/{id}", pokemonId)
                            .retrieve()
                            .toEntity(Pokemon.class)
                            .getBody();

                    log.info("Successfully fetched: {}", pokemon);
                    return pokemon;
                });
    }
}

