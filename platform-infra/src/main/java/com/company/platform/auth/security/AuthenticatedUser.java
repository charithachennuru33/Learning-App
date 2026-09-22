package com.company.platform.auth.security;

import java.util.UUID;

/** Security principal for requests carrying a valid access token. Inject with {@code @AuthenticationPrincipal}. */
public record AuthenticatedUser(UUID id) {
    @Override
    public String toString() { return id.toString(); }
}
