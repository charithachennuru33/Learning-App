package com.company.platform.auth.service;

import com.company.platform.audit.AuditEventType;
import com.company.platform.audit.AuditService;
import com.company.platform.auth.config.AuthProperties;
import com.company.platform.common.error.ApiException;
import com.company.platform.common.error.ErrorCode;
import com.company.platform.common.ratelimit.RedisRateLimiter;
import com.company.platform.common.web.ClientContext;
import com.company.platform.sms.SmsDeliveryException;
import com.company.platform.sms.SmsGateway;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.HexFormat;
import java.util.List;
import java.util.concurrent.TimeUnit;

import static com.company.platform.auth.service.PhoneNumberNormalizer.mask;

/**
 * Issues and checks one-time codes. Codes are stored as HMACs (a Redis dump does not reveal them), each code
 * allows {@code maxAttempts} guesses, and issuance is throttled per phone and per IP to stop SMS pumping.
 * Keys use a {phone} hash tag so the Lua scripts stay on one slot in Redis Cluster.
 */
@Service
public class OtpService {
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Duration HOUR = Duration.ofHours(1);

    /** KEYS: code, attempts. ARGV: hash, ttlMillis. Storing a new code resets the attempt counter. */
    private static final RedisScript<Long> STORE = RedisScript.of("""
            redis.call('SET', KEYS[1], ARGV[1], 'PX', ARGV[2])
            redis.call('DEL', KEYS[2])
            return 1
            """, Long.class);

    /** KEYS: code, attempts. ARGV: hash, maxAttempts. Returns 1 match, 0 mismatch/absent, -1 attempts exhausted. */
    private static final RedisScript<Long> VERIFY = RedisScript.of("""
            local stored = redis.call('GET', KEYS[1])
            if not stored then return 0 end
            local attempts = redis.call('INCR', KEYS[2])
            if attempts == 1 then
              redis.call('PEXPIRE', KEYS[2], math.max(redis.call('PTTL', KEYS[1]), 1))
            end
            if stored == ARGV[1] then
              redis.call('DEL', KEYS[1], KEYS[2])
              return 1
            end
            if attempts >= tonumber(ARGV[2]) then
              redis.call('DEL', KEYS[1], KEYS[2])
              return -1
            end
            return 0
            """, Long.class);

    private final StringRedisTemplate redis;
    private final RedisRateLimiter rateLimiter;
    private final SmsGateway sms;
    private final AuditService audit;
    private final AuthProperties.Otp config;
    private final SecretKeySpec hmacKey;
    private final int bound;

    public OtpService(StringRedisTemplate redis, RedisRateLimiter rateLimiter, SmsGateway sms, AuditService audit,
                      AuthProperties props) {
        this.redis = redis;
        this.rateLimiter = rateLimiter;
        this.sms = sms;
        this.audit = audit;
        this.config = props.otp();
        this.hmacKey = new SecretKeySpec(config.secret().getBytes(StandardCharsets.UTF_8), "HmacSHA256");
        this.bound = (int) Math.pow(10, config.length());
    }

    public OtpChallenge issue(String phone, ClientContext client) {
        rateLimiter.consume("otp-request:ip:" + client.ip(), config.maxRequestsPerIpPerHour(), HOUR);

        String cooldownKey = key(phone, "cooldown");
        Boolean acquired = redis.opsForValue().setIfAbsent(cooldownKey, "1", config.resendCooldown());
        if (!Boolean.TRUE.equals(acquired)) {
            Long ttl = redis.getExpire(cooldownKey, TimeUnit.SECONDS);
            throw ApiException.retryAfter(ErrorCode.OTP_RESEND_TOO_SOON,
                    ttl != null && ttl > 0 ? Duration.ofSeconds(ttl) : config.resendCooldown());
        }
        rateLimiter.consume("otp-request:phone:" + phone, config.maxRequestsPerPhonePerHour(), HOUR);

        String code = generate();
        redis.execute(STORE, List.of(key(phone, "code"), key(phone, "attempts")),
                hash(phone, code), String.valueOf(config.ttl().toMillis()));
        try {
            sms.sendOtp(phone, code);
        } catch (SmsDeliveryException e) {
            // Let the user retry immediately; the undelivered code must not stay valid.
            redis.delete(List.of(key(phone, "code"), key(phone, "attempts"), cooldownKey));
            audit.record(AuditEventType.OTP_DELIVERY_FAILED, null, mask(phone), client, e.getMessage());
            throw new ApiException(ErrorCode.SMS_UNAVAILABLE);
        }
        audit.record(AuditEventType.OTP_REQUESTED, null, mask(phone), client, null);
        return new OtpChallenge(config.ttl(), config.resendCooldown());
    }

    /** @throws ApiException INVALID_OTP or OTP_ATTEMPTS_EXCEEDED */
    public void verify(String phone, String code, ClientContext client) {
        rateLimiter.consume("otp-verify:ip:" + client.ip(), config.maxVerificationsPerIpPerHour(), HOUR);

        Long result = redis.execute(VERIFY, List.of(key(phone, "code"), key(phone, "attempts")),
                hash(phone, code), String.valueOf(config.maxAttempts()));
        if (result != null && result == 1) return;
        if (result != null && result == -1) {
            audit.record(AuditEventType.OTP_ATTEMPTS_EXCEEDED, null, mask(phone), client, null);
            throw new ApiException(ErrorCode.OTP_ATTEMPTS_EXCEEDED);
        }
        audit.record(AuditEventType.OTP_VERIFICATION_FAILED, null, mask(phone), client, null);
        throw new ApiException(ErrorCode.INVALID_OTP);
    }

    private String generate() {
        return String.format("%0" + config.length() + "d", RANDOM.nextInt(bound));
    }

    private String hash(String phone, String code) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(hmacKey);
            return HexFormat.of().formatHex(mac.doFinal((phone + ':' + code).getBytes(StandardCharsets.UTF_8)));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    private static String key(String phone, String suffix) {
        return "platform:auth:otp:{" + phone + "}:" + suffix;
    }

    public record OtpChallenge(Duration expiresIn, Duration resendAfter) {}
}
