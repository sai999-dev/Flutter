# Middleware Integration Guide (Mobile App ↔ Middleware ↔ Admin Portal/DB)

Audience: Middleware engineers building and maintaining the Node.js layer that powers the Flutter mobile app under the `/api/mobile/*` namespace, orchestrating with the Admin Portal backend and the database.

Last Updated: 2025-11-05

---

## 1) High-level architecture

```
Flutter Mobile App  ⇄  Middleware (Node.js/Express/Nest)  ⇄  Admin Portal API/Services
                                 │
                                 └── Database (Postgres/MySQL)
```

Responsibilities:
- Mobile app talks ONLY to Middleware under `/api/mobile/*`.
- Middleware owns:
  - Auth/JWT, device registration, and secure session handling
  - Payment orchestration with Stripe (server-side secret operations)
  - Leads, Territories, Subscriptions routing and business logic
  - Document uploads (ingress), storage pointers, and verification state tracking
  - Data persistence and synchronization with the Admin Portal backend

Non-goals for mobile: The app never calls Admin Portal or Stripe directly with secrets.

---

## 2) Base URLs and health

- Mobile discovers a working base URL via `GET /api/health`.
- Production base URL must be stable and HTTPS.

Example (Express):
```js
app.get('/api/health', (req, res) => res.status(200).json({ ok: true, ts: Date.now() }));
```

---

## 3) Authentication & JWT

- Registration/Login return a signed JWT.
- All protected endpoints check `Authorization: Bearer <jwt>`.
- Use a JWT middleware that extracts the user/agency and injects into `req.user`.

Example:
```js
// jwt-middleware.js
module.exports = function jwtMiddleware(secret) {
  return (req, res, next) => {
    const auth = req.headers.authorization || '';
    const [, token] = auth.split(' ');
    if (!token) return res.status(401).json({ success: false, message: 'No token' });
    try {
      req.user = require('jsonwebtoken').verify(token, secret);
      next();
    } catch (e) {
      return res.status(401).json({ success: false, message: 'Invalid token' });
    }
  };
};
```

---

## 4) Endpoint contracts (summary)

All routes are under `/api/mobile/*`:

- Auth: `/auth/register`, `/auth/login`, `/auth/verify-email`, `/auth/forgot-password`, `/auth/register-device`, `/auth/update-device`, `/auth/unregister-device`, `/auth/upload-document`, `/auth/verification-status`, `/auth/documents`
- Subscriptions/Payments: `/subscription/plans`, `/subscription`, `/subscription/subscribe`, `/subscription/upgrade`, `/subscription/downgrade`, `/subscription/cancel`, `/subscription/invoices`, `/payment-method`
- Leads: `/leads`, `/leads/:leadId`, `/leads/:leadId/status`, `/leads/:leadId/view`, `/leads/:leadId/call`, `/leads/:leadId/notes`, `/leads/:leadId/accept`, `/leads/:leadId/reject`
- Territories: `/territories` (GET/POST), `/territories/:id` (PUT/DELETE)
- Notifications: `/notifications/settings` (GET/PUT)
- Health: `/api/health`

See `FINAL_MOBILE_API_CONNECTIONS.md` for request/response examples expected by the client.

---

## 5) Controller → Service → Repository (pattern)

Recommended layering:
- Controller: parse/validate HTTP, map to service calls
- Service: business logic, Stripe orchestration, Admin Portal calls
- Repository: DB persistence (ORM like Prisma/Sequelize/TypeORM)

Example: Auth Register
```js
// routes/auth.js
router.post('/register', async (req, res) => {
  try {
    const dto = req.body; // email, password, agency_name, zipcodes[], plan_id, payment_method_id?
    const result = await authService.register(dto);
    return res.status(201).json(result); // { token, agency_id, user_profile }
  } catch (e) {
    return res.status(e.statusCode || 400).json({ success: false, error: e.message });
  }
});
```

```js
// services/auth-service.js
async function register({ email, password, agency_name, zipcodes = [], plan_id, payment_method_id, ...rest }) {
  // 1) Validate input
  // 2) Create agency & user in DB (hash password)
  const agency = await agencyRepo.create({ email, agency_name, ...rest });
  await userRepo.create({ agencyId: agency.id, email, passwordHash: hash(password) });

  // 3) Optionally create/attach Stripe customer + payment method + subscription
  if (plan_id) {
    const customerId = await billing.ensureCustomerForAgency(agency.id, email);
    if (payment_method_id) await billing.attachPaymentMethod(customerId, payment_method_id);
    await billing.ensureSubscription(customerId, plan_id);
  }

  // 4) Sync with Admin Portal (two-way): create/update agency profile
  await adminPortal.upsertAgency({
    agencyId: agency.id,
    email,
    agencyName: agency_name,
    zipcodes,
    planId: plan_id || null,
  });

  // 5) Issue JWT
  const token = signJwt({ agency_id: agency.id, email });
  return { token, agency_id: agency.id, user_profile: { email, agency_name } };
}
```

