package com.company.platform.auth.security;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;
import java.util.List;

/**
 * HS256 signing configuration. To rotate keys without logging everyone out: move the current secret into
 * {@code previous-secrets}, set a new {@code secret}, deploy, and drop the old one after one access-token TTL.
 */
@Validated
@ConfigurationProperties("security.jwt")
public record JwtProperties(
        @NotBlank String issuer,
        @NotBlank String audience,
        @NotBlank String secret,
        List<String> previousSecrets,
        @NotNull Duration accessTokenTtl,
        @NotNull Duration clockSkew) {

    public JwtProperties {
        previousSecrets = previousSecrets == null ? List.of()
                : previousSecrets.stream().filter(s -> s != null && !s.isBlank()).toList();
    }
}
