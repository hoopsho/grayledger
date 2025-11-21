# PRD: Heroku Deployment with PostgreSQL + pgvector

**Source:** [ADR 01.002](../docs/adrs/01.foundation/01.002.heroku-postgres-pgvector.md)
**Status:** In Progress
**Branch:** `feature/adr-01.002-heroku-postgres-pgvector`

## Overview

Deploy GrayLedger to Heroku with a single-database PostgreSQL setup including pgvector extension for AI embeddings. This enables zero-ops deployment for a solo developer while maintaining production-grade infrastructure.

## Goals

1. **Zero-ops deployment:** Push to Heroku, auto-migrate, zero-downtime
2. **Single database simplicity:** One PostgreSQL database for all Rails 8 Solid gems
3. **pgvector ready:** AI embedding cache enabled from day one
4. **Cost target:** ≤$75/mo for first 500 companies
5. **S3 integration:** Direct uploads for receipts/documents
6. **Security hardened:** SSL, rate limiting, secret rotation documented
7. **Backup strategy:** Daily automated backups with restore procedure

## Technical Requirements

### Database
- **Single PostgreSQL database:** Heroku Postgres Standard-0 ($50/mo)
- **pgvector extension:** For 1536-dimension AI embeddings
- **Simplified database.yml:** Use `ENV['DATABASE_URL']` only
- **Solid gems:** Queue/Cache/Cable all use primary database

### Deployment
- **Procfile:** Web + worker dynos
- **Buildpacks:** heroku/ruby + heroku-buildpack-pgvector
- **Release phase:** Automatic migrations
- **Environment vars:** All secrets in Heroku config vars

### Storage
- **Active Storage:** S3 for production
- **Direct uploads:** Client → S3 (bypass Rails)
- **IAM:** Least-privilege AWS user for uploads only

### Security
- **Force SSL:** All production traffic HTTPS
- **Rack::Attack:** Rate limiting (already implemented)
- **Secret rotation:** 90-day schedule documented
- **Backups:** Daily with 7-day retention

## User Stories

### As a Solo Developer
- I can deploy with `git push heroku main`
- I never SSH into servers or manage infrastructure
- I can rollback bad deploys with `heroku rollback`
- I can restore data from daily backups
- I monitor app health via Papertrail logs

### As a Platform
- AI categorization uses pgvector for fast lookups
- Receipt uploads go directly to S3
- Background jobs process via Solid Queue worker
- Database scales from Hobby → Standard-0 → Standard-2 as needed

## Success Criteria

- [ ] `git push heroku main` deploys successfully
- [ ] pgvector extension enabled and tested
- [ ] Single database (no multi-database complexity)
- [ ] S3 uploads working end-to-end
- [ ] Solid Queue worker processing jobs
- [ ] SSL enforced (HTTP → HTTPS redirect)
- [ ] Daily backups verified
- [ ] All 329 existing tests pass
- [ ] Cost ≤$75/mo (Standard-0 PostgreSQL + dynos)

## Out of Scope (Deferred)

- ❌ Staging environment (production YOLO mode for MVP)
- ❌ APM monitoring (Sentry, Scout) - wait for $10K MRR
- ❌ Multi-region deployment (US-only initially)
- ❌ Read replicas (not until 1000+ companies)
- ❌ Heroku Postgres continuous protection (daily backups sufficient)

## Implementation Phases

### Wave 1: Database Simplification
- Simplify database.yml to single DATABASE_URL
- Remove multi-database config (cache, queue, cable)
- Add pgvector gem
- Create pgvector migration

### Wave 2: Heroku Configuration
- Create Procfile (web + worker)
- Configure S3 storage for production
- Enable force_ssl in production.rb
- Add deployment documentation

### Wave 3: Testing & Validation
- Test pgvector locally
- Verify Solid Queue/Cache/Cable with single database
- Test S3 uploads
- Run full test suite
- Document deployment procedures

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Multi-database → Single database breaks Solid gems | Test locally first, Rails 8 designed for single DB |
| pgvector buildpack fails | Document manual extension enable command |
| S3 credentials exposed | Use IAM least-privilege, never commit secrets |
| Production data loss | Daily backups, test restore procedure |
| Cost overrun | Set Heroku spending alerts at $100/mo |

## Dependencies

- ADR 01.001 (Rails 8 stack) - ✅ COMPLETE
- ADR 06.002 (pgvector memory cache) - ⏸ Deferred to AI implementation

## Timeline

- **Wave 1:** 1-2 hours (database config)
- **Wave 2:** 1-2 hours (Heroku setup)
- **Wave 3:** 1-2 hours (testing)
- **Total:** 4-6 hours

## Metrics

- Deployment time: <5 minutes (git push → live)
- Rollback time: <1 minute (heroku rollback)
- Monthly cost: $50-75 (PostgreSQL + 2 dynos)
- Backup time: <2 minutes (manual backup)
- Restore time: <10 minutes (from backup)

## Open Questions

- ✅ Single database vs multi-database? → **Single database** (cost, simplicity)
- ✅ Include pgvector now or defer? → **Include now** (foundation requirement)
- ✅ Daily backups vs continuous protection? → **Daily backups** (MVP sufficient)
- ✅ Staging environment? → **No** (production YOLO mode)

---

**Last Updated:** 2025-11-21
**Implementation:** See [dev/TASKS.md](./TASKS.md)
