# ADR 01.001 Completion Tasks

**ADR:** 01.001 Rails 8 Minimal Stack
**Current Progress:** 92.1% (82/89 requirements)
**Remaining:** 7 partially implemented items
**Goal:** Achieve 100% implementation of all 8 phases

---

## Overview

This task list completes the remaining work for ADR 01.001. The ADR defines 8 implementation phases. Currently:

- ✅ Phase 1: Initial Rails 8 Application Setup (100%)
- ✅ Phase 2: Testing Infrastructure & Development Tools (100%)
- ⚠️ Phase 3: External API Client Setup (0% - **needs completion**)
- ✅ Phase 4: money-rails Rails 8 Compatibility Testing (100%)
- ⚠️ Phase 5: Production Deployment to Heroku (0% - **needs completion**)
- ✅ Phase 6: Security Hardening & Rate Limiting (100%)
- ⚠️ Phase 7: Caching & Performance Optimization (60% - **needs completion**)
- ⚠️ Phase 8: Observability & Business Metrics (80% - **needs completion**)

---

## Task Breakdown by Wave

### Wave 1: External API Client Setup (Phase 3)
**Dependencies:** None
**Estimated Time:** 2-3 hours
**Status:** Not started

#### Task 1.1: Create Plaid Initializer
- [ ] Create `config/initializers/plaid.rb`
- [ ] Configure Plaid client with credentials from Rails.application.credentials
- [ ] Set environment (sandbox/development/production)
- [ ] Add error handling for missing credentials
- [ ] Document required credentials in README

**Acceptance Criteria:**
- Plaid client initializes without errors
- Can make test API call to Plaid sandbox
- Credentials loaded from encrypted credentials file

**Files to create:**
- `config/initializers/plaid.rb` (~20 lines)

---

#### Task 1.2: Create OpenAI Initializer
- [ ] Create `config/initializers/openai.rb`
- [ ] Configure OpenAI client with API key from Rails.application.credentials
- [ ] Set organization ID (if applicable)
- [ ] Add timeout and retry configuration
- [ ] Document required credentials

**Acceptance Criteria:**
- OpenAI client initializes without errors
- Can make test completion API call
- API key loaded from encrypted credentials

**Files to create:**
- `config/initializers/openai.rb` (~15 lines)

---

#### Task 1.3: Create Anthropic Initializer
- [ ] Update `config/initializers/anthropic.rb` (currently exists but empty)
- [ ] Configure Anthropic client with API key from Rails.application.credentials
- [ ] Set timeout and retry configuration
- [ ] Add error handling for missing credentials
- [ ] Document required credentials

**Acceptance Criteria:**
- Anthropic client initializes without errors
- Can make test messages API call
- API key loaded from encrypted credentials

**Files to update:**
- `config/initializers/anthropic.rb` (~15 lines)

---

#### Task 1.4: Create TaxCloud Initializer
- [ ] Create `config/initializers/tax_cloud.rb`
- [ ] Configure TaxCloud SOAP client with credentials from Rails.application.credentials
- [ ] Set API ID and API key
- [ ] Add USPS user ID for address verification (optional)
- [ ] Document required credentials

**Acceptance Criteria:**
- TaxCloud client initializes without errors
- Can make test lookup API call
- Credentials loaded from encrypted credentials

**Files to create:**
- `config/initializers/tax_cloud.rb` (~20 lines)

---

#### Task 1.5: Create VCR Cassettes for External APIs
- [ ] Create VCR cassette for Plaid item creation
- [ ] Create VCR cassette for Plaid transactions fetch
- [ ] Create VCR cassette for OpenAI completion
- [ ] Create VCR cassette for OpenAI embeddings
- [ ] Create VCR cassette for Anthropic messages
- [ ] Create VCR cassette for TaxCloud lookup
- [ ] Update VCR configuration to filter API keys

**Acceptance Criteria:**
- All cassettes recorded successfully
- Cassettes replay without network calls
- Sensitive data (API keys) filtered from cassettes
- Tests pass using cassettes

