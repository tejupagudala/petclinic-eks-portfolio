package org.springframework.samples.petclinic.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class ObservabilityDemoServiceApplication {

    private static final Logger log =
        LoggerFactory.getLogger(ObservabilityDemoServiceApplication.class);

    public static void main(String[] args) {
        SpringApplication.run(ObservabilityDemoServiceApplication.class, args);
    }
    @GetMapping("/hello")
    public String hello() {
        return "Hello";
    }
}
