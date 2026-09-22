package com.company.platform.auth.config;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

@Validated
@ConfigurationProperties("platform.auth")
public record AuthProperties(
        /** ISO 3166 region used to parse phone numbers entered without a country code. */
        @NotBlank String defaultRegion,
        @NotNull @Valid Otp otp,
        @NotNull @Valid RefreshToken refreshToken) {

    public record Otp(
            /** HMAC key for hashing OTPs at rest. At least 32 characters; rotate by redeploying (pending OTPs become invalid). */
            @NotBlank @Size(min = 32, message = "must be at least 32 characters")
            @Pattern(regexp = "^(?!\\$\\{).*", message = "is not set (OTP_SECRET)") String secret,
            @NotNull Duration ttl,
            @Min(4) @Max(9) int length,
            @Min(1) int maxAttempts,
            @NotNull Duration resendCooldown,
            @Min(1) int maxRequestsPerPhonePerHour,
            @Min(1) int maxRequestsPerIpPerHour,
            @Min(1) int maxVerificationsPerIpPerHour) {}

    public record RefreshToken(
            @NotNull Duration ttl,
            @Min(1) int maxRefreshesPerIpPerHour) {}
}
