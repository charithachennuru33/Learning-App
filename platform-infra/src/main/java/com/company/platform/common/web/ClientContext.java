package com.company.platform.common.web;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpHeaders;

/**
 * Caller metadata used for rate limiting and auditing. The IP is the servlet remote address, so behind a
 * proxy or load balancer set FORWARD_HEADERS_STRATEGY=native and make sure only the proxy can set
 * X-Forwarded-For; otherwise clients can spoof their IP and dodge per-IP limits.
 */
public record ClientContext(String ip, String userAgent) {
    private static final int MAX_USER_AGENT = 255;

    public static ClientContext from(HttpServletRequest request) {
        String ua = request.getHeader(HttpHeaders.USER_AGENT);
        if (ua != null && ua.length() > MAX_USER_AGENT) ua = ua.substring(0, MAX_USER_AGENT);
        return new ClientContext(request.getRemoteAddr(), ua);
    }
}
