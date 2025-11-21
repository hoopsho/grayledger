# TASKS: ADR 01.001 - Rails 8 Minimal Stack Implementation

**Source:** [ADR 01.001](../docs/adrs/01.foundation/01.001.rails-8-minimal-stack.md) | [PRD](./prd-from-adr-01.001.md)
**Feature Branch:** `feature/adr-01.001-rails-8-minimal-stack`
**Status:** In Progress - Wave 2 Complete
**Progress:** 7/25 tasks complete (28%)

---

## Wave 1: Rails Foundation (No Dependencies)

**Goal:** Initialize Rails 8 application with core configuration

### TASK-1.1: Initialize Rails 8 Application
- **Status:** [x] DONE
- **Dependencies:** None
- **Blocks:** ALL subsequent tasks
- **Completed:** 2025-11-21
- **Notes:** Rails 8.1.1 initialized with PostgreSQL, zero build step
- **Acceptance Criteria:**
  - Rails 8.0+ application initialized with PostgreSQL
  - Directory structure follows Rails conventions
  - `rails server` starts without errors
  - `rails test` runs (even if empty)
- **Files to Create:**
  - `config/database.yml`
  - `config/application.rb`
  - `Gemfile`
  - `config/routes.rb`
  - Standard Rails directory structure

### TASK-1.2: Configure PostgreSQL Database
- **Status:** [x] DONE
- **Dependencies:** TASK-1.1
- **Blocks:** TASK-2.1, TASK-2.2, TASK-6.1
- **Completed:** 2025-11-21
- **Notes:** Created grayledger_development and grayledger_test databases, PostgreSQL 18.1 verified
- **Acceptance Criteria:**
  - PostgreSQL adapter configured in database.yml
  - Database created successfully (`rails db:create`)
  - Database connection verified
  - Development/test databases separate
- **Files to Modify:**
  - `config/database.yml`
  - `Gemfile` (add pg gem)

### TASK-1.3: Install and Configure Tailwind CSS
- **Status:** [x] DONE
- **Dependencies:** TASK-1.1
- **Blocks:** TASK-4.3
- **Completed:** 2025-11-21
- **Notes:** tailwindcss-rails 4.4.0 installed, zero Node.js, Tailwind v4 auto-configuration
- **Acceptance Criteria:**
  - tailwindcss-rails gem installed
  - Tailwind CSS compiles without errors
  - CSS assets served correctly
  - No Node.js dependency
- **Files to Create:**
  - `config/tailwind.config.js`
  - `app/assets/stylesheets/application.tailwind.css`
- **Files to Modify:**
  - `Gemfile`
  - `app/views/layouts/application.html.erb`

### TASK-1.4: Configure Importmaps (Zero Build Step)
- **Status:** [x] DONE
- **Dependencies:** TASK-1.1
- **Blocks:** TASK-4.3
- **Completed:** 2025-11-21
- **Notes:** importmap-rails 2.2.2, Turbo 8 (2.0.20), Stimulus 3 (1.3.4), SRI enabled
- **Acceptance Criteria:**
  - Importmaps configured for Turbo/Stimulus
  - No Node.js, no webpack, no build step
  - JavaScript loads correctly in browser
  - Subresource Integrity (SRI) enabled
- **Files to Create:**
  - `config/importmap.rb`
- **Files to Modify:**
  - `app/views/layouts/application.html.erb`

---

## Wave 2: Core Gems & Configuration

**Goal:** Install essential gems and configure core functionality

### TASK-2.1: Install and Configure Solid Queue
- **Status:** [x] DONE
- **Dependencies:** TASK-1.2 (needs database)
- **Blocks:** TASK-6.2
- **Completed:** 2025-11-21
- **Notes:** solid_queue 1.2.4 + mission_control-jobs 1.1.0, 11 tables migrated, TestJob verified, Mission Control at /jobs
- **Acceptance Criteria:**
  - solid_queue gem installed
  - mission_control-jobs gem installed
  - Solid Queue tables migrated
  - Test job processes successfully
  - Mission Control dashboard accessible
