package com.company.platform.auth.service;

import com.company.platform.audit.AuditEventType;
import com.company.platform.audit.AuditService;
import com.company.platform.auth.config.AuthProperties;
import com.company.platform.auth.domain.RefreshToken;
import com.company.platform.auth.domain.RefreshTokenRepository;
import com.company.platform.auth.domain.User;
import com.company.platform.auth.domain.UserRepository;
import com.company.platform.auth.security.JwtService;
import com.company.platform.common.error.ApiException;
import com.company.platform.common.error.ErrorCode;
import com.company.platform.common.web.ClientContext;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;

/**
 * Opaque, rotating refresh tokens. Each refresh revokes the presented token and issues its successor.
 * Presenting an already-rotated token means it leaked (or two clients share it), so the whole family
 * is revoked and the user must log in again.
 */
@Service
public class TokenService {
    private static final SecureRandom RANDOM = new SecureRandom();

    private final RefreshTokenRepository tokens;
    private final UserRepository users;
    private final JwtService jwt;
    private final AuditService audit;
    private final AuthProperties.RefreshToken config;

    public TokenService(RefreshTokenRepository tokens, UserRepository users, JwtService jwt, AuditService audit,
                        AuthProperties props) {
        this.tokens = tokens;
        this.users = users;
        this.jwt = jwt;
        this.audit = audit;
        this.config = props.refreshToken();
    }

    @Transactional
    public AuthTokens issue(User user, ClientContext client) {
        return mint(user.getId(), UUID.randomUUID(), client).tokens();
    }

    // Revocations triggered while rejecting a token must still commit.
    @Transactional(noRollbackFor = ApiException.class)
    public AuthTokens refresh(String rawToken, ClientContext client) {
        Instant now = Instant.now();
        RefreshToken current = tokens.findByTokenHashForUpdate(hash(rawToken))
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_REFRESH_TOKEN));

        if (current.isRevoked()) {
            int revoked = tokens.revokeFamily(current.getFamilyId(), now);
            audit.record(AuditEventType.REFRESH_TOKEN_REUSE_DETECTED, current.getUserId(), null, client,
                    "family=" + current.getFamilyId() + " revoked=" + revoked);
            throw new ApiException(ErrorCode.INVALID_REFRESH_TOKEN);
        }
        if (current.isExpired(now)) throw new ApiException(ErrorCode.INVALID_REFRESH_TOKEN);

        User user = users.findById(current.getUserId())
                .orElseThrow(() -> new ApiException(ErrorCode.INVALID_REFRESH_TOKEN));
        if (!user.isActive()) {
            tokens.revokeAllForUser(user.getId(), now);
            throw new ApiException(ErrorCode.ACCOUNT_INACTIVE);
        }

        Minted next = mint(user.getId(), current.getFamilyId(), client);
        current.rotatedTo(next.entity().getId(), now);
        audit.record(AuditEventType.TOKEN_REFRESHED, user.getId(), null, client, null);
        return next.tokens();
    }

    /** Ends the session the token belongs to. Unknown tokens are ignored so logout never leaks token validity. */
    @Transactional
    public void revokeSession(String rawToken, ClientContext client) {
        tokens.findByTokenHash(hash(rawToken)).ifPresent(t -> {
            tokens.revokeFamily(t.getFamilyId(), Instant.now());
            audit.record(AuditEventType.LOGOUT, t.getUserId(), null, client, null);
        });
    }

    @Transactional
    public void revokeAllSessions(UUID userId, ClientContext client) {
        int revoked = tokens.revokeAllForUser(userId, Instant.now());
        audit.record(AuditEventType.LOGOUT_ALL_SESSIONS, userId, null, client, "revoked=" + revoked);
    }

    private Minted mint(UUID userId, UUID familyId, ClientContext client) {
        Instant now = Instant.now();
        String raw = newRawToken();
        RefreshToken entity = tokens.save(new RefreshToken(userId, familyId, hash(raw), now,
                now.plus(config.ttl()), client.ip(), client.userAgent()));
        JwtService.AccessToken access = jwt.createAccessToken(userId);
        return new Minted(entity, new AuthTokens(userId, access.value(), access.expiresAt(), raw, entity.getExpiresAt()));
    }

    private static String newRawToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /** Tokens carry 256 bits of entropy, so a plain SHA-256 is enough; no salt or slow hash needed. */
    static String hash(String rawToken) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(rawToken.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private record Minted(RefreshToken entity, AuthTokens tokens) {}
}
