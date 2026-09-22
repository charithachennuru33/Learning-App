package com.company.platform.sms;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.stereotype.Component;

/** Local-development adapter: sends nothing. Refuses to start under the prod profile. */
@Component
@ConditionalOnProperty(name = "platform.sms.provider", havingValue = "logging")
public class LoggingSmsGateway implements SmsGateway {
    private static final Logger log = LoggerFactory.getLogger(LoggingSmsGateway.class);

    private final boolean logOtp;

    public LoggingSmsGateway(SmsProperties props, Environment env) {
        if (env.acceptsProfiles(Profiles.of("prod"))) {
            throw new IllegalStateException("platform.sms.provider=logging is not allowed with the prod profile");
        }
        this.logOtp = props.logging().logOtp();
    }

    @Override
    public void sendOtp(String e164Phone, String otp) {
        if (logOtp) {
            log.warn("DEV ONLY: OTP for {} is {}", e164Phone, otp);
        } else {
            log.info("DEV ONLY: OTP generated for {} (set platform.sms.logging.log-otp=true to print it)", e164Phone);
        }
    }
}
