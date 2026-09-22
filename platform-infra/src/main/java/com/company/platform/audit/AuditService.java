package com.company.platform.audit;

import com.company.platform.common.web.ClientContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.UUID;

/**
 * Persists security events in their own transaction so they survive a rollback of the calling operation
 * (a failed login must still be recorded). Audit failures are logged, not propagated, so an audit outage
 * does not take authentication down with it.
 */
@Service
public class AuditService {
    private static final Logger log = LoggerFactory.getLogger("AUDIT");

    private final AuditEventRepository events;
    private final TransactionTemplate tx;

    public AuditService(AuditEventRepository events, PlatformTransactionManager txManager) {
        this.events = events;
        this.tx = new TransactionTemplate(txManager);
        this.tx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    public void record(AuditEventType type, UUID userId, String subject, ClientContext client, String details) {
        String ip = client != null ? client.ip() : null;
        String ua = client != null ? client.userAgent() : null;
        log.info("event={} userId={} subject={} ip={} details={}", type, userId, subject, ip, details);
        try {
            tx.executeWithoutResult(s -> events.save(new AuditEvent(type, userId, subject, ip, ua, details)));
        } catch (RuntimeException e) {
            log.error("Failed to persist audit event {}", type, e);
        }
    }
}
