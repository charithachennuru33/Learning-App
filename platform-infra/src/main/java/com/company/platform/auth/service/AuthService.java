package com.company.platform.auth.service;

import com.company.platform.audit.AuditEventType;
import com.company.platform.audit.AuditService;
import com.company.platform.auth.config.AuthProperties;
import com.company.platform.auth.domain.User;
import com.company.platform.auth.domain.UserRepository;
import com.company.platform.common.error.ApiException;
import com.company.platform.common.error.ErrorCode;
import com.company.platform.common.ratelimit.RedisRateLimiter;
import com.company.platform.common.web.ClientContext;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Duration;
import java.util.UUID;

import static com.company.platform.auth.service.PhoneNumberNormalizer.mask;

/** Entry point for the phone-OTP login flow and session management. */
@Service
public class AuthService {
    private final PhoneNumberNormalizer phones;
    private final OtpService otp;
    private final TokenService tokens;
    private final UserRepository users;
    private final AuditService audit;
    private final RedisRateLimiter rateLimiter;
    private final AuthProperties.RefreshToken refreshConfig;
    private final TransactionTemplate tx;

    public AuthService(PhoneNumberNormalizer phones, OtpService otp, TokenService tokens, UserRepository users,
                       AuditService audit, RedisRateLimiter rateLimiter, AuthProperties props,
                       PlatformTransactionManager txManager) {
        this.phones = phones;
        this.otp = otp;
        this.tokens = tokens;
        this.users = users;
        this.audit = audit;
        this.rateLimiter = rateLimiter;
        this.refreshConfig = props.refreshToken();
        this.tx = new TransactionTemplate(txManager);
    }

    public OtpService.OtpChallenge requestOtp(String rawPhone, ClientContext client) {
        return otp.issue(phones.normalize(rawPhone), client);
    }

    public AuthTokens verifyOtp(String rawPhone, String code, ClientContext client) {
        String phone = phones.normalize(rawPhone);
        otp.verify(phone, code, client);

        User user = findOrRegister(phone, client);
        if (!user.isActive()) {
            audit.record(AuditEventType.LOGIN_REJECTED_INACTIVE_ACCOUNT, user.getId(), mask(phone), client,
                    "status=" + user.getStatus());
            throw new ApiException(ErrorCode.ACCOUNT_INACTIVE);
        }
        AuthTokens issued = tokens.issue(user, client);
        audit.record(AuditEventType.LOGIN_SUCCEEDED, user.getId(), mask(phone), client, null);
        return issued;
    }

    public AuthTokens refresh(String refreshToken, ClientContext client) {
        rateLimiter.consume("token-refresh:ip:" + client.ip(), refreshConfig.maxRefreshesPerIpPerHour(),
                Duration.ofHours(1));
        return tokens.refresh(refreshToken, client);
    }

    public void logout(String refreshToken, ClientContext client) {
        tokens.revokeSession(refreshToken, client);
    }

    public void logoutAll(UUID userId, ClientContext client) {
        tokens.revokeAllSessions(userId, client);
    }

    private User findOrRegister(String phone, ClientContext client) {
        User existing = users.findByPhone(phone).orElse(null);
        if (existing != null) return existing;
        try {
            User created = tx.execute(s -> users.saveAndFlush(User.withPhone(phone)));
            audit.record(AuditEventType.USER_REGISTERED, created.getId(), mask(phone), client, null);
            return created;
        } catch (DataIntegrityViolationException raceLost) {
            // A concurrent first login for the same phone inserted the row first.
            return users.findByPhone(phone).orElseThrow(() -> raceLost);
        }
    }
}