**Files to create:**
- `test/vcr_cassettes/plaid_item_create.yml`
- `test/vcr_cassettes/plaid_transactions.yml`
- `test/vcr_cassettes/openai_completion.yml`
- `test/vcr_cassettes/openai_embeddings.yml`
- `test/vcr_cassettes/anthropic_messages.yml`
- `test/vcr_cassettes/tax_cloud_lookup.yml`

**Files to update:**
- `test/support/vcr.rb` (add filter_sensitive_data for new API keys)

---

#### Task 1.6: Create Integration Tests for External APIs
- [ ] Create `test/integration/plaid_client_test.rb`
- [ ] Create `test/integration/openai_client_test.rb`
- [ ] Create `test/integration/anthropic_client_test.rb`
- [ ] Create `test/integration/tax_cloud_client_test.rb`
- [ ] Test client initialization
- [ ] Test basic API calls with VCR
- [ ] Test error handling (missing credentials, API errors)

**Acceptance Criteria:**
- All integration tests pass
- Tests use VCR cassettes (no real API calls)
- Tests verify client configuration
- Tests cover error scenarios

**Files to create:**
- `test/integration/plaid_client_test.rb` (~40 lines)
- `test/integration/openai_client_test.rb` (~40 lines)
- `test/integration/anthropic_client_test.rb` (~40 lines)
- `test/integration/tax_cloud_client_test.rb` (~40 lines)

---

#### Task 1.7: Update Encrypted Credentials Template
- [ ] Add Plaid credentials placeholders to credentials.yml.enc
- [ ] Add OpenAI API key placeholder
- [ ] Add Anthropic API key placeholder
- [ ] Add TaxCloud credentials placeholders
- [ ] Add AWS S3 credentials placeholders
- [ ] Document credential structure in README

**Acceptance Criteria:**
- All required credentials documented
- Template includes comments explaining each credential
- README documents how to add credentials

**Files to update:**
- `config/credentials.yml.enc` (via `rails credentials:edit`)
- `README.md` (add "Configuration" section)

---

### Wave 2: Admin Metrics Dashboard (Phase 8)
**Dependencies:** None (metrics tracking already complete)
**Estimated Time:** 2-3 hours
**Status:** Not started

#### Task 2.1: Create Admin::MetricsController
- [ ] Create `app/controllers/admin/metrics_controller.rb`
- [ ] Add `index` action to display metrics dashboard
- [ ] Add authorization check (superuser only)
- [ ] Fetch all business metrics (anomaly queue, AI confidence, entry posting, cache hit rate)
- [ ] Calculate 24-hour trends
- [ ] Render metrics with color coding (green/yellow/red)

**Acceptance Criteria:**
- Controller requires superuser authentication
- Fetches all business metrics from MetricsTracker
- Calculates trends (24h comparison)
- Returns 403 for non-superusers

**Files to create:**
- `app/controllers/admin/metrics_controller.rb` (~60 lines)

---

#### Task 2.2: Create Admin::MetricsPolicy
- [ ] Create `app/policies/admin/metrics_policy.rb`
- [ ] Restrict `index?` to superusers only
- [ ] Add policy tests

**Acceptance Criteria:**
- Only superusers can view metrics dashboard
- Policy tested for user, admin, superuser roles

**Files to create:**
- `app/policies/admin/metrics_policy.rb` (~15 lines)
- `test/policies/admin/metrics_policy_test.rb` (~30 lines)

---

#### Task 2.3: Create Admin Metrics Dashboard View
- [ ] Create `app/views/admin/metrics/index.html.erb`
- [ ] Display anomaly queue depth (target: <50, alert: >100)
- [ ] Display AI confidence average (target: >95%, alert: <90%)
- [ ] Display entry posting success rate (target: >99%, alert: <95%)
- [ ] Display cache hit rate (target: >80%, alert: <80%)
- [ ] Display job failures per hour (target: 0, alert: >10)
- [ ] Color-code metrics: green (healthy), yellow (warning), red (alert)
- [ ] Show 24-hour trend (up/down/stable)
- [ ] Use TailwindCSS for styling

**Acceptance Criteria:**
- All business metrics displayed
- Color coding matches thresholds
- Responsive design (mobile-friendly)
- Shows last updated timestamp

