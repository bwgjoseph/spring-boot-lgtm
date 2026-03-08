package com.bwgjoseph.observability.api;

import io.micrometer.observation.annotation.Observed;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.concurrent.ExecutionException;

@Slf4j
@RestController
public class PokemonController {
    private final PokemonAPI pokemonAPI;

    public PokemonController(PokemonAPI pokemonAPI) {
        this.pokemonAPI = pokemonAPI;
    }

    @GetMapping("/trace")
    public String trace() {
        return "trace";
    }

    @Observed(name = "pokemon.controller", contextualName = "get-pokemon")
    @GetMapping("/pokemon/{id}")
    public Pokemon get(@PathVariable String id) {
        log.info("Controller received request for ID: {}", id);
        Pokemon ditto = this.pokemonAPI.getPokemon(id);

        return new Pokemon(ditto.id(), ditto.name(), ditto.baseExperience());
    }
}
