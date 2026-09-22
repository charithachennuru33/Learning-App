# platform-infra

Shared infrastructure service: phone-OTP authentication, JWT access tokens, rotating refresh tokens,
rate limiting, audit logging, and provider abstractions for SMS and payments.

## Local development

Requirements: Java 21, Maven, Docker.

```bash
docker compose up -d
mvn clean verify
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

The `dev` profile supplies local-only secrets, enables Swagger (`/swagger-ui.html`), and uses the logging SMS
adapter, which **prints the OTP to the console** instead of sending it.

Integration tests (`AuthFlowIntegrationTest`) start PostgreSQL and Redis through Testcontainers. Without
Docker they are skipped, not failed, so check the Maven output for `Skipped`.

## API

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/otp/request` | – | `{"phone":"9876543210"}` sends a code |
| POST | `/api/v1/auth/otp/verify` | – | `{"phone":"…","otp":"123456"}` returns access + refresh tokens |
| POST | `/api/v1/auth/token/refresh` | – | `{"refreshToken":"…"}` rotates the token |
| POST | `/api/v1/auth/logout` | – | `{"refreshToken":"…"}` ends that session |
| POST | `/api/v1/auth/logout-all` | Bearer | Ends every session of the caller |
| GET | `/api/v1/users/me` | Bearer | Current user |
| GET | `/actuator/health`, `/actuator/health/liveness`, `/actuator/health/readiness` | – | Probes |

Errors share one shape, with a stable `error.code` clients can branch on:

```json
{"success": false, "message": "Invalid or expired OTP", "error": {"code": "INVALID_OTP"}}
```

429 responses include a `Retry-After` header. Every response carries `X-Request-Id`, which is also in the log lines.

## Security model

- **Phone numbers** are normalised to E.164 (libphonenumber), so each person has one account however they type it.
- **OTPs** are stored in Redis as HMAC-SHA256 hashes, expire after 5 minutes, and are single-use. Five wrong
  guesses burn the code. Issuance is limited to one per 60 s and 5 per hour per phone, plus per-IP limits.
  All checks are atomic Lua scripts, so they hold across multiple instances.
- **Access tokens** are HS256 JWTs (15 min) with issuer, audience, `jti`, `kid` and `token_type` checks.
- **Refresh tokens** are random 256-bit values stored as SHA-256 hashes. Every refresh rotates the token.
  Replaying an old one revokes the whole session family (theft detection). Two clients sharing one refresh
  token will trigger this too, so each device must keep its own.
- **Logout** revokes refresh tokens. Access tokens already issued stay valid until they expire (at most 15 minutes).
- **Audit**: logins, failures, lockouts, refreshes, reuse detection and logouts go to `auth_audit_event`
  (phones masked) and to the `AUDIT` logger.
- **Disabled/locked users** cannot log in or refresh. Setting `status` revokes access within one access-token TTL.

## Production configuration

The app will not start without the required secrets. There are no unsafe defaults outside the `dev` profile.

| Variable | Required | Notes |
|---|---|---|
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | yes | PostgreSQL |
| `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `REDIS_SSL` | yes | Redis 6+ |
| `JWT_SECRET` | yes | ≥ 32 bytes: `openssl rand -base64 48` |
| `OTP_SECRET` | yes | ≥ 32 bytes, different from `JWT_SECRET` |
| `SMS_PROVIDER` | yes | `msg91` or `twilio` (`logging` is refused under the `prod` profile) |
| `MSG91_AUTH_KEY`, `MSG91_TEMPLATE_ID` | with msg91 | Template must be DLT-approved and linked in the MSG91 panel |
| `MSG91_OTP_VARIABLE` | no | Template variable for the code, default `otp` (for `##otp##`) |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` | with twilio | |
| `TWILIO_FROM_NUMBER` or `TWILIO_MESSAGING_SERVICE_SID` | with twilio | For India, use a DLT-registered sender/template |
| `SPRING_PROFILES_ACTIVE` | recommended | `prod` |
| `FORWARD_HEADERS_STRATEGY` | behind a proxy | `native`, or rate limits see the proxy's IP |
| `CORS_ALLOWED_ORIGINS` | for browsers | Comma-separated |
| `JWT_PREVIOUS_SECRETS` | during rotation | See below |
| `AUTH_DEFAULT_REGION` | no | Default `IN` |

Keep secrets in a secrets manager (AWS Secrets Manager, GCP Secret Manager, Vault, Kubernetes secrets) and
inject them as environment variables. Never commit them.

**Rotating the JWT key without logging users out:** set `JWT_PREVIOUS_SECRETS` to the current secret, set
`JWT_SECRET` to a new one, deploy, then remove the old value after 15 minutes.

**Docker:**

```bash
docker build -t platform-infra .
docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=prod -e DB_URL=... -e JWT_SECRET=... platform-infra
```

The image runs as a non-root user and shuts down gracefully on SIGTERM (20 s drain).

## Not yet production-ready

- **Payments**: only the `dev` mock exists (`PaymentController` is dev-profile only). A real provider still
  needs transaction persistence, idempotency keys and webhook signature verification.
- **Metrics/alerting**: add `micrometer-registry-prometheus` on a management port that isn't public, and
  alert on `OTP_DELIVERY_FAILED` and `REFRESH_TOKEN_REUSE_DETECTED`.
- **Audit retention**: `auth_audit_event` grows without bound; add partitioning or a retention job.
- **Abuse protection** beyond rate limits (CAPTCHA/device attestation before OTP requests) if SMS costs matter.