```js
// billing/stripe.js (server-side secret operations)
module.exports = {
  async ensureCustomerForAgency(agencyId, email) { /* create/retrieve Stripe customer by agencyId */ },
  async attachPaymentMethod(customerId, paymentMethodId) { /* stripe.paymentMethods.attach */ },
  async ensureSubscription(customerId, planId) { /* stripe.subscriptions.create */ },
};
```

```js
// integrations/admin-portal.js
module.exports = {
  async upsertAgency(payload) {
    // POST/PUT to Admin Portal API or call internal service
  },
  async fetchPlans() { /* GET /plans from Admin Portal */ },
};
```

---

## 6) Database integration

- Use a robust ORM (Prisma/Sequelize/TypeORM) and migrations.
- Key tables (example): agencies, users, territories, leads, subscriptions, documents, devices, invoices.
- Index on: agency_id, email, lead status, created_at.
- Keep `external_id` fields for stable references to Admin Portal/Stripe ids (e.g., `stripe_customer_id`).

Repository sketch:
```js
// repos/agency-repo.js
module.exports = {
  create(data) { /* INSERT agencies ... RETURNING id */ },
  findByEmail(email) { /* SELECT ... */ },
  update(id, patch) { /* UPDATE ... */ },
};
```

---

## 7) Admin Portal integration (two-way)

Patterns:
- Outbound (from Middleware):
  - On registration/update: upsert agency profile and territories to the Admin Portal
  - On plan queries: read plans from Admin Portal (`/plans?isActive=true`)
- Inbound (from Admin Portal):
  - Use webhooks or message bus to receive updates (e.g., plan changes, manual verification decisions)
- Idempotency:
  - Use `Idempotency-Key` on write calls; store keys in DB to avoid duplicate effects
- Retry policy:
  - Exponential backoff for Admin Portal transient errors

---

## 8) Stripe integration (server-side)

- Mobile sends `payment_method_id` (created via Stripe SDK client-side)
- Middleware:
  - Creates/retrieves Stripe Customer for the agency
  - Attaches PaymentMethod to Customer
  - Creates Subscription or PaymentIntent
  - Stores Stripe ids and status in DB (customer id, subscription id, latest invoice id)
- Webhooks (essential):
  - `invoice.payment_succeeded`, `invoice.payment_failed`, `customer.subscription.updated` → update DB and notify Admin Portal
- Security:
  - All Stripe secret keys via env vars (`STRIPE_SECRET_KEY`)
  - Verify webhook signatures

---

## 9) Documents (verification)

- Endpoint: `POST /api/mobile/auth/upload-document` (multipart), plus GET list/status
- Upload flow:
  1) Middleware accepts file (PDF/PNG/JPG up to 10MB)
  2) Store in object storage (S3/GCS/Azure), save metadata in DB
  3) Notify Admin Portal for review, or mark status `pending`
  4) Verification decisions from Admin Portal update status to `approved|rejected` (webhook or internal call)

---

## 10) Leads

- List: `GET /api/mobile/leads` with `status/from_date/to_date/limit`
- Detail/Actions: mark viewed, accept, reject, add notes, track call
- Permissions: scope all queries by `req.user.agency_id`
- Caching: add short TTL caching if needed; always prefer correctness

---

## 11) Notifications & devices

- Device registration updates device tokens for push
- Notification preferences are stored per agency and can be synced to Admin Portal if needed

---

## 12) Error handling and response format

Standardize JSON:
```json
{ "success": true, "data": { ... }, "message": "OK" }
```
```json
{ "success": false, "error": "Message", "message": "Details", "statusCode": 400 }
```

- Map validation errors to 400, auth to 401, forbidden to 403, not found to 404, conflicts to 409, rate limit to 429.

---

## 13) Security & ops checklist

- Env vars: JWT_SECRET, STRIPE_SECRET_KEY, DB_URL, ADMIN_PORTAL_URL, CORS_ALLOWED_ORIGINS
- JWT expiry/refresh policy
- CORS allowlist (mobile apps origins if applicable)
- Rate limiting & request size limits (multipart up to 10MB)
- Input validation (zod/joi/express-validator)
- Logging (correlation IDs), metrics, tracing
- Health, readiness, liveness probes
- OpenAPI/Swagger for `/api/mobile/*`
- CI: unit/integration tests; e2e against a seeded DB

