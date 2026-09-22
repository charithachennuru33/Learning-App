package com.company.platform.sms;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

import java.util.List;
import java.util.Map;

/**
 * Sends OTPs through the MSG91 Flow API (v5), the DLT-compliant route for Indian numbers. The SMS text is the
 * approved template on MSG91; this adapter only fills in the code.
 */
@Component
@ConditionalOnProperty(name = "platform.sms.provider", havingValue = "msg91")
public class Msg91SmsGateway implements SmsGateway {
    private static final Logger log = LoggerFactory.getLogger(Msg91SmsGateway.class);

    private final SmsProperties.Msg91 msg91;
    private final RestClient client;

    @Autowired
    public Msg91SmsGateway(SmsProperties props, RestClient.Builder builder) {
        this(props, builder, true);
    }

    /** @param applyTimeouts false in tests, where the builder is bound to a mock server. */
    Msg91SmsGateway(SmsProperties props, RestClient.Builder builder, boolean applyTimeouts) {
        this.msg91 = props.msg91();
        require(msg91.authKey(), "platform.sms.msg91.auth-key");
        require(msg91.templateId(), "platform.sms.msg91.template-id");
        if (applyTimeouts) builder.requestFactory(requestFactory(msg91));
        this.client = builder
                .baseUrl(msg91.baseUrl())
                .defaultHeader("authkey", msg91.authKey())
                .build();
    }

    @Override
    public void sendOtp(String e164Phone, String otp) {
        // MSG91 expects country code + number without the leading '+', e.g. 919876543210.
        String mobile = e164Phone.startsWith("+") ? e164Phone.substring(1) : e164Phone;
        Map<String, Object> body = Map.of(
                "template_id", msg91.templateId(),
                "short_url", "0",
                "recipients", List.of(Map.of("mobiles", mobile, msg91.otpVariable(), otp)));

        Msg91Response response;
        try {
            response = client.post()
                    .uri("/api/v5/flow")
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(Msg91Response.class);
        } catch (RestClientResponseException e) {
            log.warn("MSG91 rejected SMS: status={} body={}", e.getStatusCode().value(), e.getResponseBodyAsString());
            throw new SmsDeliveryException("MSG91 rejected the message", e);
        } catch (RestClientException e) {
            log.warn("MSG91 unreachable: {}", e.getMessage());
            throw new SmsDeliveryException("MSG91 unreachable", e);
        }

        // MSG91 can answer HTTP 200 with {"type":"error"}, so the body decides success.
        if (response == null || !"success".equalsIgnoreCase(response.type())) {
            String reason = response != null ? response.message() : "empty response";
            log.warn("MSG91 rejected SMS: {}", reason);
            throw new SmsDeliveryException("MSG91 rejected the message: " + reason, null);
        }
    }

    private static SimpleClientHttpRequestFactory requestFactory(SmsProperties.Msg91 msg91) {
        var factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(msg91.connectTimeout());
        factory.setReadTimeout(msg91.readTimeout());
        return factory;
    }

    private static void require(String value, String property) {
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(property + " is required when platform.sms.provider=msg91");
        }
    }

    record Msg91Response(String type, String message) {}
}
