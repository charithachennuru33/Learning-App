# platform-infra

Reusable company platform infrastructure service.

## Purpose

`platform-infra` provides shared infrastructure capabilities for company applications.

Initial modules:

- `auth` - identity and authentication foundation
- `sms` - SMS provider abstraction
- `payment` - payment provider abstraction
- `common` - shared API/web concerns
- `config` - application/security configuration

Business-specific functionality must remain in application services such as `learning-backend`.

## Technology

- Java 21
- Spring Boot 3.5
- Maven
- PostgreSQL
- Redis
- Flyway
- Spring Security
- Docker
- GitHub Actions

## Architecture

```text
learning-mobile
      |
      v
learning-backend
      |
      v
platform-infra
  |      |      |
 Auth   SMS   Payment
```

## Run locally

Prerequisites:

- Java 21
- Docker
- Maven (or generate the Maven wrapper in your environment)

Start dependencies:

```bash
docker compose up -d
```

Build:

```bash
mvn clean verify
```

Run:

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

Health:

```text
GET http://localhost:8080/actuator/health
```

Swagger UI:

```text
http://localhost:8080/swagger-ui.html
```

## Important security note

The OTP endpoint in this initial skeleton is intentionally only a foundation. Before production, add:

- real SMS provider adapter
- OTP generation and secure storage
- OTP expiry
- attempt limits
- rate limiting
- abuse detection
- audit logging
- JWT/OIDC token issuance
- refresh-token strategy
- secrets management

Never log OTP values or payment credentials.

## Provider abstraction

Applications should depend on interfaces such as:

```java
PaymentGateway
SmsGateway
```

Provider-specific implementations should live behind those interfaces. This allows providers to be changed without rewriting application business logic.

## Database ownership

`platform-infra` owns platform data such as:

- users/identity
- OTP/audit records
- platform payment transaction records
- provider configuration metadata

Application services own their own business data.

Do not turn `platform-infra` into a shared business database.

## Next recommended implementation steps

1. Complete OTP authentication.
2. Add JWT/OIDC authentication.
3. Add Redis-backed OTP/rate-limit support.
4. Add production SMS adapter.
5. Add payment transaction model and provider adapter.
6. Add audit logging.
7. Add integration tests.
8. Add container image publishing in GitHub Actions.
9. Add staging deployment.
