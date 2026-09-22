package com.company.platform.auth.security;

import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtServiceTest {
    private static final String SECRET = "test-secret-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    private static final String OLD_SECRET = "old-secret-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    private static final Instant NOW = Instant.parse("2026-01-01T10:00:00Z");

    private static JwtProperties props(String secret, List<String> previous) {
        return new JwtProperties("platform-infra", "platform-clients", secret, previous,
                Duration.ofMinutes(15), Duration.ofSeconds(30));
    }

    private static JwtService at(JwtProperties props, Instant instant) {
        return new JwtService(props, Clock.fixed(instant, ZoneOffset.UTC));
    }

    @Test
    void roundTripsUserId() {
        var service = at(props(SECRET, List.of()), NOW);
        UUID userId = UUID.randomUUID();
        var token = service.createAccessToken(userId);
        assertThat(token.expiresAt()).isEqualTo(NOW.plus(Duration.ofMinutes(15)));
        assertThat(service.parseUserId(token.value())).isEqualTo(userId);
    }

    @Test
    void rejectsExpiredTokenBeyondClockSkew() {
        String token = at(props(SECRET, List.of()), NOW).createAccessToken(UUID.randomUUID()).value();
        var later = at(props(SECRET, List.of()), NOW.plus(Duration.ofMinutes(16)));
        assertThatThrownBy(() -> later.parseUserId(token)).isInstanceOf(JwtException.class);
    }

    @Test
    void rejectsTokenSignedWithUnknownKey() {
        String token = at(props(OLD_SECRET, List.of()), NOW).createAccessToken(UUID.randomUUID()).value();
        assertThatThrownBy(() -> at(props(SECRET, List.of()), NOW).parseUserId(token)).isInstanceOf(JwtException.class);
    }

    @Test
    void acceptsTokensFromPreviousKeyDuringRotation() {
        UUID userId = UUID.randomUUID();
        String token = at(props(OLD_SECRET, List.of()), NOW).createAccessToken(userId).value();
        var rotated = at(props(SECRET, List.of(OLD_SECRET)), NOW);
        assertThat(rotated.parseUserId(token)).isEqualTo(userId);
    }

    @Test
    void rejectsWrongAudienceOrMissingTokenType() {
        var key = Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8));
        var service = at(props(SECRET, List.of()), NOW);
        String kid = keyId(SECRET);

        String wrongAudience = Jwts.builder().header().keyId(kid).and()
                .issuer("platform-infra").audience().add("someone-else").and()
                .subject(UUID.randomUUID().toString()).claim("token_type", "access")
                .expiration(Date.from(NOW.plusSeconds(60))).signWith(key).compact();
        String noType = Jwts.builder().header().keyId(kid).and()
                .issuer("platform-infra").audience().add("platform-clients").and()
                .subject(UUID.randomUUID().toString())
                .expiration(Date.from(NOW.plusSeconds(60))).signWith(key).compact();

        assertThatThrownBy(() -> service.parseUserId(wrongAudience)).isInstanceOf(JwtException.class);
        assertThatThrownBy(() -> service.parseUserId(noType)).isInstanceOf(JwtException.class);
    }

    private static String keyId(String secret) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(secret.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest, 0, 8);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    @Test
    void refusesShortSecrets() {
        assertThatThrownBy(() -> new JwtService(props("too-short", List.of())))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("at least 32 bytes");
        assertThatThrownBy(() -> new JwtService(props("${JWT_SECRET}", List.of())))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("is not set");
    }
}
