# PRD: Rails 8 Minimal Stack - Battle-Hardened Foundation

**Source:** [ADR 01.001 - Rails 8 Minimal Stack](../docs/adrs/01.foundation/01.001.rails-8-minimal-stack.md)
**Status:** In Development
**Feature Branch:** `feature/adr-01.001-rails-8-minimal-stack`
**Target Completion:** 2 weeks (10 working days)

---

## Product Vision

Build a **production-ready Rails 8 foundation** for an AI-driven accounting application that is:
- **Solo-maintainable forever** - Any Rails developer in 2025-2035 can understand every line
- **Extremely cheap** - <$300/month for first 1,000 customers
- **Battle-tested from day one** - Rate limiting, caching, observability built-in
- **Zero build complexity** - No Node.js, no webpack, just Rails

---

## Success Criteria

### Must-Have (Minimum Viable Foundation)
- [ ] Rails 8 application with Hotwire (Turbo 8 + Stimulus 3)
- [ ] PostgreSQL + pgvector extension configured
- [ ] Tailwind CSS via importmaps (zero build step)
- [ ] Solid Queue for background jobs (no Redis)
- [ ] Pundit authorization + Pagy pagination
- [ ] Rack::Attack rate limiting (OTP, API endpoints)
- [ ] Solid Cache + Russian Doll caching
- [ ] Custom business metrics tracking
- [ ] 90%+ test coverage (Minitest + fixtures)
- [ ] GitHub Actions CI/CD pipeline
- [ ] money-rails Rails 8 compatibility validated

### Should-Have (Enhanced Foundation)
- [ ] VCR/WebMock for external API mocking
- [ ] SimpleCov coverage reporting
- [ ] Standard linter configured
- [ ] Letter opener for email previews
- [ ] Encrypted credentials for secrets
- [ ] Performance benchmarks (<200ms with 10k entries)

### Nice-to-Have (Future Enhancements)
- [ ] Heroku production deployment
- [ ] S3 configured for Active Storage
- [ ] External API clients (Plaid, OpenAI, TaxCloud)
- [ ] Metrics dashboard UI (/admin/metrics)

---

## Technical Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Framework | Rails 8.0+ | Hotwire, Solid Queue, auth primitives |
| Frontend | Importmaps + Tailwind | Zero build step |
| JavaScript | Turbo 8 + Stimulus 3 | No React/Vue |
| Database | PostgreSQL + pgvector | AI embeddings + relational |
| Background Jobs | Solid Queue | No Redis dependency |
| Testing | Minitest + fixtures | Fast, Rails native |
| Rate Limiting | Rack::Attack | Prevent abuse, protect API costs |
| Caching | Solid Cache + Russian Doll | Sub-200ms responses |
| Observability | Custom metrics | Business-first, defer APM |

---

## Implementation Phases

### Phase 1: Rails Application Bootstrap (Days 1-2)
**Goal:** Functioning Rails 8 application with core gems installed

**Deliverables:**
- Rails 8 app initialized with PostgreSQL
- Gemfile with all approved gems (pundit, pagy, money-rails, rack-attack, solid_cache, etc.)
- Tailwind CSS configured via tailwindcss-rails gem
- Importmaps configured (no Node.js)
- Solid Queue installed and configured
- Application starts without errors

**Validation:**
- `rails server` runs successfully
- `rails test` runs (even if empty)
- Tailwind CSS assets compile
- Solid Queue processes test job

---

### Phase 2: Testing Infrastructure (Days 3-4)
**Goal:** Comprehensive test framework with CI/CD

**Deliverables:**
- Minitest configured with fixtures
- VCR + WebMock for API mocking
- SimpleCov for coverage reporting
- GitHub Actions CI pipeline
- Standard linter configured
- Letter opener for email previews

**Validation:**
- CI pipeline runs on PR
- Coverage reports generated
- Linting passes with `standardrb`
- Email previews work at `/letter_opener`

---

### Phase 3: Security Hardening (Days 5-6)
**Goal:** Production-grade rate limiting and security

**Deliverables:**
- Rack::Attack configured with throttle rules:
  - OTP: 3 per 15 min
  - Receipt uploads: 50 per hour
  - Entry creation: 100 per hour
  - API endpoints: 1000 per hour
- Rate limit response headers (X-RateLimit-*)
- Rack::Attack logging configured
- Integration tests for all rate limits

**Validation:**
- Throttles enforce limits correctly
- Rate limit headers returned
- Throttled requests logged
- Tests cover all scenarios

---

### Phase 4: Caching & Performance (Days 7-8)
**Goal:** Aggressive caching for sub-200ms responses

**Deliverables:**
- Solid Cache configured in production
- Russian Doll caching patterns in views
- Fragment caching for expensive calculations
- Cache invalidation logic
- Performance benchmarks (10k+ entries)
- Development environment uses null_store

**Validation:**
- Dashboard renders <200ms (cached)
- Cache invalidation works correctly
- Benchmarks demonstrate 5x+ speedup
- Caching disabled in development

