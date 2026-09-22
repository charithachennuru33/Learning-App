package com.company.platform.sms;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

/** Sends OTPs through the Twilio Messages REST API. */
@Component
@ConditionalOnProperty(name = "platform.sms.provider", havingValue = "twilio")
public class TwilioSmsGateway implements SmsGateway {
    private static final Logger log = LoggerFactory.getLogger(TwilioSmsGateway.class);

    private final SmsProperties props;
    private final SmsProperties.Twilio twilio;
    private final RestClient client;

    @Autowired
    public TwilioSmsGateway(SmsProperties props, RestClient.Builder builder) {
        this(props, builder, true);
    }

    /** @param applyTimeouts false in tests, where the builder is bound to a mock server. */
    TwilioSmsGateway(SmsProperties props, RestClient.Builder builder, boolean applyTimeouts) {
        this.props = props;
        this.twilio = props.twilio();
        require(twilio.accountSid(), "platform.sms.twilio.account-sid");
        require(twilio.authToken(), "platform.sms.twilio.auth-token");
        if (isBlank(twilio.fromNumber()) && isBlank(twilio.messagingServiceSid())) {
            throw new IllegalStateException(
                    "Set platform.sms.twilio.from-number or platform.sms.twilio.messaging-service-sid");
        }
        if (applyTimeouts) builder.requestFactory(requestFactory(twilio));
        this.client = builder
                .baseUrl(twilio.baseUrl())
                .defaultHeaders(h -> h.setBasicAuth(twilio.accountSid(), twilio.authToken()))
                .build();
    }

    @Override
    public void sendOtp(String e164Phone, String otp) {
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("To", e164Phone);
        form.add("Body", props.render(otp));
        if (!isBlank(twilio.messagingServiceSid())) form.add("MessagingServiceSid", twilio.messagingServiceSid());
        else form.add("From", twilio.fromNumber());
        try {
            client.post()
                    .uri("/2010-04-01/Accounts/{sid}/Messages.json", twilio.accountSid())
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(form)
                    .retrieve()
                    .toBodilessEntity();
        } catch (RestClientResponseException e) {
            // Twilio's error body holds an error code and description, never the SMS body, so the OTP is not logged.
            log.warn("Twilio rejected SMS: status={} body={}", e.getStatusCode().value(), e.getResponseBodyAsString());
            throw new SmsDeliveryException("Twilio rejected the message", e);
        } catch (RestClientException e) {
            log.warn("Twilio unreachable: {}", e.getMessage());
            throw new SmsDeliveryException("Twilio unreachable", e);
        }
    }

    private static SimpleClientHttpRequestFactory requestFactory(SmsProperties.Twilio twilio) {
        var factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(twilio.connectTimeout());
        factory.setReadTimeout(twilio.readTimeout());
        return factory;
    }

    private static void require(String value, String property) {
        if (isBlank(value)) throw new IllegalStateException(property + " is required when platform.sms.provider=twilio");
    }

    private static boolean isBlank(String s) { return s == null || s.isBlank(); }
}
