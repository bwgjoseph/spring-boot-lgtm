package com.bwgjoseph.observability.api;

import com.mongodb.client.MongoCollection;
import io.micrometer.tracing.annotation.NewSpan;
import lombok.extern.slf4j.Slf4j;
import org.bson.Document;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.mongodb.core.MongoOperations;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.concurrent.ExecutionException;

@Slf4j
@Service
public class PokemonAPI {
    private final RestClient restClient;

    public PokemonAPI(RestClient.Builder builder) {
        this.restClient = builder.baseUrl("https://pokeapi.co/api/v2/pokemon/").build();
    }

    public Pokemon getPokemon(String pokemonId) {
        Pokemon pokemon = this.restClient.get().uri("/{id}", pokemonId).retrieve().toEntity(Pokemon.class).getBody();

        log.info("{}", pokemon);

        return pokemon;
    }
}