- **Files to Create:**
  - `config/initializers/solid_queue.rb`
  - Database migration for Solid Queue tables
- **Files to Modify:**
  - `Gemfile`
  - `config/routes.rb` (Mission Control mount)

### TASK-2.2: Install Pundit and Pagy
- **Status:** [x] DONE
- **Dependencies:** TASK-1.2 (needs Rails foundation)
- **Blocks:** None (used in future ADRs)
- **Completed:** 2025-11-21
- **Notes:** pundit 2.5.2 + pagy 9.4.0, ApplicationPolicy secure-by-default, 34 tests passing (PostPolicy + UserPolicy examples)
- **Acceptance Criteria:**
  - pundit gem installed
  - pagy gem installed
  - Pundit configured in ApplicationController
  - Pagy configured for pagination
  - Test policy created and working
- **Files to Create:**
  - `app/policies/application_policy.rb`
  - `config/initializers/pagy.rb`
- **Files to Modify:**
  - `Gemfile`
  - `app/controllers/application_controller.rb`

### TASK-2.3: Install money-rails
- **Status:** [x] DONE
- **Dependencies:** TASK-1.2 (needs database)
- **Blocks:** TASK-7.1 (money-rails testing)
- **Completed:** 2025-11-21
- **Notes:** money-rails 1.15.0 + money 6.19.0, USD default, banker's rounding, InvoiceItem test model, 11 tests passing, Rails 8 compatible
- **Acceptance Criteria:**
  - money-rails gem installed
  - Money initializer configured
  - Money column type available
  - Basic Money object works
- **Files to Create:**
  - `config/initializers/money.rb`
- **Files to Modify:**
  - `Gemfile`

---

## Wave 3: Testing Infrastructure

**Goal:** Comprehensive test framework with CI/CD

### TASK-3.1: Configure Minitest and Fixtures
- **Status:** [ ] pending
- **Dependencies:** TASK-1.1 (needs Rails)
- **Blocks:** All testing tasks
- **Acceptance Criteria:**
  - Minitest configured (Rails default)
  - Fixtures directory structure created
  - test_helper.rb configured
  - Sample test passes
- **Files to Create:**
  - `test/fixtures/.keep`
  - `test/models/.keep`
  - `test/controllers/.keep`
  - `test/integration/.keep`
  - `test/system/.keep`
- **Files to Modify:**
  - `test/test_helper.rb`

### TASK-3.2: Install VCR and WebMock
- **Status:** [ ] pending
- **Dependencies:** TASK-3.1 (needs test framework)
- **Blocks:** TASK-3.6 (external API testing)
- **Acceptance Criteria:**
  - vcr gem installed
  - webmock gem installed
  - VCR configured in test_helper
  - Cassettes directory created
  - Sample VCR cassette works
- **Files to Create:**
  - `test/vcr_cassettes/.gitkeep`
  - `test/support/vcr.rb`
- **Files to Modify:**
  - `Gemfile` (test group)
  - `test/test_helper.rb`

### TASK-3.3: Install and Configure SimpleCov
- **Status:** [ ] pending
- **Dependencies:** TASK-3.1 (needs test framework)
- **Blocks:** None
- **Acceptance Criteria:**
  - simplecov gem installed
  - Coverage tracking enabled
  - HTML reports generated
  - 90% coverage threshold configured
  - Coverage directory gitignored
- **Files to Create:**
  - `.simplecov`
- **Files to Modify:**
  - `Gemfile` (test group)
  - `test/test_helper.rb`
  - `.gitignore`

### TASK-3.4: Set Up GitHub Actions CI Pipeline
- **Status:** [ ] pending
- **Dependencies:** TASK-3.1 (needs tests)
- **Blocks:** None
- **Acceptance Criteria:**
  - GitHub Actions workflow created
  - CI runs on PR and push to main
  - Tests run in parallel matrix
  - 100% pass rate required
  - Coverage reports uploaded
- **Files to Create:**
  - `.github/workflows/test.yml`

