package com.company.platform.payment;

import com.company.platform.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import org.springframework.context.annotation.Profile;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;

@RestController
@RequestMapping("/api/v1/payments")
@Profile("dev")
public class PaymentController {
    private final PaymentGateway gateway;

    public PaymentController(PaymentGateway gateway) { this.gateway = gateway; }

    @PostMapping
    public ApiResponse<PaymentGateway.PaymentResult> create(@Valid @RequestBody Request request) {
        var result = gateway.createPayment(
                new PaymentGateway.CreatePaymentCommand(
                        request.externalReference(), request.amount(), request.currency()));
        return ApiResponse.ok(result);
    }

    public record Request(
            @NotBlank String externalReference,
            @DecimalMin("0.01") BigDecimal amount,
            @NotBlank String currency) {}
}
