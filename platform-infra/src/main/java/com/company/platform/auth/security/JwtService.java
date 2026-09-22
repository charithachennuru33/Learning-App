package com.company.platform.auth.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.JwtParser;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.LocatorAdapter;
import io.jsonwebtoken.ProtectedHeader;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Instant;
import java.util.Date;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

@Service
public class JwtService {
    static final String TOKEN_TYPE_CLAIM = "token_type";
    static final String ACCESS = "access";
    private static final int MIN_SECRET_BYTES = 32;

    private final JwtProperties props;
    private final Clock clock;
    private final String activeKeyId;
    private final SecretKey signingKey;
    private final Map<String, SecretKey> verificationKeys = new LinkedHashMap<>();
    private final JwtParser parser;

    @Autowired
    public JwtService(JwtProperties props) { this(props, Clock.systemUTC()); }

    JwtService(JwtProperties props, Clock clock) {
        this.props = props;
        this.clock = clock;
        this.signingKey = toKey(props.secret(), "security.jwt.secret");
        this.activeKeyId = keyId(props.secret());
        verificationKeys.put(activeKeyId, signingKey);
        for (String previous : props.previousSecrets()) {
            verificationKeys.put(keyId(previous), toKey(previous, "security.jwt.previous-secrets"));
        }
        this.parser = Jwts.parser()
                .keyLocator(new LocatorAdapter<Key>() {
                    @Override
                    protected Key locate(ProtectedHeader header) {
                        SecretKey key = header.getKeyId() == null ? null : verificationKeys.get(header.getKeyId());
                        if (key == null) throw new JwtException("Unknown signing key");
                        return key;
                    }
                })
                .requireIssuer(props.issuer())
                .requireAudience(props.audience())
                .require(TOKEN_TYPE_CLAIM, ACCESS)
                .clockSkewSeconds(props.clockSkew().toSeconds())
                .clock(() -> Date.from(clock.instant()))
                .build();
    }

    public AccessToken createAccessToken(UUID userId) {
        Instant now = clock.instant();
        Instant expiresAt = now.plus(props.accessTokenTtl());
        String token = Jwts.builder()
                .header().keyId(activeKeyId).and()
                .id(UUID.randomUUID().toString())
                .issuer(props.issuer())
                .audience().add(props.audience()).and()
                .subject(userId.toString())
                .issuedAt(Date.from(now))
                .notBefore(Date.from(now))
                .expiration(Date.from(expiresAt))
                .claim(TOKEN_TYPE_CLAIM, ACCESS)
                .signWith(signingKey, Jwts.SIG.HS256)
                .compact();
        return new AccessToken(token, expiresAt);
    }

    /** @throws JwtException if the token is malformed, expired, not yet valid, or signed by an unknown key. */
    public UUID parseUserId(String token) {
        Claims claims = parser.parseSignedClaims(token).getPayload();
        try {
            return UUID.fromString(claims.getSubject());
        } catch (IllegalArgumentException | NullPointerException e) {
            throw new JwtException("Invalid subject");
        }
    }

    private static SecretKey toKey(String secret, String property) {
        // Spring binds an unresolved ${JWT_SECRET} as literal text rather than failing.
        if (secret.startsWith("${")) throw new IllegalStateException(property + " is not set (JWT_SECRET)");
        byte[] bytes = secret.getBytes(StandardCharsets.UTF_8);
        if (bytes.length < MIN_SECRET_BYTES) {
            throw new IllegalStateException(property + " must be at least " + MIN_SECRET_BYTES + " bytes");
        }
        return Keys.hmacShaKeyFor(bytes);
    }

    /** Non-reversible identifier so tokens name the key that signed them without exposing it. */
    private static String keyId(String secret) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(secret.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest, 0, 8);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    public record AccessToken(String value, Instant expiresAt) {}
}
