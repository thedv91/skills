# Security — CRITICAL

Default severity: **CRITICAL**. A real exploit path BLOCKs the merge. Apply to
every changed file.

## Secrets & configuration exposure

(OWASP A02: Cryptographic Failures / Secrets Management Cheat Sheet)

- No hardcoded secrets in source or config: API keys, tokens, passwords, private
  keys, connection strings.
- No secrets committed to version control — `.env`, credentials, and key files
  are not added to the diff or to VCS.
- No secrets committed to client-side / browser bundles (anything reachable from
  the frontend is public).
- Secrets are read from a secret store / vault / environment, not logged or
  echoed; prefer rotatable secrets over long-lived static ones.

```js
// BAD
const stripe = new Stripe("sk_live_4eC39Hq...");
// GOOD
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
```

## Injection

(OWASP A03: Injection / SQL Injection Prevention Cheat Sheet)

- SQL/NoSQL queries use parameterized queries (prepared statements) or an ORM —
  never string concatenation of user input. Escaping is a last resort, not a
  primary defense.
- Input validation (allowlist) is a secondary defense only — required for things
  that can't be bound, like table/column names.
- Database accounts follow least privilege — the app does not connect as admin.
- No shell execution built from user input (`exec`, `eval`, template into a
  command). Use argument arrays / safe APIs.
- No `eval`, `new Function`, or dynamic `require`/`import` of user-controlled
  strings.

```js
// BAD
db.query(`SELECT * FROM users WHERE id = ${req.params.id}`);
// GOOD
db.query("SELECT * FROM users WHERE id = $1", [req.params.id]);
```

## XSS & output encoding

(OWASP A03: Injection / Cross Site Scripting Prevention Cheat Sheet)

- User-controlled data is output-encoded for its context (HTML body, attribute,
  JS, CSS, URL) before rendering — context determines the encoding.
- Framework auto-escaping is not bypassed (`dangerouslySetInnerHTML` /
  `innerHTML` / `v-html`, Angular `bypassSecurityTrust*`); if user HTML is
  unavoidable, sanitize with a vetted library (e.g. DOMPurify).
- Content-Type and CSP are not weakened; CSP is treated as defense in depth, not
  a substitute for encoding.

## Authentication & authorization

(OWASP A01: Broken Access Control & A07: Identification and Authentication
Failures / Authorization & Authentication Cheat Sheets)

- New endpoints/routes/handlers enforce authentication where the surrounding
  app requires it.
- Authorization is checked server-side on every request, per resource
  (object-level access) — not only hidden in the UI/client. Deny by default.
- No privilege escalation: role/owner checks are present before mutating or
  reading another user's data (no IDOR / broken object-level authorization).
- Least privilege: a user gets only the access their role needs.
- Auth failures return generic messages (no user enumeration); credentials only
  cross TLS; brute force is throttled / locked out.
- Session tokens / cookies set `HttpOnly`, `Secure`, and a sane `SameSite`.

## Redirects, SSRF & path traversal

(OWASP A10: SSRF & A01: Broken Access Control / SSRF & Unvalidated Redirects
Cheat Sheets)

- Redirect targets are validated against an allowlist — no open redirect from
  user input. Prefer mapping a token/ID to a server-side URL over passing a raw
  URL.
- Outbound requests built from user input are restricted to an allowlist of
  hosts; block internal/private ranges and cloud metadata endpoints
  (`169.254.169.254`, `127.0.0.0/8`, `10.0.0.0/8`, etc.). Don't accept full
  URLs from users; disable redirect-following in the HTTP client.
- File paths derived from user input are normalized and confined to an allowed
  root — no `../` traversal.

## Sensitive-data handling

(OWASP A02: Cryptographic Failures & A09: Logging Failures / Password Storage &
Logging Cheat Sheets)

- PII, credentials, tokens, session IDs, and secrets are not written to logs,
  error messages, or analytics. Sanitize logged data to prevent log injection
  (strip CR/LF).
- Passwords are hashed with a strong adaptive algorithm — Argon2id (preferred),
  scrypt, bcrypt (≤72 bytes), or PBKDF2 — with a per-password salt; never stored
  or compared in plaintext. Fast hashes (MD5/SHA1/SHA256) are unsuitable for
  passwords.
- Crypto uses vetted libraries and current algorithms — no home-rolled crypto,
  no MD5/SHA1 for security purposes.
- Sensitive data is encrypted in transit (TLS) and at rest.

## Dependency & integrity risk

(OWASP A06: Vulnerable and Outdated Components & A08: Software and Data Integrity
Failures)

- New dependencies are reasonable, maintained, and from a trusted source — no
  typosquatting or abandoned packages, no known-vulnerable versions.
- Lockfile changes match the intended dependency change (no unexplained or
  unpinned additions).
- No disabling of TLS/cert verification (`rejectUnauthorized: false`,
  `NODE_TLS_REJECT_UNAUTHORIZED=0`).

## Sources

- [OWASP Top 10:2021](https://owasp.org/Top10/2021/) — the ten most critical web application security risks, used for the category tags above
- [Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) — never hardcode/commit secrets, use a vault, rotate, don't log
- [SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html) — prepared statements, allowlist validation, least-privilege DB accounts
- [Cross Site Scripting Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html) — context-aware output encoding, framework escape hatches, DOMPurify, CSP
- [Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) — least privilege, deny by default, server-side checks, IDOR prevention
- [Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html) — generic errors, brute-force protection, TLS for credentials, MFA
- [Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html) — Argon2id/scrypt/bcrypt/PBKDF2, salting, avoid fast hashes
- [Server Side Request Forgery Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html) — host allowlists, block private/metadata ranges, disable redirects
- [Unvalidated Redirects and Forwards Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html) — avoid user-controlled redirects, token mapping, allowlists
- [Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html) — what not to log (secrets/PII/session IDs), log-injection prevention
