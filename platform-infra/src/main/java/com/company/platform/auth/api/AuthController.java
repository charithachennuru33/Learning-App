package com.company.platform.auth.api;

import com.company.platform.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    @PostMapping("/otp")
    public ApiResponse<OtpResponse> requestOtp(@Valid @RequestBody OtpRequest request) {
        // Provider integration belongs in the SMS infrastructure adapter.
        return ApiResponse.ok(
                new OtpResponse("OTP_REQUEST_ACCEPTED"),
                "OTP request accepted"
        );
    }

    public record OtpRequest(
            @NotBlank(message = "destination is required")
            String destination
    ) {}

    public record OtpResponse(String status) {}
}
