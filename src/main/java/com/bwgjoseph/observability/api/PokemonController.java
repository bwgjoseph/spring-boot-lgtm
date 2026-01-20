package com.bwgjoseph.observability.api;

import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
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

    @GetMapping("/pokemon")
    public Pokemon get() throws ExecutionException, InterruptedException {
        Pokemon ditto = this.pokemonAPI.getPokemon("ditto");

        return new Pokemon(ditto.id(), ditto.name(), ditto.baseExperience());
    }
}