**Files to create:**
- `app/views/admin/metrics/index.html.erb` (~100 lines)

---

#### Task 2.4: Add Admin Routes
- [ ] Add `namespace :admin` to routes
- [ ] Add `resources :metrics, only: [:index]` route
- [ ] Add admin dashboard root (optional: redirect to metrics)

**Acceptance Criteria:**
- `/admin/metrics` route exists
- Route requires authentication
- Admin root configured

**Files to update:**
- `config/routes.rb` (~5 lines)

---

#### Task 2.5: Create Admin Metrics Controller Tests
- [ ] Create `test/controllers/admin/metrics_controller_test.rb`
- [ ] Test unauthorized access (non-superuser)
- [ ] Test authorized access (superuser)
- [ ] Test metrics data presence
- [ ] Test color coding logic

**Acceptance Criteria:**
- Tests cover authorization
- Tests verify metrics data
- Tests check view rendering

**Files to create:**
- `test/controllers/admin/metrics_controller_test.rb` (~80 lines)

---

### Wave 3: Cache Warming Background Job (Phase 7)
**Dependencies:** CacheService (already complete)
**Estimated Time:** 1 hour
**Status:** Not started

#### Task 3.1: Create CacheWarmingJob
- [ ] Create `app/jobs/cache_warming_job.rb`
- [ ] Pre-warm chart of accounts cache (when Account model exists)
- [ ] Pre-warm dashboard cache (when dashboard exists)
- [ ] Use `CacheService.warm_cache` method
- [ ] Schedule to run every 10 minutes off-peak (configurable)
- [ ] Log cache warming results

**Acceptance Criteria:**
- Job runs without errors
- Caches pre-warmed successfully
- Logs cache keys warmed
- Gracefully handles missing data (e.g., no accounts yet)

**Files to create:**
- `app/jobs/cache_warming_job.rb` (~40 lines)

---

#### Task 3.2: Configure Cache Warming Recurring Task
- [ ] Add cache warming to `config/queue.yml` recurring tasks
- [ ] Set schedule (every 10 minutes, configurable)
- [ ] Document configuration in comments

**Acceptance Criteria:**
- Recurring task configured in Solid Queue
- Schedule documented
- Task runs automatically

**Files to update:**
- `config/queue.yml` (~5 lines)

---

#### Task 3.3: Create Cache Warming Job Tests
- [ ] Create `test/jobs/cache_warming_job_test.rb`
- [ ] Test job execution
- [ ] Test cache warming with mock data
- [ ] Test error handling (missing models)

**Acceptance Criteria:**
- Tests verify cache warming
- Tests cover error cases
- Tests don't require real data

**Files to create:**
- `test/jobs/cache_warming_job_test.rb` (~50 lines)

---

### Wave 4: Deferred Caching Features (Phase 7)
**Dependencies:** ADR 04.001 (Account model), ADR 06.002 (AI categorizer), Dashboard views
**Estimated Time:** 3-4 hours
**Status:** Not started (waiting on other ADRs)

#### Task 4.1: Implement Russian Doll Caching in Account Views
- [ ] **DEFERRED** until Account model exists (ADR 04.001)
- [ ] Add Russian Doll caching to `app/views/accounts/index.html.erb`
- [ ] Add Russian Doll caching to `app/views/accounts/_account.html.erb` partial
- [ ] Use `CacheHelper.nested_cache_key`
- [ ] Test cache invalidation on account update

**Note:** This task is blocked by ADR 04.001 implementation.

---

#### Task 4.2: Implement Russian Doll Caching in Dashboard Views
- [ ] **DEFERRED** until dashboard views exist
- [ ] Add fragment caching to `app/views/dashboard/index.html.erb`
- [ ] Use `CacheHelper.composite_cache_key` for multi-record views
- [ ] Set 5-minute TTL per ADR specification
- [ ] Test cache invalidation on entry posting

**Note:** This task is blocked by dashboard implementation.

---

