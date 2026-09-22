package com.company.platform.auth.api;

import com.company.platform.auth.service.OtpService;
import com.company.platform.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final OtpService otpService;

    public AuthController(OtpService otpService) { this.otpService = otpService; }

    @PostMapping("/otp/request")
    public ApiResponse<OtpResponse> request(@Valid @RequestBody OtpRequest request) {
        otpService.requestOtp(request.destination());
        return ApiResponse.ok(new OtpResponse("OTP_SENT"), "OTP sent");
    }

    @PostMapping("/otp/verify")
    public ApiResponse<OtpService.TokenResponse> verify(@Valid @RequestBody VerifyOtpRequest request) {
        return ApiResponse.ok(otpService.verify(request.destination(), request.otp()), "Authenticated");
    }

    public record OtpRequest(@NotBlank String destination) {}
    public record VerifyOtpRequest(@NotBlank String destination, @NotBlank String otp) {}
    public record OtpResponse(String status) {}
}
