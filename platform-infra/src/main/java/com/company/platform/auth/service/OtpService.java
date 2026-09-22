package com.company.platform.auth.service;

import com.company.platform.auth.domain.User;
import com.company.platform.auth.domain.UserRepository;
import com.company.platform.auth.domain.UserStatus;
import com.company.platform.auth.security.JwtService;
import com.company.platform.sms.SmsGateway;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Service
public class OtpService {
    private static final Duration OTP_TTL = Duration.ofMinutes(5);
    private static final SecureRandom RANDOM = new SecureRandom();

    private final StringRedisTemplate redis;
    private final SmsGateway sms;
    private final UserRepository users;
    private final JwtService jwt;

    public OtpService(StringRedisTemplate redis, SmsGateway sms, UserRepository users, JwtService jwt) {
        this.redis=redis; this.sms=sms; this.users=users; this.jwt=jwt;
    }

    public void requestOtp(String destination) {
        String normalized = normalize(destination);
        String otp = String.format("%06d", RANDOM.nextInt(1_000_000));
        redis.opsForValue().set(key(normalized), otp, OTP_TTL.toSeconds(), TimeUnit.SECONDS);
        sms.sendOtp(normalized, otp);
    }

    @Transactional
    public TokenResponse verify(String destination, String otp) {
        String normalized = normalize(destination);
        String key = key(normalized);
        String expected = redis.opsForValue().get(key);
        if (expected == null || !expected.equals(otp)) {
            throw new IllegalArgumentException("Invalid or expired OTP");
        }
        redis.delete(key);

        User user = users.findByPhone(normalized).orElseGet(() -> {
            User u = new User();
            if (normalized.contains("@")) u.setEmail(normalized);
            else u.setPhone(normalized);
            u.setStatus(UserStatus.ACTIVE);
            return users.save(u);
        });

        return new TokenResponse(jwt.createAccessToken(user.getId()), "Bearer");
    }

    private String key(String destination) {
        return "platform:auth:otp:" + destination;
    }

    private String normalize(String value) {
        return value.trim().toLowerCase();
    }

    public record TokenResponse(String accessToken, String tokenType) {}
}