### TASK-3.5: Install and Configure Standard Linter
- **Status:** [ ] pending
- **Dependencies:** TASK-1.1 (needs Ruby code)
- **Blocks:** None
- **Acceptance Criteria:**
  - standard gem installed
  - Linter passes on all files
  - Auto-fix configured
  - CI enforces linting
- **Files to Create:**
  - `.standard.yml` (if custom config needed)
- **Files to Modify:**
  - `Gemfile` (development group)
  - `.github/workflows/test.yml`

### TASK-3.6: Install letter_opener_web
- **Status:** [ ] pending
- **Dependencies:** TASK-1.1 (needs Rails)
- **Blocks:** None
- **Acceptance Criteria:**
  - letter_opener_web gem installed
  - Email previews accessible at /letter_opener
  - Works in development only
  - Sample email preview works
- **Files to Modify:**
  - `Gemfile` (development group)
  - `config/routes.rb`
  - `config/environments/development.rb`

---

## Wave 4: Security Hardening & Rate Limiting

**Goal:** Production-grade security with Rack::Attack

### TASK-4.1: Install and Configure Rack::Attack
- **Status:** [ ] pending
- **Dependencies:** TASK-1.1 (needs Rails)
- **Blocks:** TASK-4.2, TASK-4.3, TASK-4.4
- **Acceptance Criteria:**
  - rack-attack gem installed
  - Rack::Attack middleware configured
  - Basic throttle rule works
  - Logging configured
- **Files to Create:**
  - `config/initializers/rack_attack.rb`
- **Files to Modify:**
  - `Gemfile`
  - `config/application.rb`

### TASK-4.2: Implement OTP and API Rate Limiting Rules
- **Status:** [ ] pending
- **Dependencies:** TASK-4.1 (needs Rack::Attack)
- **Blocks:** TASK-4.4
- **Acceptance Criteria:**
  - OTP generation throttled (3 per 15 min)
  - OTP validation throttled (5 per 10 min)
  - Receipt uploads throttled (50 per hour)
  - AI categorization throttled (200 per hour)
  - Entry creation throttled (100 per hour)
  - General API throttled (1000 per hour)
- **Files to Modify:**
  - `config/initializers/rack_attack.rb`

### TASK-4.3: Add Rate Limit Response Headers
- **Status:** [ ] pending
- **Dependencies:** TASK-4.2 (needs throttle rules)
- **Blocks:** None
- **Acceptance Criteria:**
  - X-RateLimit-Limit header included
  - X-RateLimit-Remaining header included
  - X-RateLimit-Reset header included
  - Retry-After header on throttle
  - Headers verified in tests
- **Files to Modify:**
  - `config/initializers/rack_attack.rb`

### TASK-4.4: Create Rate Limiting Integration Tests
- **Status:** [ ] pending
- **Dependencies:** TASK-4.2 (needs throttle rules), TASK-3.1 (needs test framework)
- **Blocks:** None
- **Acceptance Criteria:**
  - Tests for all throttle scenarios
  - Tests verify headers
  - Tests verify throttle enforcement
  - Tests verify allowlist works
  - >95% coverage on rate limiting code
- **Files to Create:**
  - `test/integration/rate_limiting_test.rb`

### TASK-4.5: Configure Rack::Attack Logging
- **Status:** [ ] pending
- **Dependencies:** TASK-4.1 (needs Rack::Attack)
- **Blocks:** None
- **Acceptance Criteria:**
  - Throttled requests logged to rack_attack.log
  - Log format includes IP, endpoint, throttle name
  - Log rotation configured
  - Throttle count tracked as metric
- **Files to Create:**
  - Custom logger configuration
- **Files to Modify:**
  - `config/initializers/rack_attack.rb`

---

## Wave 5: Caching & Performance Optimization

**Goal:** Aggressive caching for sub-200ms responses

### TASK-5.1: Install and Configure Solid Cache
- **Status:** [ ] pending
- **Dependencies:** TASK-1.2 (needs database)
- **Blocks:** TASK-5.2, TASK-5.3, TASK-5.4
- **Acceptance Criteria:**
  - solid_cache gem installed
  - Solid Cache configured in production
  - Null store in development
  - Cache tables migrated
  - Basic cache write/read works
