package com.company.platform.sms;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

class TwilioSmsGatewayTest {
    private static final String URL = "https://api.twilio.com/2010-04-01/Accounts/AC123/Messages.json";

    private MockRestServiceServer server;
    private TwilioSmsGateway gateway;

    @BeforeEach
    void setUp() {
        var builder = RestClient.builder();
        server = MockRestServiceServer.bindTo(builder).build();
        var props = new SmsProperties("twilio", "Code: %s", null,
                new SmsProperties.Twilio("AC123", "secret-token", "+15005550006", null, null, null, null), null);
        gateway = new TwilioSmsGateway(props, builder, false);
    }

    @Test
    void postsFormWithBasicAuth() {
        String basic = "Basic " + Base64.getEncoder().encodeToString("AC123:secret-token".getBytes());
        server.expect(requestTo(URL))
                .andExpect(method(HttpMethod.POST))
                .andExpect(header(HttpHeaders.AUTHORIZATION, basic))
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_FORM_URLENCODED))
                .andExpect(content().formDataContains(java.util.Map.of(
                        "To", "+919876543210", "From", "+15005550006", "Body", "Code: 123456")))
                .andRespond(withSuccess("{\"sid\":\"SM1\"}", MediaType.APPLICATION_JSON));

        gateway.sendOtp("+919876543210", "123456");
        server.verify();
    }

    @Test
    void translatesProviderErrors() {
        server.expect(requestTo(URL)).andRespond(withStatus(HttpStatus.BAD_REQUEST)
                .contentType(MediaType.APPLICATION_JSON).body("{\"code\":21211}"));

        assertThatThrownBy(() -> gateway.sendOtp("+919876543210", "123456"))
                .isInstanceOf(SmsDeliveryException.class);
    }

    @Test
    void requiresCredentials() {
        var props = new SmsProperties("twilio", null, null,
                new SmsProperties.Twilio(null, null, null, null, null, null, null), null);
        assertThatThrownBy(() -> new TwilioSmsGateway(props, RestClient.builder(), false))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("account-sid");
    }
}