#### Task 4.3: Implement Chart of Accounts Caching
- [ ] **DEFERRED** until Account model exists (ADR 04.001)
- [ ] Create `cached_chart_of_accounts` method in AccountsController
- [ ] Use `Rails.cache.fetch` with 1-hour TTL
- [ ] Invalidate on account create/update
- [ ] Test caching behavior

**Note:** This task is blocked by ADR 04.001 implementation.

---

#### Task 4.4: Implement AI Embedding Similarity Search Caching
- [ ] **DEFERRED** until AI categorizer exists (ADR 06.002)
- [ ] Add caching to `find_similar_transactions` method
- [ ] Use SHA256 hash of description as cache key
- [ ] Set infinite TTL (embeddings immutable)
- [ ] Test caching with pgvector queries

**Note:** This task is blocked by ADR 06.002 implementation.

---

### Wave 5: Heroku Production Deployment (Phase 5)
**Dependencies:** All previous waves
**Estimated Time:** 2-3 hours
**Status:** Not started (deployment process)

#### Task 5.1: Create Heroku Application
- [ ] Run `heroku create grayledger-production`
- [ ] Set app region (US or EU)
- [ ] Configure custom domain (optional)
- [ ] Document Heroku app name

**Acceptance Criteria:**
- Heroku app created
- Git remote `heroku` configured
- App accessible at Heroku URL

**Files to update:**
- `README.md` (add "Deployment" section)

---

#### Task 5.2: Provision Heroku Postgres with pgvector
- [ ] Add Heroku Postgres addon: `heroku addons:create heroku-postgresql:essential-0`
- [ ] Enable pgvector extension: `heroku pg:psql -c "CREATE EXTENSION IF NOT EXISTS vector;"`
- [ ] Verify extension: `heroku pg:psql -c "\dx"`
- [ ] Document database configuration

**Acceptance Criteria:**
- Postgres addon provisioned
- pgvector extension enabled
- DATABASE_URL environment variable set

---

#### Task 5.3: Configure Heroku Environment Variables
- [ ] Set `RAILS_MASTER_KEY`: `heroku config:set RAILS_MASTER_KEY=<key>`
- [ ] Set `ALERT_EMAIL`: `heroku config:set ALERT_EMAIL=alerts@grayledger.io`
- [ ] Set `JOB_CONCURRENCY`: `heroku config:set JOB_CONCURRENCY=3`
- [ ] Set `RAILS_LOG_LEVEL`: `heroku config:set RAILS_LOG_LEVEL=info`
- [ ] Verify all config vars: `heroku config`

**Acceptance Criteria:**
- All required environment variables set
- Credentials decryptable in production
- No secrets in git history

---

#### Task 5.4: Set Up AWS S3 for Active Storage
- [ ] Create S3 bucket: `grayledger-production-storage`
- [ ] Configure bucket policy (private, signed URLs)
- [ ] Create IAM user with S3 access
- [ ] Generate AWS access key + secret
- [ ] Update `config/storage.yml` for production
- [ ] Set Heroku config vars: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_BUCKET`

**Acceptance Criteria:**
- S3 bucket created and configured
- IAM user has correct permissions
- Active Storage configured for production
- Can upload test file via console

**Files to update:**
- `config/storage.yml` (uncomment amazon section)
- `config/environments/production.rb` (set `config.active_storage.service = :amazon`)

---

#### Task 5.5: Deploy Application to Heroku
- [ ] Push to Heroku: `git push heroku main`
- [ ] Run migrations: `heroku run rails db:migrate`
- [ ] Verify deployment: `heroku open`
- [ ] Check logs: `heroku logs --tail`
- [ ] Test smoke tests (homepage, jobs UI)

**Acceptance Criteria:**
- Application deploys without errors
- Database migrations run successfully
- Application loads at production URL
- No errors in logs

---

#### Task 5.6: Verify Solid Queue in Production
- [ ] Check Solid Queue processes: `heroku run rails solid_queue:start`
- [ ] Access Mission Control Jobs UI: `https://<app>.herokuapp.com/jobs`
- [ ] Run test job: `heroku run rails runner "TestJob.perform_later"`
- [ ] Verify job execution in Mission Control
- [ ] Check MetricsCollectionJob runs every 5 minutes