- **Files to Create:**
  - Database migration for Solid Cache tables
- **Files to Modify:**
  - `Gemfile`
  - `config/environments/production.rb`
  - `config/environments/development.rb`

### TASK-5.2: Implement Russian Doll Caching Patterns
- **Status:** [ ] pending
- **Dependencies:** TASK-5.1 (needs Solid Cache)
- **Blocks:** None
- **Acceptance Criteria:**
  - Russian Doll caching examples in views
  - Touch associations configured
  - Cache keys expire correctly
  - Sample view demonstrates pattern
- **Files to Create:**
  - Sample view with Russian Doll caching
  - Documentation of caching patterns
- **Files to Modify:**
  - Sample models (add touch: true)

### TASK-5.3: Add Fragment Caching for Expensive Operations
- **Status:** [ ] pending
- **Dependencies:** TASK-5.1 (needs Solid Cache)
- **Blocks:** None
- **Acceptance Criteria:**
  - Fragment caching examples created
  - TTL configured (5 min, 1 hour)
  - Cache keys include relevant identifiers
  - Sample demonstrates balance calculation caching
- **Files to Create:**
  - Sample view with fragment caching
- **Files to Modify:**
  - Sample controllers/views

### TASK-5.4: Implement Cache Invalidation Logic
- **Status:** [ ] pending
- **Dependencies:** TASK-5.2, TASK-5.3 (needs caching patterns)
- **Blocks:** None
- **Acceptance Criteria:**
  - Cache invalidation on model updates
  - Sweeping patterns documented
  - Touch associations work correctly
  - Manual cache flush helper created
  - Tests verify invalidation works
- **Files to Create:**
  - `app/helpers/cache_helper.rb`
  - Tests for cache invalidation
- **Files to Modify:**
  - Sample models (add callbacks)

### TASK-5.5: Create Performance Benchmarks
- **Status:** [ ] pending
- **Dependencies:** TASK-5.2, TASK-5.3 (needs caching)
- **Blocks:** None
- **Acceptance Criteria:**
  - Benchmark script created
  - Tests with 10,000+ sample records
  - Compares cached vs uncached performance
  - Demonstrates 5x+ speedup
  - Renders <200ms with caching
- **Files to Create:**
  - `test/performance/ledger_benchmark.rb`
  - Sample data generation script

---

## Wave 6: Observability & Business Metrics

**Goal:** Custom metrics tracking and alerting

### TASK-6.1: Create MetricsTracker Service
- **Status:** [ ] pending
- **Dependencies:** TASK-1.2 (needs database), TASK-5.1 (needs cache)
- **Blocks:** TASK-6.2, TASK-6.3
- **Acceptance Criteria:**
  - MetricsTracker service created
  - Methods for all key metrics
  - Uses Rails.cache for storage
  - Thread-safe operations
  - Unit tests pass
- **Files to Create:**
  - `app/services/metrics_tracker.rb`
  - `test/services/metrics_tracker_test.rb`

### TASK-6.2: Implement Metrics Tracking
- **Status:** [ ] pending
- **Dependencies:** TASK-6.1 (needs MetricsTracker), TASK-2.1 (needs Solid Queue)
- **Blocks:** None
- **Acceptance Criteria:**
  - Anomaly queue depth tracked
  - AI confidence avg tracked
  - Entry posting success rate tracked
  - GPT-4o Vision success rate tracked
  - Ledger calculation time p95 tracked
  - OTP delivery time p95 tracked
- **Files to Modify:**
  - `app/services/metrics_tracker.rb`

### TASK-6.3: Create MetricsCollectionJob
- **Status:** [ ] pending
- **Dependencies:** TASK-6.2 (needs metrics tracking), TASK-2.1 (needs Solid Queue)
- **Blocks:** None
- **Acceptance Criteria:**
  - Background job created
  - Scheduled to run every 5 minutes
  - Collects all metrics
  - Handles errors gracefully
  - Job tests pass