---

### Phase 5: Observability (Days 9-10)
**Goal:** Business metrics tracking and alerting

**Deliverables:**
- MetricsTracker service
- Metrics tracked:
  - Anomaly queue depth
  - AI confidence avg
  - Entry posting success rate
  - GPT-4o Vision success rate
  - Ledger calculation time p95
  - OTP delivery time p95
- MetricsCollectionJob (runs every 5 min)
- Structured logging (JSON format)
- Email alerts for critical thresholds

**Validation:**
- All metrics tracked and stored
- MetricsCollectionJob runs successfully
- Email alerts trigger on thresholds
- Structured logs output JSON

---

### Phase 6: Money-Rails Validation (Day 11)
**Goal:** Ensure money-rails works with Rails 8

**Deliverables:**
- Money model integration tests
- Currency calculations tested
- Rounding behavior validated
- Storage/retrieval tested
- Fallback plan documented (if issues found)

**Validation:**
- Money objects persist correctly
- Currency conversions work
- No deprecation warnings
- Rounding behaves as expected

---

## Non-Goals (Explicitly Out of Scope)

- ❌ Heroku deployment (Phase 5 in ADR, deferred)
- ❌ External API integration (Plaid, OpenAI, TaxCloud) - separate ADRs
- ❌ Active Storage S3 configuration - future
- ❌ Metrics dashboard UI (/admin/metrics) - future
- ❌ Domain models (Entry, Account, etc.) - separate ADRs
- ❌ Authentication (OTP) - ADR 02.001
- ❌ Authorization policies - will use Pundit gem, policies deferred

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| money-rails incompatible with Rails 8 | Medium | High | Thorough testing in Phase 6, fallback to plain `money` gem |
| Solid Queue performance insufficient | Low | Medium | Monitor queue depth, add indexes, rollback to Sidekiq if needed |
| Cache invalidation bugs | Medium | High | >95% test coverage, manual cache flush button, monitoring |
| Rate limiting false positives | Medium | Medium | Document limits in UI, allow superuser whitelisting |
| Solid Cache database bloat | Low | Medium | Configure auto-cleanup, monitor table size |

---

## Dependencies

**Required for this PRD:**
- Rails 8.0+ installed
- PostgreSQL 14+ with pgvector extension
- Ruby 3.2+ (Rails 8 requirement)

**Blocked by this PRD:**
- ADR 02.001 (Passwordless OTP) - needs Rails foundation
- ADR 03.001 (Company Tenancy) - needs database setup
- ADR 04.001 (Double-Entry Ledger) - needs Rails models
- ADR 06.001 (AI Strategy) - needs external API clients
- All other domain ADRs

---

## Metrics & Monitoring

### Key Performance Indicators (KPIs)
- **Test Coverage:** >90% on all new code
- **Test Speed:** Unit tests <10 seconds, full suite <60 seconds
- **Response Time:** <200ms for cached dashboard (10k entries)
- **Cache Hit Rate:** >80% for frequently accessed data
- **Rate Limit Hit Rate:** <5% of total requests

### Success Metrics
- All CI builds pass (100% green)
- Zero deprecation warnings in Rails 8
- Linter passes with `standardrb` (zero violations)
- Performance benchmarks demonstrate 5x+ speedup with caching

---

## Open Questions

1. **money-rails compatibility:** Last release 2021 - will it work with Rails 8?
   - **Resolution:** Thorough testing in Phase 6, fallback plan ready

2. **Solid Cache table growth:** Will postgres bloat become an issue?
   - **Resolution:** Configure auto-cleanup, monitor weekly, manual VACUUM if needed

3. **Rate limit tuning:** Are the initial limits correct?
   - **Resolution:** Start conservative, monitor throttle logs, adjust if >5% users hit limits

4. **Caching strategy:** Which views need Russian Doll caching?
   - **Resolution:** Defer to actual domain implementation (Entry, Account views)

---

## Timeline

- **Days 1-2:** Rails bootstrap + core gems
- **Days 3-4:** Testing infrastructure + CI/CD
- **Days 5-6:** Security hardening + rate limiting
- **Days 7-8:** Caching + performance optimization
- **Days 9-10:** Observability + metrics tracking
- **Day 11:** money-rails validation + buffer
- **Day 12:** Final review, PR creation, merge

**Total:** 12 days (2.5 weeks including buffer)

---

## Approval & Sign-Off

- [ ] ADR reviewed and approved → ✅ DONE (via /adr-analyze)
- [ ] PRD reviewed and approved → Pending user confirmation
- [ ] TASKS.md created and approved → Next step
- [ ] Feature branch created → ✅ DONE (feature/adr-01.001-rails-8-minimal-stack)
- [ ] Ready to begin implementation → Pending approval

---

**Last Updated:** 2025-11-21
**Owner:** Solo Developer
**Reviewers:** None (solo project)
**Status:** Draft - awaiting implementation start
