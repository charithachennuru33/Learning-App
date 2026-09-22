package com.company.platform.sms;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

class Msg91SmsGatewayTest {
    private static final String URL = "https://control.msg91.com/api/v5/flow";

    private MockRestServiceServer server;
    private Msg91SmsGateway gateway;

    @BeforeEach
    void setUp() {
        var builder = RestClient.builder();
        server = MockRestServiceServer.bindTo(builder).build();
        gateway = new Msg91SmsGateway(props("auth-123", "tmpl-456"), builder, false);
    }

    private static SmsProperties props(String authKey, String templateId) {
        return new SmsProperties("msg91", null, null, null,
                new SmsProperties.Msg91(authKey, templateId, null, null, null, null));
    }

    @Test
    void postsFlowRequestWithTemplateAndOtpVariable() {
        server.expect(requestTo(URL))
                .andExpect(method(HttpMethod.POST))
                .andExpect(header("authkey", "auth-123"))
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.template_id").value("tmpl-456"))
                .andExpect(jsonPath("$.short_url").value("0"))
                .andExpect(jsonPath("$.recipients[0].mobiles").value("919876543210"))
                .andExpect(jsonPath("$.recipients[0].otp").value("123456"))
                .andRespond(withSuccess("{\"type\":\"success\",\"message\":\"3763646c3058373530393832\"}",
                        MediaType.APPLICATION_JSON));

        gateway.sendOtp("+919876543210", "123456");
        server.verify();
    }

    @Test
    void treatsErrorBodyWithHttp200AsFailure() {
        server.expect(requestTo(URL)).andRespond(
                withSuccess("{\"type\":\"error\",\"message\":\"Invalid template id\"}", MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> gateway.sendOtp("+919876543210", "123456"))
                .isInstanceOf(SmsDeliveryException.class)
                .hasMessageContaining("Invalid template id");
    }

    @Test
    void translatesHttpErrors() {
        server.expect(requestTo(URL)).andRespond(withStatus(HttpStatus.UNAUTHORIZED)
                .contentType(MediaType.APPLICATION_JSON).body("{\"type\":\"error\",\"message\":\"Authentication failure\"}"));

        assertThatThrownBy(() -> gateway.sendOtp("+919876543210", "123456"))
                .isInstanceOf(SmsDeliveryException.class);
    }

    @Test
    void requiresAuthKeyAndTemplate() {
        assertThatThrownBy(() -> new Msg91SmsGateway(props(null, "tmpl"), RestClient.builder(), false))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("auth-key");
        assertThatThrownBy(() -> new Msg91SmsGateway(props("key", " "), RestClient.builder(), false))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("template-id");
    }
}
