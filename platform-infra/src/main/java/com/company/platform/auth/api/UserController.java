package com.company.platform.auth.api;

import com.company.platform.auth.domain.UserRepository;
import com.company.platform.auth.domain.UserStatus;
import com.company.platform.auth.security.AuthenticatedUser;
import com.company.platform.common.api.ApiResponse;
import com.company.platform.common.error.ApiException;
import com.company.platform.common.error.ErrorCode;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/users")
@SecurityRequirement(name = "bearer")
public class UserController {
    private final UserRepository users;

    public UserController(UserRepository users) { this.users = users; }

    @GetMapping("/me")
    public ApiResponse<Me> me(@AuthenticationPrincipal AuthenticatedUser principal) {
        var user = users.findById(principal.id()).orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
        return ApiResponse.ok(new Me(user.getId(), user.getPhone(), user.getEmail(), user.getStatus(), user.getCreatedAt()));
    }

    public record Me(UUID id, String phone, String email, UserStatus status, Instant createdAt) {}
}
