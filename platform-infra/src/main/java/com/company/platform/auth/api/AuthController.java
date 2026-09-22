package com.company.platform.auth.api;

import com.company.platform.auth.security.AuthenticatedUser;
import com.company.platform.auth.service.AuthService;
import com.company.platform.auth.service.AuthTokens;
import com.company.platform.common.api.ApiResponse;
import com.company.platform.common.web.ClientContext;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final AuthService auth;

    public AuthController(AuthService auth) { this.auth = auth; }

    @Operation(summary = "Send a one-time code to a phone number")
    @PostMapping("/otp/request")
    public ApiResponse<OtpResponse> request(@Valid @RequestBody OtpRequest request, HttpServletRequest http) {
        var challenge = auth.requestOtp(request.phone(), ClientContext.from(http));
        return ApiResponse.ok(new OtpResponse(challenge.expiresIn().toSeconds(), challenge.resendAfter().toSeconds()),
                "OTP sent");
    }

    @Operation(summary = "Exchange a one-time code for access and refresh tokens")
    @PostMapping("/otp/verify")
    public ApiResponse<TokenResponse> verify(@Valid @RequestBody VerifyOtpRequest request, HttpServletRequest http) {
        return ApiResponse.ok(TokenResponse.from(auth.verifyOtp(request.phone(), request.otp(),
                ClientContext.from(http))), "Authenticated");
    }

    @Operation(summary = "Rotate a refresh token. The presented token becomes invalid")
    @PostMapping("/token/refresh")
    public ApiResponse<TokenResponse> refresh(@Valid @RequestBody RefreshRequest request, HttpServletRequest http) {
        return ApiResponse.ok(TokenResponse.from(auth.refresh(request.refreshToken(), ClientContext.from(http))));
    }

    @Operation(summary = "End the session that owns this refresh token")
    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@Valid @RequestBody RefreshRequest request, HttpServletRequest http) {
        auth.logout(request.refreshToken(), ClientContext.from(http));
    }

    @Operation(summary = "End every session of the current user", security = @SecurityRequirement(name = "bearer"))
    @PostMapping("/logout-all")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logoutAll(@AuthenticationPrincipal AuthenticatedUser user, HttpServletRequest http) {
        auth.logoutAll(user.id(), ClientContext.from(http));
    }

    public record OtpRequest(@NotBlank @Size(max = 32) String phone) {}

    public record VerifyOtpRequest(
            @NotBlank @Size(max = 32) String phone,
            @NotBlank @Pattern(regexp = "\\d{4,9}", message = "must be 4-9 digits") String otp) {}

    public record RefreshRequest(@NotBlank @Size(max = 128) String refreshToken) {}

    public record OtpResponse(long expiresInSeconds, long resendAfterSeconds) {}

    public record TokenResponse(UUID userId, String tokenType, String accessToken, Instant accessTokenExpiresAt,
                                long expiresIn, String refreshToken, Instant refreshTokenExpiresAt) {
        static TokenResponse from(AuthTokens t) {
            long expiresIn = Math.max(0, t.accessTokenExpiresAt().getEpochSecond() - Instant.now().getEpochSecond());
            return new TokenResponse(t.userId(), "Bearer", t.accessToken(), t.accessTokenExpiresAt(), expiresIn,
                    t.refreshToken(), t.refreshTokenExpiresAt());
        }
    }
}
