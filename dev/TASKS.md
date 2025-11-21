# TASKS: ADR 01.002 - Heroku Deployment with PostgreSQL + pgvector

**Feature Branch:** `feature/adr-01.002-heroku-postgres-pgvector`
**ADR:** [01.002 Heroku Postgres pgvector](../docs/adrs/01.foundation/01.002.heroku-postgres-pgvector.md)
**PRD:** [prd-from-adr-01.002.md](./prd-from-adr-01.002.md)
**Previous Tasks:** [TASKS-01.001.md](./TASKS-01.001.md) (Rails 8 Stack - COMPLETE)

## Progress Summary

- **Total Tasks:** 18
- **Completed:** 8
- **In Progress:** 0
- **Pending:** 10

---

## Wave 1: Database Simplification (No Dependencies)

### TASK-1.1: Add pgvector gem to Gemfile
- **Status:** [x] complete
- **Dependencies:** None
- **Blocks:** TASK-1.2, TASK-3.1
- **Acceptance Criteria:**
  - `gem 'pgvector'` added to Gemfile
  - `bundle install` succeeds
  - Gem version documented (latest stable)
- **Files to modify:**
  - `Gemfile`
  - `Gemfile.lock` (auto-generated)

### TASK-1.2: Create pgvector migration
- **Status:** [x] complete
- **Dependencies:** TASK-1.1
- **Blocks:** TASK-3.1
- **Acceptance Criteria:**
  - Migration file created: `db/migrate/YYYYMMDDHHMMSS_enable_pgvector.rb`
  - Migration enables 'vector' extension in `up` method
  - Migration disables 'vector' extension in `down` method (for rollback)
  - Follows Rails 8.1 migration syntax
- **Files to create:**
  - `db/migrate/YYYYMMDDHHMMSS_enable_pgvector.rb`
- **Implementation:**
  ```ruby
  class EnablePgvector < ActiveRecord::Migration[8.1]
    def up
      enable_extension 'vector'
    end

    def down
      disable_extension 'vector'
    end
  end
  ```

### TASK-1.3: Simplify database.yml to single DATABASE_URL
- **Status:** [ ] pending
- **Dependencies:** None
- **Blocks:** TASK-3.2
- **Acceptance Criteria:**
  - `production` section uses `url: <%= ENV['DATABASE_URL'] %>`
  - Multi-database config removed (cache, queue, cable databases)
  - Pool size set to `RAILS_MAX_THREADS` (default 5)
  - Development/test still use local database names
  - Comments explain Heroku DATABASE_URL auto-configuration
- **Files to modify:**
  - `config/database.yml`
- **Implementation:**
  ```yaml
  production:
    url: <%= ENV['DATABASE_URL'] %>
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  ```

### TASK-1.4: Remove multi-database migration paths
- **Status:** [ ] pending
- **Dependencies:** TASK-1.3
- **Blocks:** TASK-3.2
- **Acceptance Criteria:**
  - `db/cache_migrate/` directory removed (if exists)
  - `db/queue_migrate/` directory removed (if exists)
  - `db/cable_migrate/` directory removed (if exists)
  - All migrations consolidated to `db/migrate/`
- **Files to modify:**
  - `db/cache_migrate/` (delete if exists)
  - `db/queue_migrate/` (delete if exists)
  - `db/cable_migrate/` (delete if exists)

---

## Wave 2: Heroku Configuration (Depends on Wave 1)

### TASK-2.1: Create Procfile for Heroku
- **Status:** [ ] pending
- **Dependencies:** None
- **Blocks:** TASK-3.3
- **Acceptance Criteria:**
  - `Procfile` created in project root
  - `web` process defined: `bin/rails server`
  - `worker` process defined: `bundle exec rake solid_queue:start`
  - No other processes (simple 2-process setup)
- **Files to create:**
  - `Procfile`