---

## 14) Local development

- Run DB locally (Docker Compose recommended)
- Seed base data (plans, a demo agency)
- Start Admin Portal API (staging/local) or mock
- Start Middleware: `PORT=3000 node server.js`
- Mobile app will detect `http://localhost:3000` via health check

---

## 15) Example route wiring (Express)

```js
const express = require('express');
const router = express.Router();
const jwt = require('./middlewares/jwt-middleware')(process.env.JWT_SECRET);

// Auth
router.post('/auth/register', require('./routes/auth').register);
router.post('/auth/login', require('./routes/auth').login);
router.post('/auth/verify-email', require('./routes/auth').verifyEmail);
router.post('/auth/forgot-password', require('./routes/auth').forgotPassword);
router.post('/auth/register-device', jwt, require('./routes/auth').registerDevice);
router.put('/auth/update-device', jwt, require('./routes/auth').updateDevice);
router.delete('/auth/unregister-device', jwt, require('./routes/auth').unregisterDevice);
router.post('/auth/upload-document', jwt, require('./routes/documents').upload);
router.get('/auth/verification-status', jwt, require('./routes/documents').status);
router.get('/auth/documents', jwt, require('./routes/documents').list);

// Subscriptions & payments
router.get('/subscription/plans', require('./routes/subscription').plans);
router.get('/subscription', jwt, require('./routes/subscription').get);
router.post('/subscription/subscribe', jwt, require('./routes/subscription').subscribe);
router.put('/subscription/upgrade', jwt, require('./routes/subscription').upgrade);
router.put('/subscription/downgrade', jwt, require('./routes/subscription').downgrade);
router.post('/subscription/cancel', jwt, require('./routes/subscription').cancel);
router.get('/subscription/invoices', jwt, require('./routes/subscription').invoices);
router.put('/payment-method', jwt, require('./routes/subscription').updatePaymentMethod);

// Leads
router.get('/leads', jwt, require('./routes/leads').list);
router.get('/leads/:leadId', jwt, require('./routes/leads').detail);
router.put('/leads/:leadId/status', jwt, require('./routes/leads').updateStatus);
router.put('/leads/:leadId/view', jwt, require('./routes/leads').markViewed);
router.post('/leads/:leadId/call', jwt, require('./routes/leads').trackCall);
router.post('/leads/:leadId/notes', jwt, require('./routes/leads').addNotes);
router.put('/leads/:leadId/accept', jwt, require('./routes/leads').accept);
router.put('/leads/:leadId/reject', jwt, require('./routes/leads').reject);

// Territories
router.get('/territories', jwt, require('./routes/territories').list);
router.post('/territories', jwt, require('./routes/territories').add);
router.put('/territories/:id', jwt, require('./routes/territories').update);
router.delete('/territories/:id', jwt, require('./routes/territories').remove);

module.exports = router;
```

Mount under `/api/mobile`:
```js
app.use('/api/mobile', mobileRouter);
```

---

## 16) Two-way sync patterns

- Use change-data-capture or eventing to propagate Admin Portal changes back to Middleware (webhooks, pub/sub, or polling with ETags/If-Modified-Since)
- Store `updated_at`/`version` to reconcile conflicts
- Keep mapping tables if identifiers differ between systems
- Build idempotent handlers; use `Idempotency-Key`

---

## 17) Monitoring & alerting

- Log structured JSON (requestId, agencyId, route)
- Export metrics (p95 latency, 4xx/5xx, throughput)
- Alerts on health check flaps, Stripe webhook failures, Admin Portal timeouts

---

## 18) Acceptance checklist

- [ ] All `/api/mobile/*` routes implemented
- [ ] JWT middleware applied where required
- [ ] Stripe secret keys in env; webhook endpoint verified
- [ ] Admin Portal URLs configured; retries & timeouts in place
- [ ] DB migrations applied; indexes added
- [ ] CORS, rate-limits, body size limits
- [ ] Health/readiness probes return 200
- [ ] Swagger/OpenAPI published
- [ ] CI pipeline runs unit/integration tests

---

For request/response examples used by the client, see `FINAL_MOBILE_API_CONNECTIONS.md`. This guide focuses on the server wiring, data orchestration, and operations to keep Mobile ⇄ Middleware ⇄ Admin Portal/DB in sync and production‑ready.
