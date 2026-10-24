package com.bwgjoseph.observability.api;

import io.micrometer.observation.annotation.Observed;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Slf4j
@Service
public class PokemonAPI {
    private final RestClient restClient;

    public PokemonAPI(RestClient.Builder builder) {
        this.restClient = builder.baseUrl("https://pokeapi.co/api/v2/pokemon/").build();
    }

    @Observed(name = "pokemon.lookup", contextualName = "fetch-pokemon")
    public Pokemon getPokemon(String pokemonId) {
        log.info("Fetching Pokemon with ID: {}", pokemonId);
        
        Pokemon pokemon = this.restClient.get()
                .uri("/{id}", pokemonId)
                .retrieve()
                .toEntity(Pokemon.class)
                .getBody();

        log.info("Successfully fetched: {}", pokemon);
        return pokemon;
    }
}