**Acceptance Criteria:**
- Solid Queue processes jobs
- Mission Control UI accessible
- Test job executes successfully
- Recurring tasks running

---

#### Task 5.7: Smoke Test Production Integrations
- [ ] Test Active Storage upload (if views exist)
- [ ] Test Solid Cache operations: `heroku run rails console` → `Rails.cache.write/read`
- [ ] Verify Rack::Attack rate limiting (make requests to /test_throttle endpoints)
- [ ] Check metrics tracking in database
- [ ] Verify alert emails (trigger threshold, check email delivery)

**Acceptance Criteria:**
- All integrations working in production
- No errors in logs
- Metrics tracked successfully
- Rate limiting active

---

#### Task 5.8: Document Deployment Process
- [ ] Update README with deployment instructions
- [ ] Document environment variables
- [ ] Document database setup
- [ ] Document S3 configuration
- [ ] Document common Heroku commands
- [ ] Create troubleshooting guide

**Acceptance Criteria:**
- README has "Deployment" section
- All steps documented
- Troubleshooting section added

**Files to update:**
- `README.md` (add ~100 lines)

---

### Wave 6: Final Validation & Documentation
**Dependencies:** All previous waves
**Estimated Time:** 1-2 hours
**Status:** Not started

#### Task 6.1: Run Full Test Suite
- [ ] Run `rails test` (all unit + integration tests)
- [ ] Run `rails test:system` (system tests)
- [ ] Verify 100% pass rate
- [ ] Check SimpleCov coverage (target: 90%+)
- [ ] Fix any failing tests

**Acceptance Criteria:**
- All tests pass (330+ tests)
- Coverage ≥90% on critical paths
- No deprecation warnings

---

#### Task 6.2: Run Linters and Security Scans
- [ ] Run `standardrb` (Ruby linter)
- [ ] Run `brakeman` (security scanner)
- [ ] Run `bundle audit` (gem vulnerabilities)
- [ ] Fix any issues found

**Acceptance Criteria:**
- No linter errors
- No security vulnerabilities
- No gem vulnerabilities

---

#### Task 6.3: Verify All ADR 01.001 Goals Checked
- [ ] Review ADR 01.001 "Goals" section (lines 542-552)
- [ ] Verify all checkboxes marked complete
- [ ] Update ADR if needed

**Acceptance Criteria:**
- All 9 goals checked in ADR
- Implementation matches ADR specification

**Files to update:**
- `docs/adrs/01.foundation/01.001.rails-8-minimal-stack.md` (lines 542-552)

---

#### Task 6.4: Update CLAUDE.md with Completion Status
- [ ] Update `CLAUDE.md` "Active Feature" section
- [ ] Mark ADR 01.001 as ✅ COMPLETE
- [ ] Update verification status
- [ ] Document any deferred items (Wave 4)

**Acceptance Criteria:**
- CLAUDE.md reflects completion
- Deferred items documented

**Files to update:**
- `CLAUDE.md` (lines 10-22)

---

#### Task 6.5: Create Completion Summary Document
- [ ] Create `dev/adr-01.001-completion-summary.md`
- [ ] Document what was completed
- [ ] Document deferred items (Wave 4)
- [ ] Document production deployment details
- [ ] Include metrics and test results

**Acceptance Criteria:**
- Summary document created
- All achievements documented
- Deferred items clearly marked

**Files to create:**
- `dev/adr-01.001-completion-summary.md` (~50 lines)

---

## Dependency Graph

```
Wave 1 (External API Setup) ──────┐
Wave 2 (Admin Dashboard) ─────────┤
Wave 3 (Cache Warming Job) ───────┼─→ Wave 5 (Heroku Deployment) ─→ Wave 6 (Final Validation)
Wave 4 (Deferred Caching) ────────┘      ↑
  ├─ Blocked by ADR 04.001              │
  ├─ Blocked by ADR 06.002              │
  └─ Blocked by Dashboard views          │
                                         │
                                    (Wave 4 can be
                                     completed later)
```

---

## Progress Tracking