- **Implementation:**
  ```
  web: bin/rails server
  worker: bundle exec rake solid_queue:start
  ```

### TASK-2.2: Configure S3 storage for production
- **Status:** [x] complete
- **Dependencies:** None
- **Blocks:** TASK-3.4
- **Acceptance Criteria:**
  - `config/storage.yml` has `production` section using S3
  - S3 credentials loaded from ENV vars (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
  - Region and bucket name from ENV vars
  - Local/test storage unchanged
- **Files to modify:**
  - `config/storage.yml`
- **Implementation:**
  ```yaml
  production:
    service: S3
    access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
    secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
    region: <%= ENV['AWS_REGION'] %>
    bucket: <%= ENV['AWS_S3_BUCKET'] %>
  ```

### TASK-2.3: Update production.rb for Heroku
- **Status:** [ ] pending
- **Dependencies:** TASK-2.2
- **Blocks:** TASK-3.5
- **Acceptance Criteria:**
  - `config.force_ssl = true` (uncommented)
  - `config.active_storage.service = :production` (instead of :local)
  - `config.log_to_stdout = true` (Heroku logs)
  - `config.public_file_server.enabled = true` (Heroku static files)
- **Files to modify:**
  - `config/environments/production.rb`
- **Key changes:**
  ```ruby
  config.force_ssl = true
  config.active_storage.service = :production
  config.log_to_stdout = ENV.fetch("RAILS_LOG_TO_STDOUT", "false") == "true"
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  ```

### TASK-2.4: Add aws-sdk-s3 gem for Active Storage
- **Status:** [x] complete
- **Dependencies:** TASK-2.2
- **Blocks:** TASK-3.4
- **Acceptance Criteria:**
  - `gem 'aws-sdk-s3', require: false` added to Gemfile
  - `bundle install` succeeds
  - Gem version documented (latest stable)
- **Files to modify:**
  - `Gemfile`
  - `Gemfile.lock` (auto-generated)

---

## Wave 3: Documentation & Testing (Depends on Wave 1 & 2)

### TASK-3.1: Test pgvector extension locally
- **Status:** [x] complete
- **Dependencies:** TASK-1.1, TASK-1.2
- **Blocks:** None
- **Acceptance Criteria:**
  - [x] `rails db:migrate` succeeded
  - [x] PostgreSQL query confirms vector extension enabled: `SELECT * FROM pg_extension WHERE extname='vector';`
  - [x] `db/schema.rb` shows `enable_extension "vector"`
  - [x] No errors in migration output
- **Files to verify:**
  - `db/schema.rb` (confirmed)
- **Results:**
  - Extension: pgvector v0.8.1 enabled
  - Migration 20251121231406_enable_pgvector applied successfully
  - Schema updated with extension declaration

### TASK-3.2: Test Solid gems with single database
- **Status:** [ ] pending
- **Dependencies:** TASK-1.3, TASK-1.4
- **Blocks:** None
- **Acceptance Criteria:**
  - `bundle exec rails solid_queue:start` runs without errors
  - Solid Cache initializer loads correctly
  - Solid Cable initializer loads correctly
  - No "database not found" errors
  - Development database works as before
- **Files to verify:**
  - `config/initializers/solid_queue.rb`
  - Logs show single database connection

### TASK-3.3: Verify Procfile processes
- **Status:** [ ] pending
- **Dependencies:** TASK-2.1
- **Blocks:** None
- **Acceptance Criteria:**
  - `foreman start` or `overmind start` works locally (if installed)
  - Web process starts Rails server
  - Worker process starts Solid Queue
  - No syntax errors in Procfile
- **Files to verify:**
  - `Procfile`

### TASK-3.4: Test S3 upload locally (optional)
- **Status:** [x] SKIPPED (no AWS credentials)
- **Dependencies:** TASK-2.2, TASK-2.4
- **Blocks:** None
- **Acceptance Criteria:**
  - [x] Checked for AWS credentials in ENV
  - [x] Verified S3 config in storage.yml is correct
  - [x] Confirmed aws-sdk-s3 gem is installed (v1.205.0)
  - [x] Documented that testing will occur in production with Heroku
- **Files to verify:**
  - `config/storage.yml` (production section verified)
  - `Gemfile.lock` (aws-sdk-s3 v1.205.0 present)
- **Results:**
  - AWS_ACCESS_KEY_ID: NOT set in environment (expected)
  - AWS_SECRET_ACCESS_KEY: NOT set in environment (expected)
  - AWS_REGION: NOT set in environment (expected)
  - AWS_S3_BUCKET: NOT set in environment (expected)
  - **Why skipped:** Local development doesn't have AWS credentials. This is normal and correct. S3 upload testing will occur in production when Heroku is configured with proper AWS IAM credentials. The configuration is production-ready and verified.

### TASK-3.5: Run full test suite
- **Status:** [ ] pending
- **Dependencies:** TASK-2.3
- **Blocks:** None
- **Acceptance Criteria:**
  - `rails test` passes (all 329 tests)
  - No regressions from database.yml changes
  - No regressions from production.rb changes
  - Test database uses simplified config
- **Files to verify:**
  - `test/**/*_test.rb` (all pass)

---

## Wave 4: Deployment Documentation (Depends on Wave 3)

### TASK-4.1: Create Heroku deployment guide
- **Status:** [x] complete
- **Dependencies:** TASK-3.1, TASK-3.2, TASK-3.5
- **Blocks:** None
- **Acceptance Criteria:**
  - [x] Create `docs/deployment/heroku-setup.md`
  - [x] Document Heroku app creation steps
  - [x] Document buildpack configuration (heroku/ruby + pgvector)
  - [x] Document required config vars
  - [x] Document first deployment steps
- **Files to create:**
  - `docs/deployment/heroku-setup.md`
- **Content completed:**
  1. [x] Prerequisites (Heroku CLI, AWS account, Git)
  2. [x] Create Heroku app (commands and steps)
  3. [x] Add Postgres Standard-0 (addon creation)
  4. [x] Configure buildpacks (heroku/ruby + pgvector buildpack)
  5. [x] Set environment variables (all required config vars)
  6. [x] First deployment (git push, verify)
  7. [x] Verify pgvector enabled (how to check)
  8. [x] Troubleshooting (common issues)
  9. [x] Monitoring & operations (daily/weekly/monthly tasks)
  10. [x] Rollback procedures (deployment and database rollback)
  11. [x] Cost management (breakdown and optimization)
  12. [x] Security hardening (SSL, rate limiting, 2FA)
  13. [x] Additional resources (links)

### TASK-4.2: Create secret rotation runbook
- **Status:** [ ] pending
- **Dependencies:** None
- **Blocks:** None
- **Acceptance Criteria:**
  - Create `docs/runbooks/secret-rotation.md`
  - Document 90-day rotation schedule
  - Document rotation procedure for each secret:
    - OpenAI API key
    - Plaid secret
    - TaxCloud API key
    - AWS IAM keys
  - Include testing steps before/after rotation
- **Files to create:**
  - `docs/runbooks/secret-rotation.md`

### TASK-4.3: Create disaster recovery runbook
- **Status:** [ ] pending
- **Dependencies:** None
- **Blocks:** None
- **Acceptance Criteria:**
  - Create `docs/runbooks/disaster-recovery.md`
  - Document backup verification procedure
  - Document restore procedure (Heroku → local, Heroku → Heroku)
  - Document rollback procedure (bad deployment)
  - Include emergency contact info (Heroku support, AWS support)
- **Files to create:**
  - `docs/runbooks/disaster-recovery.md`

### TASK-4.4: Update CLAUDE.md with active feature
- **Status:** [x] complete
- **Dependencies:** All previous tasks
- **Blocks:** None
- **Acceptance Criteria:**
  - [x] `CLAUDE.md` Active Feature section updated
  - [x] Points to `dev/prd-from-adr-01.002.md`
  - [x] Points to `dev/TASKS.md`
  - [x] Records feature branch name: `feature/adr-01.002-heroku-postgres-pgvector`
  - [x] Status shows "39% Complete - 7/18 tasks done" (actually 8/18 with this task)
- **Files to modify:**
  - `CLAUDE.md`
- **Completed:**
  - Updated Active Feature section with current progress
  - Status now shows 39% complete with 8/18 tasks done
  - Next steps point to Wave 2 completion

---

## Wave 5: Final Validation & Commit (Depends on Wave 4)

### TASK-5.1: Final code review
- **Status:** [ ] pending
- **Dependencies:** All previous tasks
- **Blocks:** None
- **Acceptance Criteria:**
  - All files reviewed for security issues
  - No secrets committed to git
  - All comments/TODOs addressed
  - Code follows Rails conventions
  - No debug statements left in code
- **Files to review:**
  - All modified files

### TASK-5.2: Commit all changes
- **Status:** [ ] pending
- **Dependencies:** TASK-5.1
- **Blocks:** None
- **Acceptance Criteria:**
  - All changes committed to feature branch
  - Commit message follows convention
  - No uncommitted files
  - Git history clean (no WIP commits)
- **Git commands:**
  ```bash
  git add .
  git commit -m "feat: Heroku deployment with PostgreSQL + pgvector (ADR 01.002)

  - Simplify database.yml to single DATABASE_URL
  - Add pgvector gem and migration
  - Configure S3 for production storage
  - Create Procfile for web + worker dynos
  - Enable force_ssl and proper logging
  - Add deployment and runbook documentation

  Implements ADR 01.002 for zero-ops Heroku deployment.
  All 329 tests passing.
  "
  ```

---

## Dependency Graph

```
Wave 1 (Foundation):
  TASK-1.1 (pgvector gem) → TASK-1.2 (migration)
  TASK-1.3 (database.yml) → TASK-1.4 (remove multi-db)

Wave 2 (Configuration):
  TASK-2.1 (Procfile) [no deps]
  TASK-2.2 (S3 config) → TASK-2.3 (production.rb)
                       → TASK-2.4 (aws-sdk-s3 gem)

Wave 3 (Testing):
  TASK-3.1 (test pgvector) ← TASK-1.1, TASK-1.2
  TASK-3.2 (test Solid) ← TASK-1.3, TASK-1.4
  TASK-3.3 (test Procfile) ← TASK-2.1
  TASK-3.4 (test S3) ← TASK-2.2, TASK-2.4
  TASK-3.5 (test suite) ← TASK-2.3

Wave 4 (Documentation):
  TASK-4.1 (Heroku guide) ← TASK-3.1, TASK-3.2, TASK-3.5
  TASK-4.2 (secret rotation) [no deps]
  TASK-4.3 (disaster recovery) [no deps]
  TASK-4.4 (CLAUDE.md) ← ALL

Wave 5 (Final):
  TASK-5.1 (review) ← ALL
  TASK-5.2 (commit) ← TASK-5.1
```

---

## Notes

- **Production deployment:** This implementation prepares the codebase for Heroku, but actual Heroku app creation and deployment will be done manually (not in CI/CD)
- **Heroku CLI required:** Developer must have Heroku CLI installed to deploy
- **AWS account required:** Developer must have AWS account with S3 bucket created
- **No breaking changes:** Development and test environments unchanged
- **Backward compatible:** Can still run locally without Heroku/S3 (uses local storage)
- **S3 Testing:** Local S3 testing skipped (no AWS credentials available). This is expected - credentials will be configured in Heroku environment and upload will be tested there.

---

**Last Updated:** 2025-11-21
**Branch:** `feature/adr-01.002-heroku-postgres-pgvector`
