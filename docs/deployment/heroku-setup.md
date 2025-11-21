# Heroku Deployment Guide: GrayLedger

**Source:** [ADR 01.002 - Heroku Postgres pgvector](../adrs/01.foundation/01.002.heroku-postgres-pgvector.md)
**Last Updated:** 2025-11-21
**Audience:** Developers, DevOps engineers
**Status:** Production-ready

This guide walks you through deploying GrayLedger to Heroku with PostgreSQL and pgvector extension enabled.

---

## Prerequisites

Before starting, ensure you have:

### 1. Heroku Account
- Create account at [heroku.com](https://www.heroku.com)
- Verify email address
- Set up billing information (even if using free tier initially)

### 2. Heroku CLI
Install the Heroku Command Line Interface for your operating system:

**macOS (Homebrew):**
```bash
brew tap heroku/brew && brew install heroku
```

**Ubuntu/Debian:**
```bash
curl https://cli-assets.heroku.com/install-ubuntu.sh | sh
```

**Windows:**
Download from [heroku.com/devcenter/articles/heroku-cli](https://devcenter.heroku.com/articles/heroku-cli)

Verify installation:
```bash
heroku --version
# Output: heroku/8.x.x (darwin-x64) node-vx.x.x
```

### 3. Git Repository
- Local git repository with commits to `main` branch
- Heroku CLI will use git for deployment

### 4. AWS Account
- Account created with S3 access
- IAM user created with S3 upload permissions (least-privilege)
- S3 bucket created for production file uploads

### 5. API Keys & Credentials
Gather before starting:
- **OpenAI API key:** sk-... (from openai.com)
- **Plaid credentials:** client_id, secret (from plaid.com)
- **TaxCloud credentials:** API login, API key (from taxcloud.com)
- **AWS credentials:** ACCESS_KEY_ID, SECRET_ACCESS_KEY (from AWS IAM)
- **AWS region & bucket:** us-east-1, grayledger-production

---

## Step 1: Create Heroku App

### 1.1: Login to Heroku

```bash
heroku login
# Opens browser to authenticate
# After login, returns: Logged in as user@example.com
```

### 1.2: Create Application

```bash
heroku create grayledger-production --region us
# Creating app... done, ⬢ grayledger-production
# https://grayledger-production.herokuapp.com/ | https://git.heroku.com/grayledger-production.git
```

**Notes:**
- Name must be globally unique (change if already taken)
- Region `us` keeps app in US (vs `eu` for Europe)
- This automatically adds `heroku` git remote to local repo

### 1.3: Verify App Creation

```bash
heroku apps:info --app grayledger-production

# ⬢ grayledger-production
# Buildpack URLs
# Database
# Dynos
# Git URL:           https://git.heroku.com/grayledger-production.git
# Owner Email:       user@example.com
# Region:            us
# Repo Size:         0 B
# Slug Size:         0 B
# Stack:             heroku-22
# Web URL:           https://grayledger-production.herokuapp.com/
```

### 1.4: Add Git Remote (if not auto-added)

```bash
git remote add heroku https://git.heroku.com/grayledger-production.git
git remote -v
# heroku  https://git.heroku.com/grayledger-production.git (fetch)
# heroku  https://git.heroku.com/grayledger-production.git (push)
```

---

## Step 2: Add PostgreSQL Database

### 2.1: Create Postgres Add-on

```bash
heroku addons:create heroku-postgresql:standard-0 --app grayledger-production

# Creating heroku-postgresql:standard-0 on ⬢ grayledger-production... done
# The database should be available in 3-5 minutes.
# PostgreSQL 14.8 (DATABASE_URL added to config vars)
```

**Database tier options:**
- **hobby-dev** ($0/month): Development only, 1GB storage, sleeps after 1 hour inactivity - **DO NOT USE FOR PRODUCTION**
- **standard-0** ($50/month): Production tier, 10GB storage, 120 connections, automated backups - **RECOMMENDED FOR MVP**
- **standard-2** ($200/month): Higher tier, 64GB storage, dedicated resources, followers (read replicas)

### 2.2: Wait for Database Provisioning

```bash
# Check status (runs every 10 seconds until ready)
watch heroku pg:info --app grayledger-production

# After 3-5 minutes, you'll see:
# === DATABASE_URL
# Plan:                  Heroku Postgres Standard 0
# Status:                Available
# Data Size:             8.2 MB
# Tables:                0
# PG Version:            14.8
# Connections:           0
# Connection limit:      120
# Wal-E:                 off
```

Press `Ctrl+C` to exit watch mode.

### 2.3: Verify DATABASE_URL Environment Variable

```bash
heroku config:get DATABASE_URL --app grayledger-production

# postgres://user:password@ec2-123-45-67-89.compute-1.amazonaws.com:5432/dbname
```

This confirms PostgreSQL is provisioned and connected. Environment variable is automatically set by Heroku.

---

## Step 3: Configure Buildpacks

Buildpacks are scripts that prepare your app for deployment. Order matters: Ruby first, then pgvector.

### 3.1: Add Ruby Buildpack

```bash
heroku buildpacks:add heroku/ruby --app grayledger-production --index 1

# Buildpack added. Next release on ⬢ grayledger-production will use heroku/ruby.
# Run `git push heroku main` to create a new release using this buildpack.
```

### 3.2: Add pgvector Buildpack

```bash
heroku buildpacks:add https://github.com/heroku/heroku-buildpack-pgvector.git \
  --app grayledger-production --index 2

# Buildpack added. Next release on ⬢ grayledger-production will use heroku-buildpack-pgvector.
# Run `git push heroku main` to create a new release using this buildpack.
```

### 3.3: Verify Buildpack Order

```bash
heroku buildpacks --app grayledger-production

# 1. heroku/ruby
# 2. https://github.com/heroku/heroku-buildpack-pgvector.git
```

**Critical:** Ruby MUST be first, pgvector second. If order is wrong:

```bash
# Wrong order detected? Fix with:
heroku buildpacks:clear --app grayledger-production
heroku buildpacks:add heroku/ruby --app grayledger-production --index 1
heroku buildpacks:add https://github.com/heroku/heroku-buildpack-pgvector.git \
  --app grayledger-production --index 2
```

---

## Step 4: Set Environment Variables

### 4.1: Production Rails Configuration

```bash
heroku config:set \
  RAILS_ENV=production \
  RACK_ENV=production \
  RAILS_LOG_TO_STDOUT=true \
  RAILS_SERVE_STATIC_FILES=true \
  RAILS_MAX_THREADS=5 \
  WEB_CONCURRENCY=2 \
  --app grayledger-production

# Setting config vars... done
# RAILS_ENV: production
# RACK_ENV: production
# RAILS_LOG_TO_STDOUT: true
# RAILS_SERVE_STATIC_FILES: true
# RAILS_MAX_THREADS: 5
# WEB_CONCURRENCY: 2
```

**What these do:**
- `RAILS_ENV=production`: Enables production mode (asset precompilation, error handling, etc.)
- `RAILS_LOG_TO_STDOUT=true`: Sends logs to Heroku's logging system (required for Papertrail integration)
- `RAILS_SERVE_STATIC_FILES=true`: Heroku dynos serve CSS/JS/images
- `RAILS_MAX_THREADS=5`: Thread pool size (default, adjust if you see 500 errors)
- `WEB_CONCURRENCY=2`: Puma workers (adjust based on dyno size)

### 4.2: OpenAI API Key

```bash
heroku config:set OPENAI_API_KEY='sk-...' --app grayledger-production

# Setting config vars... done
# OPENAI_API_KEY: (redacted)
```

Replace `sk-...` with your actual OpenAI API key from [platform.openai.com/account/api-keys](https://platform.openai.com/account/api-keys).

### 4.3: Plaid Integration

```bash
heroku config:set \
  PLAID_CLIENT_ID='...' \
  PLAID_SECRET='...' \
  PLAID_ENV=sandbox \
  --app grayledger-production

# Setting config vars... done
```

**PLAID_ENV options:**
- `sandbox`: For testing (no real bank connections)
- `production`: For live bank feeds (after Plaid review)

Get credentials from [dashboard.plaid.com/team/keys](https://dashboard.plaid.com/team/keys).

### 4.4: TaxCloud Integration

```bash
heroku config:set \
  TAXCLOUD_API_LOGIN='...' \
  TAXCLOUD_API_KEY='...' \
  --app grayledger-production

# Setting config vars... done
```

Get credentials from TaxCloud account dashboard.

### 4.5: AWS S3 Configuration

```bash
heroku config:set \
  AWS_ACCESS_KEY_ID='...' \
  AWS_SECRET_ACCESS_KEY='...' \
  AWS_REGION='us-east-1' \
  AWS_S3_BUCKET='grayledger-production' \
  --app grayledger-production

# Setting config vars... done
```

**Generate AWS credentials:**
1. Log in to [AWS Console](https://console.aws.amazon.com)
2. Go to IAM → Users → Add User
3. Grant "AmazonS3FullAccess" policy (or custom least-privilege policy)
4. Create access key, copy ID and secret key
5. Create S3 bucket: `aws s3 mb s3://grayledger-production --region us-east-1`

**⚠️ SECURITY:** Never commit these keys to git. Heroku stores them encrypted.

### 4.6: Verify All Config Vars Set

```bash
heroku config --app grayledger-production

# === grayledger-production Config Vars
# AWS_ACCESS_KEY_ID:           (redacted)
# AWS_REGION:                  us-east-1
# AWS_S3_BUCKET:               grayledger-production
# AWS_SECRET_ACCESS_KEY:       (redacted)
# DATABASE_URL:                postgres://...
# OPENAI_API_KEY:              (redacted)
# PLAID_CLIENT_ID:             (redacted)
# PLAID_ENV:                   sandbox
# PLAID_SECRET:                (redacted)
# RAILS_ENV:                   production
# RAILS_LOG_TO_STDOUT:         true
# RAILS_MAX_THREADS:           5
# RAILS_SERVE_STATIC_FILES:    true
# RACK_ENV:                    production
# TAXCLOUD_API_KEY:            (redacted)
# TAXCLOUD_API_LOGIN:          (redacted)
# WEB_CONCURRENCY:             2
```

All expected variables present? ✅ Continue to Step 5.

---

## Step 5: Deploy to Heroku

### 5.1: Ensure Clean Git State

```bash
git status

# On branch main
# nothing to commit, working tree clean
```

If there are uncommitted changes, commit them first:

```bash
git add .
git commit -m "Prepare for Heroku deployment"
```

### 5.2: Deploy

```bash
git push heroku main

# Enumerating objects: 357, done.
# Counting objects: 100% (357/357), done.
# ...
# remote: Verifying deploy... done.
# To https://git.heroku.com/grayledger-production.git
#    abc1234..def5678  main -> main
```

### 5.3: Monitor Build Process

```bash
heroku logs --tail --app grayledger-production

# 2025-11-21T14:35:00.000000+00:00 heroku[api]: Release v1 created by user@example.com
# 2025-11-21T14:35:01.123456+00:00 heroku[web.1]: State changed from crashed to starting
# 2025-11-21T14:35:15.654321+00:00 app[web.1]: ... Rails startup logs ...
# 2025-11-21T14:35:25.987654+00:00 app[web.1]: Listening on port 3000
```

Press `Ctrl+C` to stop tailing logs.

### 5.4: Verify App is Running

```bash
heroku ps --app grayledger-production

# Free dyno hours quota remaining: 550h 0m
# ⬢ grayledger-production web.1:Free is up

# OR (if web dyno crashed)
# ⬢ grayledger-production web.1:Free is down (crashed)

heroku logs --app grayledger-production | tail -50
# Check logs for error message
```

If web dyno crashed, check the logs for errors (common: missing config vars, database issue).

### 5.5: Open App in Browser

```bash
heroku open --app grayledger-production

# Opens https://grayledger-production.herokuapp.com in your browser
```

You should see the GrayLedger login page. If you see error page, check logs:

```bash
heroku logs --app grayledger-production -n 100
```

---

## Step 6: Run Database Migrations

### 6.1: Execute Migrations on Production Database

```bash
heroku run rails db:migrate --app grayledger-production

# Running rails db:migrate on ⬢ grayledger-production... up, run.1234
# ...
# 20251121231406: EnablePgvector
```

**Note:** This creates tables and seeds data. Takes 1-5 minutes depending on schema size.

### 6.2: Verify Migration Status

```bash
heroku run rails db:migrate:status --app grayledger-production

# database: postgres://...
#
#  Status   Migration ID    Migration Name
# --------------------------------------------------
#    up     20251104120000  Create users
#    up     20251121231406  Enable pgvector
#   ...
#    up     20251121231525  Create entries
```

All migrations showing `up`? ✅ Continue to Step 7.

---

## Step 7: Verify pgvector Enabled

### 7.1: Check pgvector Extension

```bash
heroku pg:psql --app grayledger-production <<EOF
SELECT * FROM pg_extension WHERE extname='vector';
EOF

# extname | extowner | extnamespace | extrelocatable | extversion | extconfig | extcondition
# --------+----------+--------------+----------------+------------+-----------+-----------
# vector  |       10 |         2200 | f              | 0.8.1      |           |
```

pgvector extension is installed and enabled! ✅

If no output or error, pgvector buildpack failed. See [Troubleshooting: pgvector Not Loading](#troubleshooting).

### 7.2: Test Vector Operations

```bash
heroku pg:psql --app grayledger-production <<EOF
SELECT '[1, 2, 3]'::vector;
EOF

# vector
# --------
# [1,2,3]
```

Vector type works! ✅

---

## Step 8: Scale Dynos

### 8.1: Scale Web Dyno (Optional)

By default, Heroku creates one free `web.1` dyno. For production, scale to at least Standard dynos:

```bash
# FREE TIER (for testing only):
heroku ps:scale web=1:free --app grayledger-production
# This uses 550 free dyno hours/month (enough for 1 small app)

# PRODUCTION TIER (recommended):
heroku ps:scale web=1:standard-1x --app grayledger-production
# $50/mo per Standard-1X dyno

heroku ps --app grayledger-production
# ⬢ grayledger-production
# web.1: Standard-1X, 512 MB

# Check cost:
heroku billing:info --app grayledger-production
```

### 8.2: Scale Worker Dyno for Background Jobs

Solid Queue requires a worker dyno to process background jobs:

```bash
heroku ps:scale worker=1:standard-1x --app grayledger-production

# Scaling dynos... done, now running web at 1:Standard-1X, worker at 1:Standard-1X
```

### 8.3: Verify Dynos Running

```bash
heroku ps --app grayledger-production

# ⬢ grayledger-production
# web.1:   Standard-1X, 512 MB, up, last contacted 2s ago
# worker.1: Standard-1X, 512 MB, up, last contacted 5s ago
```

Both dynos running? ✅

---

## Step 9: Test Background Jobs

Solid Queue processes jobs using the worker dyno. Test it:

### 9.1: Queue Test Job

```bash
heroku run rails runner "TestJob.perform_later" --app grayledger-production

# Running rails runner TestJob.perform_later on ⬢ grayledger-production... up, run.1234
# Job queued! (ID: abc1234567890)
```

### 9.2: Monitor Job Processing

```bash
heroku logs --tail --app grayledger-production

# 2025-11-21T14:45:30.123456+00:00 app[worker.1]: Processing: TestJob
# 2025-11-21T14:45:31.654321+00:00 app[worker.1]: Finished: TestJob
```

Job processed by worker dyno? ✅

### 9.3: Check Mission Control - Jobs (Optional)

Heroku provides job monitoring dashboard. Enable it:

```bash
heroku features:enable runtime-dyno-metadata --app grayledger-production
# Enabling runtime-dyno-metadata for ⬢ grayledger-production... done
```

Then visit [dashboard.heroku.com](https://dashboard.heroku.com) → Select app → "Resources" tab → "Mission Control – Jobs" to see real-time job processing.

---

## Step 10: Test S3 Uploads (Optional)

If you have AWS credentials configured:

### 10.1: Test via Rails Console

```bash
heroku run rails console --app grayledger-production

# irb(main):001:0>
# require 'open-uri'
# file = URI.open('https://example.com/receipt.jpg')
# blob = ActiveStorage::Blob.create_and_upload!(io: file, filename: 'receipt.jpg')
# => #<ActiveStorage::Blob ...>
#
# irb(main):002:0> blob.service.exist?(blob.key)
# => true
# (exit console with Ctrl+D)
```

If upload succeeds, blob.service.exist? returns true. ✅

### 10.2: Test via Web UI

1. Open https://grayledger-production.herokuapp.com
2. Log in with test user
3. Navigate to receipt upload
4. Upload test image
5. Check S3 bucket: `aws s3 ls s3://grayledger-production/`

If file appears in S3, upload works! ✅

---

## Verification Checklist

Run this checklist after deployment:

```bash
APP_NAME=grayledger-production

# ✅ App is running
heroku ps --app $APP_NAME | grep "web.*up"

# ✅ Database connection works
heroku run rails db:version --app $APP_NAME

# ✅ pgvector extension enabled
heroku pg:psql --app $APP_NAME <<EOF
SELECT * FROM pg_extension WHERE extname='vector';
EOF

# ✅ All migrations applied
heroku run rails db:migrate:status --app $APP_NAME | grep "Status"

# ✅ Worker dyno processing jobs
heroku ps --app $APP_NAME | grep "worker.*up"

# ✅ Environment variables set
heroku config --app $APP_NAME | grep -c "RAILS_ENV\|OPENAI_API_KEY\|AWS_"

# ✅ SSL enforced (no HTTP errors)
curl -I https://grayledger-production.herokuapp.com/

# ✅ Logs accessible
heroku logs --app $APP_NAME -n 10
```

All checks passing? 🎉 Deployment successful!

---

## Troubleshooting

### Issue: pgvector Extension Not Loading

**Symptoms:**
```
PG::UndefinedObject: ERROR: type "vector" does not exist
```

**Cause:** pgvector buildpack misconfigured or not run yet.

**Solution:**

1. Verify buildpack order:
```bash
heroku buildpacks --app grayledger-production
# Should show:
# 1. heroku/ruby
# 2. https://github.com/heroku/heroku-buildpack-pgvector.git
```

2. If wrong, fix it:
```bash
heroku buildpacks:clear --app grayledger-production
heroku buildpacks:add heroku/ruby --app grayledger-production --index 1
heroku buildpacks:add https://github.com/heroku/heroku-buildpack-pgvector.git \
  --app grayledger-production --index 2
```

3. Redeploy with a dummy change:
```bash
git commit --allow-empty -m "Trigger rebuild with pgvector buildpack"
git push heroku main
```

4. Manually enable extension (if buildpack still fails):
```bash
heroku pg:psql --app grayledger-production <<EOF
CREATE EXTENSION IF NOT EXISTS vector;
EOF
```

5. Verify:
```bash
heroku pg:psql --app grayledger-production <<EOF
SELECT * FROM pg_extension WHERE extname='vector';
EOF
```

### Issue: Database Migrations Failed

**Symptoms:**
```
PG::ConnectionBad: could not connect to server
```

**Cause:** DATABASE_URL not set or database not ready.

**Solution:**

1. Check database exists:
```bash
heroku pg:info --app grayledger-production
```

If database not showing, create it:
```bash
heroku addons:create heroku-postgresql:standard-0 --app grayledger-production
```

2. Wait 3-5 minutes for provisioning, then retry:
```bash
heroku run rails db:migrate --app grayledger-production
```

3. Check config vars:
```bash
heroku config --app grayledger-production | grep DATABASE_URL
```

If not present, re-add database add-on.

### Issue: Memory Limit Exceeded (R14 Error)

**Symptoms:**
```
heroku[worker.1]: Error R14 (Memory quota exceeded)
```

**Cause:** Background job consuming too much memory, or WEB_CONCURRENCY too high.

**Solution:**

1. Reduce web concurrency:
```bash
heroku config:set WEB_CONCURRENCY=1 --app grayledger-production
```

2. Reduce max threads:
```bash
heroku config:set RAILS_MAX_THREADS=3 --app grayledger-production
```

3. Upgrade dyno size:
```bash
heroku ps:scale web=1:standard-2x --app grayledger-production
```

4. Identify memory-heavy job and optimize (see logs):
```bash
heroku logs --app grayledger-production -n 100 | grep "Error R14"
```

### Issue: App Crashes on Startup

**Symptoms:**
```
heroku[web.1]: State changed from starting to crashed
```

**Cause:** Missing config var, missing gem, or schema issue.

**Solution:**

1. Check logs:
```bash
heroku logs --app grayledger-production -n 50
```

2. Look for errors like:
   - `Unknown variable: OPENAI_API_KEY` → Missing config var, run Step 4
   - `uninitialized constant` → Missing gem, run `bundle install` locally, commit, redeploy
   - `PG::Error` → Database issue, check migrations status

3. If config var missing:
```bash
heroku config:set OPENAI_API_KEY='sk-...' --app grayledger-production
heroku restart --app grayledger-production
```

4. If gem missing:
```bash
bundle install
git add Gemfile.lock
git commit -m "Add missing gem"
git push heroku main
```

### Issue: S3 Upload Fails

**Symptoms:**
```
AWS::S3::Errors::InvalidAccessKeyId: The AWS Access Key Id you provided does not exist
```

**Cause:** Incorrect or expired AWS credentials.

**Solution:**

1. Verify AWS credentials locally:
```bash
export AWS_ACCESS_KEY_ID='...'
export AWS_SECRET_ACCESS_KEY='...'
export AWS_REGION='us-east-1'
aws sts get-caller-identity
# Should show your AWS account, not error
```

2. If error, regenerate AWS credentials:
   - Log in to AWS Console
   - IAM → Users → Find your user
   - Security credentials → Delete old, create new access key
   - Copy new keys

3. Update Heroku config:
```bash
heroku config:set \
  AWS_ACCESS_KEY_ID='new-key-id' \
  AWS_SECRET_ACCESS_KEY='new-secret-key' \
  --app grayledger-production
```

4. Restart app:
```bash
heroku restart --app grayledger-production
```

5. Test upload:
```bash
heroku run rails console --app grayledger-production
# (in console)
# require 'open-uri'
# file = URI.open('https://www.w3schools.com/css/img_5terre.jpg')
# blob = ActiveStorage::Blob.create_and_upload!(io: file, filename: 'test.jpg')
# blob.service.exist?(blob.key) # Should return true
```

### Issue: Slow Deployments

**Symptoms:**
```
git push heroku main takes >5 minutes
```

**Cause:** Large Gemfile, asset precompilation, or database migration.

**Solution:**

1. Check build logs:
```bash
git push heroku main 2>&1 | tee build.log
cat build.log | grep -A5 "Compiling\|Migrating"
```

2. If slow at asset precompilation, add to `config/environments/production.rb`:
```ruby
config.assets.precompile += %w[application.js application.css]
```

3. If slow at bundling, update `Gemfile.lock`:
```bash
bundle update --bundler
bundle install
git add Gemfile.lock
git commit -m "Update Gemfile.lock"
git push heroku main
```

4. If slow at database migration, optimize schema:
```bash
# Locally, profile slow query:
rails db:migrate
rails runner "puts SomeModel.count" # Check query time in logs
```

### Issue: 404 Page Not Found on Static Files

**Symptoms:**
```
GET /assets/application.js → 404 Not Found
```

**Cause:** RAILS_SERVE_STATIC_FILES not set or assets not precompiled.

**Solution:**

1. Verify config var:
```bash
heroku config:get RAILS_SERVE_STATIC_FILES --app grayledger-production
# Should output: true
```

2. If not set:
```bash
heroku config:set RAILS_SERVE_STATIC_FILES=true --app grayledger-production
heroku restart --app grayledger-production
```

3. If still 404, assets not precompiled during build:
```bash
# Force rebuild
git commit --allow-empty -m "Rebuild assets"
git push heroku main

# Check logs for "Precompiling assets..."
heroku logs --app grayledger-production | grep -i "asset\|compile"
```

### Issue: Rate Limiting Too Strict (Too Many 429 Errors)

**Symptoms:**
```
HTTP 429 Too Many Requests after <100 requests/minute
```

**Cause:** Rack::Attack rate limit too low.

**Solution:**

1. Check Rack::Attack config:
```bash
grep -A10 "throttle\|Throttle" config/initializers/rack_attack.rb
```

2. Adjust limits in `config/initializers/rack_attack.rb`:
```ruby
# Current: 100 requests/minute per IP
Rack::Attack.throttle('requests by ip', limit: 100, period: 60) do |req|
  # Change to: 500 requests/minute
  limit: 500
end
```

3. Restart app:
```bash
git add config/initializers/rack_attack.rb
git commit -m "Increase rate limit to 500 req/min"
git push heroku main
```

---

## Monitoring & Operations

### Daily Checks

Every morning, verify app is healthy:

```bash
# 1. Check dyno status
heroku ps --app grayledger-production

# 2. Check recent errors in logs
heroku logs --app grayledger-production --tail -n 50 | grep "ERROR\|Error"

# 3. Check database size (should grow slowly)
heroku pg:info --app grayledger-production

# 4. Check if worker processed jobs
heroku logs --app grayledger-production | grep "Processing:" | tail -10
```

### Weekly Tasks

- [ ] **Backup verification:** `heroku pg:backups` shows recent daily backup
- [ ] **Cost check:** `heroku billing:info --app grayledger-production` still under budget
- [ ] **Log review:** Search logs for ERRORs or unusual patterns
- [ ] **Secret rotation reminder:** (Monthly) Check if any API keys due for rotation

### Monthly Tasks

- [ ] **Upgrade check:** `heroku log` for deprecation warnings
- [ ] **Dependency updates:** `bundle update`, test locally, deploy
- [ ] **Database cleanup:** Remove old test data, expired tokens
- [ ] **Cost analysis:** Review dyno types, database size, bandwidth

### Secret Rotation (Every 90 Days)

Secrets expire and should be rotated regularly:

**OpenAI API Key:**
```bash
# 1. Generate new key in OpenAI dashboard
# 2. Test locally: OPENAI_API_KEY=sk-new rails console
# 3. Update Heroku:
heroku config:set OPENAI_API_KEY='sk-new-key' --app grayledger-production
# 4. Monitor logs for 24 hours (no "invalid API key" errors)
# 5. Delete old key from OpenAI dashboard
```

**Plaid Secret:**
```bash
# 1. Generate new secret in Plaid dashboard → Keys
# 2. Test in sandbox environment first
# 3. Update Heroku:
heroku config:set PLAID_SECRET='new-secret' --app grayledger-production
# 4. Monitor bank transaction syncs for 48 hours
# 5. Deactivate old secret in Plaid dashboard
```

**AWS IAM Keys:**
```bash
# 1. Create new access key in AWS IAM console
# 2. Test locally:
export AWS_ACCESS_KEY_ID='new-id'
export AWS_SECRET_ACCESS_KEY='new-secret'
aws sts get-caller-identity
# 3. Update Heroku:
heroku config:set AWS_ACCESS_KEY_ID='new-id' AWS_SECRET_ACCESS_KEY='new-secret' --app grayledger-production
# 4. Monitor S3 uploads for 24 hours (check logs for errors)
# 5. Deactivate old key in AWS IAM (keep for 7 days in case of issues)
# 6. Delete old key after 7 days
```

**TaxCloud API Key:**
```bash
# 1. Contact TaxCloud support → request key rotation
# 2. Receive new key
# 3. Test in sandbox environment
# 4. Update Heroku:
heroku config:set TAXCLOUD_API_KEY='new-key' --app grayledger-production
# 5. Monitor sales tax calculations for 24 hours
# 6. Confirm old key deactivated with TaxCloud support
```

---

## Rollback Procedures

### Rollback Recent Deployment

If deployment breaks the app:

```bash
# View releases (last 15 kept by Heroku)
heroku releases --app grayledger-production | head -10

# Example output:
# Version   Committed At                   Description
# -------   ------------------------       --------------------------------
# v42       2025-11-21 14:35:00 +0000      Deploy abc1234
# v41       2025-11-21 10:00:00 +0000      Deploy def5678
# v40       2025-11-20 20:15:00 +0000      Deploy ghi9012

# Rollback to previous version
heroku rollback --app grayledger-production

# OR rollback to specific release:
heroku rollback v40 --app grayledger-production

# Verify rollback succeeded
heroku logs --app grayledger-production -n 20
```

### Rollback Database Migration

If migration broke schema:

```bash
# 1. Check backup available:
heroku pg:backups --app grayledger-production

# Example output:
# ID   Created At                 Status
# ---  ---                        ------
# b01  2025-11-21 11:30 +0000    Completed
# b00  2025-11-20 12:00 +0000    Completed

# 2. Restore from backup:
heroku pg:backups:restore b01 --app grayledger-production

# This is destructive - warns before proceeding

# 3. Verify restore succeeded:
heroku run rails db:migrate:status --app grayledger-production
```

**Note:** Restore deletes current database and replaces with backup. Use only in emergencies.

---

## Cost Management

### Monthly Cost Breakdown

**Minimum production setup:**
```
Heroku Postgres Standard-0:  $50/month (10GB, 120 connections)
Web dyno (Standard-1X):      $50/month (512MB, shared CPU)
Worker dyno (Standard-1X):   $25/month (background jobs)
S3 storage (100GB):          $2.30/month
S3 data transfer:            Variable (typically <$5)
Papertrail logs (free):      $0/month
----------------------------------------------
Total:                       ~$130-150/month
```

### Cost Optimization

**Scale down during development:**
```bash
# Use free dynos for development (won't sleep if in development environment):
heroku config:set HEROKU_ENV=development --app grayledger-production

# Scale web to free dyno:
heroku ps:scale web=1:free --app grayledger-production
# Free tier = 550 dyno hours/month (enough for 1 app with 24/7 uptime)
```

**Monitor usage:**
```bash
# View spending for current month
heroku billing:info --app grayledger-production

# Set spending alert
heroku billing:set-spending-limit 100 --app grayledger-production
# Stops free dynos if you hit $100/month
```

**Scale up only when needed:**
- MVP: 1 web + 1 worker (Standard tier)
- 100+ companies: 2 web + 2 worker (monitor performance)
- 1000+ companies: Upgrade to Standard-2 or Premium tier

---

## Security Hardening

### SSL/TLS Enforcement

Verify SSL is enforced (all HTTP traffic redirects to HTTPS):

```bash
curl -I http://grayledger-production.herokuapp.com

# Should return:
# HTTP/1.1 301 Moved Permanently
# Location: https://grayledger-production.herokuapp.com/
```

If not enforcing, enable in `config/environments/production.rb`:

```ruby
config.force_ssl = true
```

Then redeploy:

```bash
git add config/environments/production.rb
git commit -m "Force SSL in production"
git push heroku main
```

### Rate Limiting

Verify Rack::Attack is active:

```bash
# Send 200 requests rapidly from same IP
for i in {1..200}; do
  curl -s https://grayledger-production.herokuapp.com/health -w "Status: %{http_code}\n"
done | sort | uniq -c

# Should see:
# ...
# 100 Status: 200
# 100 Status: 429
```

If 429 doesn't appear, rate limiting not working. Check `config/initializers/rack_attack.rb`.

### Environment Variable Security

Never commit secrets to git:

```bash
# Verify no secrets in repo:
git log --all --source -- Heroku --oneline
git grep "OPENAI_API_KEY\|AWS_SECRET"

# Should return no results
```

If secrets were committed accidentally:

```bash
# Never just delete - history remains!
# Instead, rotate the secret immediately:
heroku config:set OPENAI_API_KEY='sk-new-key' --app grayledger-production

# And contact OpenAI to revoke old key
```

### 2FA for Heroku Account

Enable two-factor authentication on Heroku account:

1. Log in to [heroku.com/dashboard](https://dashboard.heroku.com)
2. Account → Security → Two-factor authentication
3. Enable authenticator app or SMS
4. Save backup codes

Once enabled, all `heroku` CLI commands require verification.

---

## Additional Resources

- **Heroku Documentation:** [devcenter.heroku.com](https://devcenter.heroku.com)
- **ADR 01.002:** [docs/adrs/01.foundation/01.002.heroku-postgres-pgvector.md](../adrs/01.foundation/01.002.heroku-postgres-pgvector.md)
- **Disaster Recovery Runbook:** [docs/runbooks/disaster-recovery.md](../runbooks/disaster-recovery.md)
- **Secret Rotation Runbook:** [docs/runbooks/secret-rotation.md](../runbooks/secret-rotation.md)

---

**Last Updated:** 2025-11-21
**Applies to:** GrayLedger v1.0.0+
**Status:** Production-ready
