package com.company.platform.sms;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

/**
 * {@code provider} selects the adapter: {@code twilio} or {@code msg91} for real delivery, {@code logging} for
 * local development only. Left empty, the application refuses to start rather than silently not sending SMS.
 */
@ConfigurationProperties("platform.sms")
public record SmsProperties(String provider, String messageTemplate, Logging logging, Twilio twilio, Msg91 msg91) {

    public SmsProperties {
        if (messageTemplate == null || messageTemplate.isBlank()) {
            messageTemplate = "%s is your verification code. Do not share it with anyone.";
        }
        if (logging == null) logging = new Logging(false);
        if (twilio == null) twilio = new Twilio(null, null, null, null, null, null, null);
        if (msg91 == null) msg91 = new Msg91(null, null, null, null, null, null);
    }

    public String render(String otp) { return messageTemplate.formatted(otp); }

    /** @param logOtp print the code in the log. Only for local development. */
    public record Logging(boolean logOtp) {}

    public record Twilio(String accountSid, String authToken, String fromNumber, String messagingServiceSid,
                         String baseUrl, Duration connectTimeout, Duration readTimeout) {
        public Twilio {
            if (baseUrl == null || baseUrl.isBlank()) baseUrl = "https://api.twilio.com";
            if (connectTimeout == null) connectTimeout = Duration.ofSeconds(3);
            if (readTimeout == null) readTimeout = Duration.ofSeconds(10);
        }
    }

    /**
     * MSG91 Flow API. The message text lives in the DLT-approved template on MSG91, not in
     * {@code messageTemplate}; {@code otpVariable} names the template variable that receives the code
     * (e.g. {@code otp} for a template containing {@code ##otp##}).
     */
    public record Msg91(String authKey, String templateId, String otpVariable,
                        String baseUrl, Duration connectTimeout, Duration readTimeout) {
        public Msg91 {
            if (otpVariable == null || otpVariable.isBlank()) otpVariable = "otp";
            if (baseUrl == null || baseUrl.isBlank()) baseUrl = "https://control.msg91.com";
            if (connectTimeout == null) connectTimeout = Duration.ofSeconds(3);
            if (readTimeout == null) readTimeout = Duration.ofSeconds(10);
        }
    }
}