- **Files to Create:**
  - `app/jobs/metrics_collection_job.rb`
  - `test/jobs/metrics_collection_job_test.rb`

### TASK-6.4: Configure Structured Logging
- **Status:** [ ] pending
- **Dependencies:** TASK-1.1 (needs Rails)
- **Blocks:** None
- **Acceptance Criteria:**
  - Logs output JSON format in production
  - Request context included
  - Exception details included
  - Slow query logging enabled (>100ms)
  - Log rotation configured
- **Files to Modify:**
  - `config/environments/production.rb`
  - `config/application.rb`

### TASK-6.5: Set Up Email Alerts for Critical Thresholds
- **Status:** [ ] pending
- **Dependencies:** TASK-6.2 (needs metrics)
- **Blocks:** None
- **Acceptance Criteria:**
  - Alert mailer created
  - Thresholds configured
  - Emails sent to @grayledger.io addresses
  - Throttle repeated alerts (1 per hour)
  - Test email sends successfully
- **Files to Create:**
  - `app/mailers/alert_mailer.rb`
  - `app/views/alert_mailer/metric_threshold_alert.html.erb`
  - `test/mailers/alert_mailer_test.rb`
  - `config/initializers/alerts.rb`

---

## Wave 7: money-rails Validation

**Goal:** Ensure money-rails compatibility with Rails 8

### TASK-7.1: Test money-rails with Rails 8
- **Status:** [ ] pending
- **Dependencies:** TASK-2.3 (needs money-rails installed)
- **Blocks:** TASK-7.2
- **Acceptance Criteria:**
  - Money model created
  - Money columns work correctly
  - Currency calculations tested
  - Rounding behavior validated
  - Storage/retrieval tested
  - No deprecation warnings
- **Files to Create:**
  - `app/models/money_test_model.rb` (test model)
  - Database migration for test table
  - `test/models/money_integration_test.rb`

### TASK-7.2: Document money-rails Compatibility
- **Status:** [ ] pending
- **Dependencies:** TASK-7.1 (needs testing complete)
- **Blocks:** None
- **Acceptance Criteria:**
  - Compatibility documented
  - Any issues noted
  - Fallback plan documented (if issues found)
  - Migration path to plain `money` gem (if needed)
  - ADR updated with findings
- **Files to Create:**
  - `dev/money-rails-rails8-compatibility.md`
- **Files to Modify:**
  - `docs/adrs/01.foundation/01.001.rails-8-minimal-stack.md` (update status)

---

## Wave 8: Final Validation & Cleanup

**Goal:** Ensure everything works together

### TASK-8.1: Run Full Test Suite and Verify Coverage
- **Status:** [ ] pending
- **Dependencies:** ALL previous tasks
- **Blocks:** None
- **Acceptance Criteria:**
  - All tests pass (100% green)
  - Coverage >90% overall
  - No deprecation warnings
  - Linter passes (standardrb)
  - CI pipeline passes
- **Files to Review:**
  - All test files
  - Coverage report

### TASK-8.2: Verify All Goals Achieved
- **Status:** [ ] pending
- **Dependencies:** TASK-8.1
- **Blocks:** None
- **Acceptance Criteria:**
  - All PRD success criteria met
  - All ADR goals achieved
  - Performance benchmarks pass
  - Security hardening complete
  - Observability working
- **Files to Review:**
  - `dev/prd-from-adr-01.001.md`
  - `docs/adrs/01.foundation/01.001.rails-8-minimal-stack.md`

### TASK-8.3: Update CLAUDE.md with Active Feature Status
- **Status:** [ ] pending
- **Dependencies:** TASK-8.2
- **Blocks:** None
- **Acceptance Criteria:**
  - CLAUDE.md updated with active feature
  - Links to PRD and TASKS.md added
  - Feature branch name recorded
  - Implementation status documented
- **Files to Modify:**
  - `CLAUDE.md`

---

## Summary Statistics

