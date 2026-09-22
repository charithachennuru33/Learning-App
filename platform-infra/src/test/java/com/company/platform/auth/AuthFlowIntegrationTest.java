package com.company.platform.auth;

import com.company.platform.audit.AuditEventRepository;
import com.company.platform.audit.AuditEventType;
import com.company.platform.auth.domain.RefreshTokenRepository;
import com.company.platform.auth.domain.UserRepository;
import com.company.platform.auth.domain.UserStatus;
import com.company.platform.sms.CapturingSmsGateway;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Testcontainers(disabledWithoutDocker = true)
class AuthFlowIntegrationTest {
    private static final String PHONE = "+919876543210";

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:17-alpine");

    @Container
    @ServiceConnection(name = "redis")
    static GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine").withExposedPorts(6379);

    @TestConfiguration
    static class SmsConfig {
        @Bean
        CapturingSmsGateway capturingSmsGateway() { return new CapturingSmsGateway(); }
    }

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired CapturingSmsGateway sms;
    @Autowired StringRedisTemplate redisTemplate;
    @Autowired UserRepository users;
    @Autowired AuditEventRepository audit;
    @Autowired RefreshTokenRepository refreshTokens;

    @BeforeEach
    void reset() {
        refreshTokens.deleteAllInBatch();
        users.deleteAllInBatch();
        audit.deleteAllInBatch();
        sms.reset();
        redisTemplate.getConnectionFactory().getConnection().serverCommands().flushAll();
    }

    @Test
    void fullLoginRefreshAndReuseDetection() throws Exception {
        requestOtp("98765 43210").andExpect(status().isOk())
                .andExpect(jsonPath("$.data.expiresInSeconds").value(300));
        String otp = sms.lastOtp(PHONE);
        assertThat(otp).hasSize(6);

        JsonNode login = body(verify("98765 43210", otp).andExpect(status().isOk()));
        String access = login.at("/data/accessToken").asText();
        String refresh1 = login.at("/data/refreshToken").asText();
        UUID userId = UUID.fromString(login.at("/data/userId").asText());

        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.phone").value(PHONE));

        JsonNode rotated = body(refresh(refresh1).andExpect(status().isOk()));
        String refresh2 = rotated.at("/data/refreshToken").asText();
        assertThat(refresh2).isNotEqualTo(refresh1);

        // Replaying the rotated token revokes the whole family, including the newest token.
        refresh(refresh1).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_REFRESH_TOKEN"));
        refresh(refresh2).andExpect(status().isUnauthorized());

        assertThat(audit.findByUserIdOrderByCreatedAtAsc(userId))
                .extracting(e -> e.getType())
                .contains(AuditEventType.USER_REGISTERED, AuditEventType.LOGIN_SUCCEEDED,
                        AuditEventType.TOKEN_REFRESHED, AuditEventType.REFRESH_TOKEN_REUSE_DETECTED);
    }

    @Test
    void codeIsSingleUse() throws Exception {
        requestOtp(PHONE).andExpect(status().isOk());
        String otp = sms.lastOtp(PHONE);
        verify(PHONE, otp).andExpect(status().isOk());
        verify(PHONE, otp).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_OTP"));
    }

    @Test
    void codeIsBurnedAfterMaxWrongAttempts() throws Exception {
        requestOtp(PHONE).andExpect(status().isOk());
        String otp = sms.lastOtp(PHONE);
        String wrong = otp.equals("000000") ? "111111" : "000000";

        for (int i = 0; i < 4; i++) {
            verify(PHONE, wrong).andExpect(status().isUnauthorized());
        }
        verify(PHONE, wrong).andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.error.code").value("OTP_ATTEMPTS_EXCEEDED"));
        verify(PHONE, otp).andExpect(status().isUnauthorized());
    }

    @Test
    void resendIsThrottled() throws Exception {
        requestOtp(PHONE).andExpect(status().isOk());
        requestOtp(PHONE).andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"))
                .andExpect(jsonPath("$.error.code").value("OTP_RESEND_TOO_SOON"));
    }

    @Test
    void smsOutageReturns503AndAllowsImmediateRetry() throws Exception {
        sms.setFailing(true);
        requestOtp(PHONE).andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.error.code").value("SMS_UNAVAILABLE"));
        sms.setFailing(false);
        requestOtp(PHONE).andExpect(status().isOk());
    }

    @Test
    void rejectsInvalidInput() throws Exception {
        requestOtp("12345").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_PHONE_NUMBER"));
        verify(PHONE, "12ab").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.fields.otp").exists());
        mvc.perform(post("/api/v1/auth/otp/request").contentType(MediaType.APPLICATION_JSON).content("{"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void protectedEndpointsNeedAValidToken() throws Exception {
        mvc.perform(get("/api/v1/users/me")).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
        mvc.perform(get("/api/v1/users/me").header("Authorization", "Bearer not-a-jwt"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logoutRevokesTheSession() throws Exception {
        JsonNode login = login(PHONE);
        String refreshToken = login.at("/data/refreshToken").asText();

        mvc.perform(post("/api/v1/auth/logout").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", refreshToken))))
                .andExpect(status().isNoContent());
        refresh(refreshToken).andExpect(status().isUnauthorized());
    }

    @Test
    void logoutAllRevokesEverySession() throws Exception {
        JsonNode first = login(PHONE);
        redisTemplate.getConnectionFactory().getConnection().serverCommands().flushAll(); // skip resend cooldown
        JsonNode second = login(PHONE);

        mvc.perform(post("/api/v1/auth/logout-all")
                        .header("Authorization", "Bearer " + second.at("/data/accessToken").asText()))
                .andExpect(status().isNoContent());
        refresh(first.at("/data/refreshToken").asText()).andExpect(status().isUnauthorized());
        refresh(second.at("/data/refreshToken").asText()).andExpect(status().isUnauthorized());
    }

    @Test
    void inactiveAccountsCannotLogInOrRefresh() throws Exception {
        JsonNode login = login(PHONE);
        var user = users.findByPhone(PHONE).orElseThrow();
        user.setStatus(UserStatus.DISABLED);
        users.save(user);

        refresh(login.at("/data/refreshToken").asText()).andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("ACCOUNT_INACTIVE"));

        redisTemplate.getConnectionFactory().getConnection().serverCommands().flushAll();
        requestOtp(PHONE).andExpect(status().isOk());
        verify(PHONE, sms.lastOtp(PHONE)).andExpect(status().isForbidden());
    }

    private JsonNode login(String phone) throws Exception {
        requestOtp(phone).andExpect(status().isOk());
        return body(verify(phone, sms.lastOtp(phone)).andExpect(status().isOk()));
    }

    private ResultActions requestOtp(String phone) throws Exception {
        return mvc.perform(post("/api/v1/auth/otp/request").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("phone", phone))));
    }

    private ResultActions verify(String phone, String otp) throws Exception {
        return mvc.perform(post("/api/v1/auth/otp/verify").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("phone", phone, "otp", otp))));
    }

    private ResultActions refresh(String token) throws Exception {
        return mvc.perform(post("/api/v1/auth/token/refresh").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("refreshToken", token))));
    }

    private JsonNode body(ResultActions result) throws Exception {
        return json.readTree(result.andReturn().getResponse().getContentAsString());
    }
}
