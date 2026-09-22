package com.company.platform.audit;

import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "auth_audit_event")
public class AuditEvent {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(name = "event_type", nullable = false, length = 64)
    private AuditEventType type;

    @Column(name = "user_id")
    private UUID userId;

    /** Masked identifier of the subject (e.g. phone), never the raw value. */
    @Column(length = 64)
    private String subject;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "user_agent", length = 255)
    private String userAgent;

    @Column(length = 500)
    private String details;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected AuditEvent() {}

    public AuditEvent(AuditEventType type, UUID userId, String subject, String ipAddress, String userAgent,
                      String details) {
        this.type = type;
        this.userId = userId;
        this.subject = subject;
        this.ipAddress = ipAddress;
        this.userAgent = userAgent;
        this.details = details != null && details.length() > 500 ? details.substring(0, 500) : details;
        this.createdAt = Instant.now();
    }

    public UUID getId() { return id; }
    public AuditEventType getType() { return type; }
    public UUID getUserId() { return userId; }
    public String getSubject() { return subject; }
    public String getIpAddress() { return ipAddress; }
    public String getUserAgent() { return userAgent; }
    public String getDetails() { return details; }
    public Instant getCreatedAt() { return createdAt; }
}