- **Total Tasks:** 25
- **Completed:** 7
- **In Progress:** 0
- **Pending:** 18
- **Blocked:** 0

**Progress by Wave:**
- Wave 1 (Foundation): 4/4 complete (100%) ✓
- Wave 2 (Core Gems): 3/3 complete (100%) ✓
- Wave 3 (Testing): 0/6 complete (0%)
- Wave 4 (Security): 0/5 complete (0%)
- Wave 5 (Caching): 0/5 complete (0%)
- Wave 6 (Observability): 0/5 complete (0%)
- Wave 7 (Validation): 0/2 complete (0%)
- Wave 8 (Final): 0/3 complete (0%)

---

## Dependency Graph

```
Wave 1 (Foundation)
├─ TASK-1.1 (Rails init) → BLOCKS: ALL
├─ TASK-1.2 (PostgreSQL) → BLOCKS: TASK-2.1, TASK-2.2, TASK-2.3, TASK-5.1, TASK-6.1
├─ TASK-1.3 (Tailwind) → BLOCKS: None
└─ TASK-1.4 (Importmaps) → BLOCKS: None

Wave 2 (Core Gems)
├─ TASK-2.1 (Solid Queue) → BLOCKS: TASK-6.2, TASK-6.3
├─ TASK-2.2 (Pundit/Pagy) → BLOCKS: None
└─ TASK-2.3 (money-rails) → BLOCKS: TASK-7.1

Wave 3 (Testing)
├─ TASK-3.1 (Minitest) → BLOCKS: TASK-3.2, TASK-3.3, TASK-4.4
├─ TASK-3.2 (VCR/WebMock) → BLOCKS: None
├─ TASK-3.3 (SimpleCov) → BLOCKS: None
├─ TASK-3.4 (GitHub Actions) → BLOCKS: None
├─ TASK-3.5 (Standard) → BLOCKS: None
└─ TASK-3.6 (letter_opener) → BLOCKS: None

Wave 4 (Security)
├─ TASK-4.1 (Rack::Attack) → BLOCKS: TASK-4.2, TASK-4.3, TASK-4.4, TASK-4.5
├─ TASK-4.2 (Rate rules) → BLOCKS: TASK-4.3, TASK-4.4
├─ TASK-4.3 (Headers) → BLOCKS: None
├─ TASK-4.4 (Tests) → BLOCKS: None
└─ TASK-4.5 (Logging) → BLOCKS: None

Wave 5 (Caching)
├─ TASK-5.1 (Solid Cache) → BLOCKS: TASK-5.2, TASK-5.3, TASK-5.4, TASK-6.1
├─ TASK-5.2 (Russian Doll) → BLOCKS: TASK-5.4, TASK-5.5
├─ TASK-5.3 (Fragment cache) → BLOCKS: TASK-5.4, TASK-5.5
├─ TASK-5.4 (Invalidation) → BLOCKS: None
└─ TASK-5.5 (Benchmarks) → BLOCKS: None

Wave 6 (Observability)
├─ TASK-6.1 (MetricsTracker) → BLOCKS: TASK-6.2, TASK-6.3
├─ TASK-6.2 (Tracking) → BLOCKS: TASK-6.3, TASK-6.5
├─ TASK-6.3 (CollectionJob) → BLOCKS: None
├─ TASK-6.4 (Logging) → BLOCKS: None
└─ TASK-6.5 (Alerts) → BLOCKS: None

Wave 7 (Validation)
├─ TASK-7.1 (money-rails test) → BLOCKS: TASK-7.2
└─ TASK-7.2 (Documentation) → BLOCKS: None

Wave 8 (Final)
├─ TASK-8.1 (Test suite) → BLOCKS: TASK-8.2
├─ TASK-8.2 (Verify goals) → BLOCKS: TASK-8.3
└─ TASK-8.3 (Update CLAUDE.md) → BLOCKS: None
```

---

**Last Updated:** 2025-11-21
**Status:** Wave 2 Complete - Moving to Wave 3
**Next Step:** Begin Wave 3 (Testing Infrastructure) - All 6 tasks ready
