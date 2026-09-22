package com.company.platform.sms;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class LoggingSmsGateway implements SmsGateway {
    private static final Logger log = LoggerFactory.getLogger(LoggingSmsGateway.class);

    @Override
    public void sendOtp(String destination, String otp) {
        // Development-only adapter. Do not log OTPs in production.
        log.info("Development SMS adapter accepted OTP request for destination={}", destination);
    }
}
