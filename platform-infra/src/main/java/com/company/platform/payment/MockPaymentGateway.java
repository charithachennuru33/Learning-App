package com.company.platform.payment;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
@Profile("dev")
public class MockPaymentGateway implements PaymentGateway {

    @Override
    public PaymentResult createPayment(CreatePaymentCommand command) {
        return new PaymentResult(
                "dev-" + UUID.randomUUID(),
                "CREATED"
        );
    }
}
