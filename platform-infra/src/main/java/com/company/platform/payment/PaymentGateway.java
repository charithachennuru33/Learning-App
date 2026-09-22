package com.company.platform.payment;

import java.math.BigDecimal;

public interface PaymentGateway {

    PaymentResult createPayment(CreatePaymentCommand command);

    record CreatePaymentCommand(
            String externalReference,
            BigDecimal amount,
            String currency
    ) {}

    record PaymentResult(
            String providerPaymentId,
            String status
    ) {}
}
