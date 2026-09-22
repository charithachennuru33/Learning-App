package com.company.platform.sms;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class LoggingSmsGateway implements SmsGateway {

    private static final Logger log = LoggerFactory.getLogger(LoggingSmsGateway.class);

    @Override
    public void sendOtp(String destination, String otp) {
        // Development adapter only. Replace with a real provider adapter.
        log.info("SMS OTP requested for destination={}", destination);
    }
}