### Wave 1: External API Setup (0/7 tasks)
- [ ] Task 1.1: Plaid initializer
- [ ] Task 1.2: OpenAI initializer
- [ ] Task 1.3: Anthropic initializer
- [ ] Task 1.4: TaxCloud initializer
- [ ] Task 1.5: VCR cassettes
- [ ] Task 1.6: Integration tests
- [ ] Task 1.7: Credentials template

### Wave 2: Admin Dashboard (0/5 tasks)
- [ ] Task 2.1: MetricsController
- [ ] Task 2.2: MetricsPolicy
- [ ] Task 2.3: Dashboard view
- [ ] Task 2.4: Routes
- [ ] Task 2.5: Controller tests

### Wave 3: Cache Warming (0/3 tasks)
- [ ] Task 3.1: CacheWarmingJob
- [ ] Task 3.2: Configure recurring task
- [ ] Task 3.3: Job tests

### Wave 4: Deferred Caching (0/4 tasks - DEFERRED)
- [ ] Task 4.1: Account views caching (blocked by ADR 04.001)
- [ ] Task 4.2: Dashboard views caching (blocked by views)
- [ ] Task 4.3: Chart of accounts caching (blocked by ADR 04.001)
- [ ] Task 4.4: AI embedding caching (blocked by ADR 06.002)

### Wave 5: Heroku Deployment (0/8 tasks)
- [ ] Task 5.1: Create Heroku app
- [ ] Task 5.2: Provision Postgres with pgvector
- [ ] Task 5.3: Configure environment variables
- [ ] Task 5.4: Set up AWS S3
- [ ] Task 5.5: Deploy application
- [ ] Task 5.6: Verify Solid Queue
- [ ] Task 5.7: Smoke test integrations
- [ ] Task 5.8: Document deployment

### Wave 6: Final Validation (0/5 tasks)
- [ ] Task 6.1: Full test suite
- [ ] Task 6.2: Linters and security scans
- [ ] Task 6.3: Verify ADR goals
- [ ] Task 6.4: Update CLAUDE.md
- [ ] Task 6.5: Completion summary

---

## Total: 32 tasks (28 immediate + 4 deferred)

**Immediate:** Waves 1-3, 5-6 (28 tasks)
**Deferred:** Wave 4 (4 tasks - waiting on other ADRs)

---

## Estimated Timeline

- **Wave 1:** 2-3 hours (can parallelize initializers)
- **Wave 2:** 2-3 hours
- **Wave 3:** 1 hour
- **Wave 4:** 3-4 hours (DEFERRED - complete with ADR 04.001 and 06.002)
- **Wave 5:** 2-3 hours
- **Wave 6:** 1-2 hours

**Total (immediate work):** 8-12 hours
**Total (with deferred):** 11-16 hours

---

## Notes

1. **Wave 4 is intentionally deferred** - These caching features depend on models and views from other ADRs (04.001, 06.002). They can be completed when those ADRs are implemented.

2. **External API credentials** - You'll need to obtain API keys for Plaid, OpenAI, Anthropic, and TaxCloud before running Wave 1 tasks. Use sandbox/test keys for development.

3. **Heroku deployment** - Wave 5 requires a Heroku account and AWS account. Costs: ~$7/month (Postgres Essential-0) + S3 storage (~$1/month).

4. **VCR cassettes** - Record cassettes using real API calls once, then tests replay without network access. Keep cassettes in git for CI/CD.

5. **Production deployment** - Wave 5 can be done incrementally (e.g., deploy without S3 first, add S3 later).

---

## Success Criteria

ADR 01.001 will be considered **100% COMPLETE** when:

✅ All Wave 1-3 tasks completed (External APIs, Admin Dashboard, Cache Warming)
✅ All Wave 5 tasks completed (Heroku Deployment)
✅ All Wave 6 tasks completed (Final Validation)
✅ All tests passing (330+ tests)
✅ Coverage ≥90% on critical paths
✅ Production deployment verified
✅ Wave 4 tasks documented as deferred (to be completed with ADR 04.001 and 06.002)

At that point, the ADR can be marked as FULLY IMPLEMENTED and archived to `docs/decisions/completed/`.
