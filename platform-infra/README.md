# platform-infra

Company-wide reusable infrastructure service.

## Modules

- Auth: OTP authentication foundation + JWT access tokens
- SMS: provider abstraction
- Payment: provider abstraction
- Common: API/error handling
- Config: security/application configuration

## Local development

Requirements: Java 21, Maven, Docker.

```bash
docker compose up -d
mvn clean verify
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

Health:
`GET http://localhost:8080/actuator/health`

Swagger:
`http://localhost:8080/swagger-ui.html`

## Test authentication

Request:

```http
POST /api/v1/auth/otp/request
Content-Type: application/json

{"destination":"9999999999"}
```

The development SMS adapter deliberately does not log the OTP. For local testing, replace it with a test adapter that exposes the generated code only in a test profile.

Verify:

```http
POST /api/v1/auth/otp/verify
Content-Type: application/json

{"destination":"9999999999","otp":"123456"}
```

The response contains a short-lived JWT access token.

## Production work still required

This is a complete development foundation, not a production authentication/payment implementation.

Before production:
- real SMS provider adapter
- OTP attempt limits and rate limiting
- secure OTP delivery/testing strategy
- refresh-token/session management
- key rotation/JWK or external OIDC provider
- audit/security events
- payment transaction persistence and webhook verification
- real payment provider adapter
- secrets manager
- observability and alerting
- integration/security tests
