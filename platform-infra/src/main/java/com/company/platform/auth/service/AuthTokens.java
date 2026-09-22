package com.company.platform.auth.service;

import java.time.Instant;
import java.util.UUID;

public record AuthTokens(UUID userId, String accessToken, Instant accessTokenExpiresAt,
                         String refreshToken, Instant refreshTokenExpiresAt) {}
