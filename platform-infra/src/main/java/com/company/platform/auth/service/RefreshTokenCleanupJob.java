package com.company.platform.auth.service;

import com.company.platform.auth.domain.RefreshTokenRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;

/**
 * Deletes refresh tokens that expired over a week ago. Expired rows are kept briefly so reuse of a just-expired
 * token can still be traced. Safe to run on every instance at once: the delete is idempotent.
 */
@Component
public class RefreshTokenCleanupJob {
    private static final Logger log = LoggerFactory.getLogger(RefreshTokenCleanupJob.class);
    private static final Duration RETENTION = Duration.ofDays(7);

    private final RefreshTokenRepository tokens;

    public RefreshTokenCleanupJob(RefreshTokenRepository tokens) { this.tokens = tokens; }

    @Scheduled(cron = "${platform.auth.refresh-token.cleanup-cron:0 30 3 * * *}")
    @Transactional
    public void purgeExpired() {
        int deleted = tokens.deleteExpiredBefore(Instant.now().minus(RETENTION));
        if (deleted > 0) log.info("Purged {} expired refresh tokens", deleted);
    }
}
