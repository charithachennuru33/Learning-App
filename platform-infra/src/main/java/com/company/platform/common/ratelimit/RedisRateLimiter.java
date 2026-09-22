package com.company.platform.common.ratelimit;

import com.company.platform.common.error.ApiException;
import com.company.platform.common.error.ErrorCode;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.List;
import java.util.concurrent.TimeUnit;

/** Fixed-window counter shared by all instances through Redis. */
@Component
public class RedisRateLimiter {
    private static final String PREFIX = "platform:ratelimit:";
    private static final RedisScript<Long> INCREMENT = RedisScript.of("""
            local current = redis.call('INCR', KEYS[1])
            if current == 1 then redis.call('PEXPIRE', KEYS[1], ARGV[1]) end
            return current
            """, Long.class);

    private final StringRedisTemplate redis;

    public RedisRateLimiter(StringRedisTemplate redis) { this.redis = redis; }

    /** Counts one hit against {@code key}; throws {@link ErrorCode#RATE_LIMITED} once {@code limit} is exceeded. */
    public void consume(String key, int limit, Duration window) {
        String redisKey = PREFIX + key;
        Long count = redis.execute(INCREMENT, List.of(redisKey), String.valueOf(window.toMillis()));
        if (count != null && count > limit) {
            Long ttl = redis.getExpire(redisKey, TimeUnit.SECONDS);
            Duration retryAfter = ttl != null && ttl > 0 ? Duration.ofSeconds(ttl) : window;
            throw ApiException.retryAfter(ErrorCode.RATE_LIMITED, retryAfter);
        }
    }
}
