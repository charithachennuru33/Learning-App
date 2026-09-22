package com.company.platform.auth.domain;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name="platform_user")
public class User {
    @Id @GeneratedValue(strategy=GenerationType.UUID)
    private UUID id;

    @Column(unique=true, length=320)
    private String email;

    /** E.164 formatted, e.g. +919876543210. */
    @Column(unique=true, length=32)
    private String phone;

    @Enumerated(EnumType.STRING)
    @Column(nullable=false, length=32)
    private UserStatus status = UserStatus.ACTIVE;

    @Column(nullable=false, updatable=false) private Instant createdAt;
    @Column(nullable=false) private Instant updatedAt;

    @PrePersist void create() { createdAt=Instant.now(); updatedAt=createdAt; }
    @PreUpdate void update() { updatedAt=Instant.now(); }

    public static User withPhone(String e164Phone) {
        User u = new User();
        u.phone = e164Phone;
        u.status = UserStatus.ACTIVE;
        return u;
    }

    public boolean isActive(){return status == UserStatus.ACTIVE;}

    public UUID getId(){return id;}
    public String getEmail(){return email;}
    public String getPhone(){return phone;}
    public UserStatus getStatus(){return status;}
    public Instant getCreatedAt(){return createdAt;}
    public void setEmail(String v){email=v;}
    public void setPhone(String v){phone=v;}
    public void setStatus(UserStatus v){status=v;}
}
