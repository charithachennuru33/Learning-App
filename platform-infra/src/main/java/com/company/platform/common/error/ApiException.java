package com.company.platform.common.error;

import java.time.Duration;

/** Expected, client-facing failure. The message is safe to return to callers. */
public class ApiException extends RuntimeException {
    private final ErrorCode code;
    private final Duration retryAfter;

    public ApiException(ErrorCode code) { this(code, code.defaultMessage(), null); }

    public ApiException(ErrorCode code, String message) { this(code, message, null); }

    public ApiException(ErrorCode code, String message, Duration retryAfter) {
        super(message);
        this.code = code;
        this.retryAfter = retryAfter;
    }

    public static ApiException retryAfter(ErrorCode code, Duration retryAfter) {
        return new ApiException(code, code.defaultMessage(), retryAfter);
    }

    public ErrorCode code() { return code; }
    public Duration retryAfter() { return retryAfter; }
}
