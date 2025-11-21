# Disaster Recovery Runbook

**Last Updated:** 2025-11-21
**Status:** Active
**Audience:** Platform Engineers, DevOps
**Severity Levels:** Critical, High, Medium

This runbook provides step-by-step procedures for backup verification, database restoration, and rollback in case of emergencies.

---

## Table of Contents

1. [Backup Verification](#backup-verification)
2. [Database Restore Procedures](#database-restore-procedures)
3. [Code Rollback Procedures](#code-rollback-procedures)
4. [Emergency Contacts](#emergency-contacts)
5. [Recovery Testing](#recovery-testing)
6. [Post-Incident Actions](#post-incident-actions)

---

## Backup Verification

### Daily Backup Verification Procedure

**Frequency:** Daily (automated check + manual weekly verification)
**Time to Complete:** 5 minutes
**Tools Required:** Heroku CLI, PostgreSQL client (psql)

#### Step 1: Verify Automated Backup Schedule

Check that Heroku Postgres Standard-0 has daily backups enabled:

```bash
heroku pg:backups -a grayledger-production
```

**Expected Output:**
```
ID    Created at                 Status      Size      Database
----  -------------------------  ----------  --------  --------
a001  2025-11-21 02:00:00 +0000  Completed   245 MB    DATABASE
a002  2025-11-20 02:00:00 +0000  Completed   244 MB    DATABASE
a003  2025-11-19 02:00:00 +0000  Completed   243 MB    DATABASE
...
```

**What to Look For:**
- Daily backups present (one per day)
- Status shows "Completed" (not "Pending" or "Failed")
- Size is reasonable (within 10% of previous day)
- Most recent backup is from today or yesterday (Heroku runs at 02:00 UTC)

#### Step 2: Verify Backup Retention

Confirm you have 7-day rolling retention:

```bash
heroku pg:backups -a grayledger-production | wc -l
```

**Expected Result:** Approximately 7-8 backup records (7-day rolling window + current)

#### Step 3: Verify Latest Backup Integrity

Check the most recent backup details:

```bash
heroku pg:backups:info a001 -a grayledger-production
```

**Expected Output:**
```
Name:    DATABASE
Created: 2025-11-21 02:00:00 +0000
Status:  Completed
Size:    245 MB
```

#### Step 4: Manual Backup (Weekly)

Create a manual backup as extra safety net (especially before major deployments):

```bash
heroku pg:backups:capture -a grayledger-production
# Output: Creating backup... done
# Backup b001 finished
```

**When to Take Manual Backups:**
- Before deploying schema changes
- Before running data migrations
- Before deploying critical features
- Before major version upgrades

#### Step 5: Alert Setup (Automated)

Ensure monitoring is in place. Add to your status page or monitoring system:

```ruby
# Example: Rails scheduled job to check backups daily
class BackupVerificationJob < ApplicationJob
  queue_as :default

  def perform
    backups = `heroku pg:backups -a grayledger-production 2>/dev/null`.split("\n")

    # Check if today's backup exists
    today = Date.today.strftime("%Y-%m-%d")
    backup_exists = backups.any? { |line| line.include?(today) }

    unless backup_exists
      AlertService.notify(
        subject: "CRITICAL: Database backup missing for #{today}",
        body: "Manual intervention required. Check Heroku dashboard immediately."
      )
    end
  end
end
```

---

## Database Restore Procedures

### Restore: Heroku Production → Local Development Database

**Severity:** Medium
**Time to Complete:** 15-30 minutes
**Prerequisites:**
- Local PostgreSQL installed (`brew install postgresql` on macOS)
- Heroku CLI installed (`brew install heroku` on macOS)
- Authenticated with Heroku (`heroku auth:login`)

#### Step 1: Create Local Empty Database

```bash
# Drop existing dev database (optional, if you want fresh copy)
dropdb grayledger_development

# Create new empty database
createdb grayledger_development
```

#### Step 2: Download Latest Backup

```bash
# Get backup ID
heroku pg:backups -a grayledger-production

# Download the latest backup (ID: a001)
heroku pg:backups:download a001 -a grayledger-production
# Downloads to ./latest.dump (PostgreSQL binary format)
```

#### Step 3: Restore to Local Database

```bash
# Restore the dump file
pg_restore --verbose --clean --if-exists --no-acl --no-owner -h localhost -U $(whoami) -d grayledger_development ./latest.dump

# Wait for restore to complete (may take 5-10 minutes for large databases)
```

**Verify Restore Success:**

```bash
# Check table count
psql grayledger_development -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"

# Check entry count (should be > 0 if data present)
psql grayledger_development -c "SELECT COUNT(*) FROM entries;"

# Start Rails and verify
rails console
# IRB: Entry.count  (should match production)
```

#### Troubleshooting

| Symptom | Cause | Solution |
|---------|-------|----------|
| `pg_restore: error: invalid BOM header` | Corrupted dump file | Re-download backup with `heroku pg:backups:download` |
| `ERROR: role "postgres" does not exist` | Wrong ownership | Use `--no-owner` flag in pg_restore (included above) |
| `Out of disk space` | Local disk full | Check disk space with `df -h`, may need older backup |
| Restore hangs | Large database | Use `psql --quiet` to suppress progress and try again |

---

### Restore: Heroku Production → Heroku Staging

**Severity:** High
**Time to Complete:** 10-15 minutes (Heroku is faster than local restore)
**Prerequisites:**
- Staging app already exists (`grayledger-staging`)
- Heroku Postgres database attached to staging app
- Permission to promote databases

#### Step 1: Verify Staging App Exists

```bash
heroku apps:info grayledger-staging -a grayledger-staging
```

#### Step 2: Restore Production Backup to Staging

```bash
# Get production backup ID
heroku pg:backups -a grayledger-production

# Restore to staging database (ID: a001)
heroku pg:backups:restore a001 DATABASE -a grayledger-staging
# Prompts: Type 'grayledger-staging' to confirm
```

**Expected Output:**
```
 ▸    WARNING: Destructive action
 ▸    This will overwrite data in postgres-xxx of grayledger-staging
 ▸    To proceed, type grayledger-staging or re-run this command with --confirm grayledger-staging

grayledger-staging
Restoring database from backup 'a001'... done
```

#### Step 3: Verify Staging Data

```bash
# Connect to staging database and verify
heroku pg:psql -a grayledger-staging
# At psql prompt:
# SELECT COUNT(*) FROM entries;  (should match production)
# \q (quit)
```

#### Step 4: Test Staging App

```bash
# Deploy to staging (if not already deployed)
git push heroku main:main -a grayledger-staging

# Run migrations if needed
heroku run 'rails db:migrate' -a grayledger-staging

# Run smoke tests
heroku run 'rails test' -a grayledger-staging

# Check app health
curl https://grayledger-staging.herokuapp.com/health
# Expected: 200 OK
```

#### Step 5: Rollback Staging (If Issues Found)

```bash
# If staging has critical issues and you need to restore from earlier backup
heroku pg:backups:restore a002 DATABASE -a grayledger-staging
# (Choose earlier backup ID)
```

---

### Restore: Emergency Partial Recovery

**Severity:** Critical
**Scenario:** Production corrupted, need to restore single table
**Time to Complete:** 20-30 minutes

#### Step 1: Download and Extract Backup

```bash
# Download backup
heroku pg:backups:download a001 -a grayledger-production

# Extract specific table to SQL dump
pg_dump -t entries --data-only latest.dump > entries_data.sql
```

#### Step 2: Restore Single Table to Production

**CRITICAL: Get approval from product/engineering lead before executing**

```bash
# Backup current table first
heroku pg:psql -a grayledger-production << 'EOF'
CREATE TABLE entries_backup_2025_11_21 AS SELECT * FROM entries;
EOF

# Restore from SQL dump
cat entries_data.sql | heroku pg:psql -a grayledger-production
```

#### Step 3: Verify Data Integrity

```bash
heroku pg:psql -a grayledger-production << 'EOF'
-- Check counts match
SELECT COUNT(*) FROM entries;
SELECT COUNT(*) FROM entries_backup_2025_11_21;

-- Check for data consistency
SELECT posted_at, COUNT(*) FROM entries GROUP BY posted_at ORDER BY posted_at DESC LIMIT 10;
EOF
```

---

## Code Rollback Procedures

### Rollback: Bad Deployment (Code Only)

**Severity:** High
**Time to Complete:** 5 minutes
**Prerequisites:**
- Know the deployment hash of the last known-good release
- Heroku CLI installed and authenticated

#### Step 1: Identify Last Known-Good Release

```bash
# View deployment history
heroku releases -a grayledger-production

# Output example:
# Version  When                Who          Change
# -------  ----------------   ---------    ----
# v256     2025-11-21 14:35   engineer@co  Deploy abc1234
# v255     2025-11-21 12:10   engineer@co  Deploy def5678
# v254     2025-11-21 09:45   engineer@co  Deploy ghi9012
```

**Identify the commit hash** of the working version (usually one or two releases back).

#### Step 2: Roll Back to Previous Release

```bash
# Rollback to specific release (v255 in example)
heroku rollback v255 -a grayledger-production

# Confirmation:
# Rolled back to v255
```

#### Step 3: Verify Rollback

```bash
# Check current release
heroku releases:info -a grayledger-production

# Check application is healthy
curl https://grayledger-production.herokuapp.com/health
# Expected: 200 OK

# Check logs for errors
heroku logs --tail -a grayledger-production
# Watch for 15-30 seconds, confirm no critical errors
```

#### Step 4: Notify Team

Create an incident report documenting:
- What was deployed (commit hash)
- What went wrong
- When rollback occurred
- Root cause (to be determined)

### Rollback: Database Migrations

**Severity:** Critical (if migration broke schema)
**Time to Complete:** 10-30 minutes depending on data size

#### Step 1: Determine Migration Status

```bash
# Check current schema version
heroku run 'rails db:version' -a grayledger-production

# Check recent migrations
heroku run 'rails db:migrate:status' -a grayledger-production | head -20
```

#### Step 2: Rollback Migration on Staging First

**ALWAYS test rollback on staging before production**

```bash
# Restore staging to a point before the bad migration
heroku pg:backups:restore a002 DATABASE -a grayledger-staging

# Deploy code that includes migration revert
git revert <bad-migration-commit>
git push heroku main:main -a grayledger-staging

# Run migration rollback
heroku run 'rails db:migrate:down VERSION=<version>' -a grayledger-staging

# Test application
curl https://grayledger-staging.herokuapp.com/health
heroku run 'rails test' -a grayledger-staging
```

#### Step 3: If Staging Rollback Successful

```bash
# Deploy revert to production
git push heroku main:main -a grayledger-production

# Run migration rollback
heroku run 'rails db:migrate:down VERSION=<version>' -a grayledger-production

# Monitor for errors
heroku logs --tail -a grayledger-production
```

#### Step 4: Restore from Database Backup if Schema Corruption

If migration corrupted data, restore from backup instead of trying to rollback:

```bash
# Restore production from backup (before bad migration)
heroku pg:backups:restore a003 DATABASE -a grayledger-production

# Verify data
heroku pg:psql -a grayledger-production << 'EOF'
SELECT COUNT(*) FROM entries;
EOF
```

---

## Emergency Contacts

### Support Escalation Path

**Level 1: Internal Investigation** (5 minutes)
- Check Heroku dashboard
- Check application logs
- Check database status
- Verify backup existence

**Level 2: Heroku Support** (if infrastructure issue, SLA: 1 hour)

```
Heroku Support Portal: https://help.heroku.com
Email: support@heroku.com
Phone: +1-877-435-9375 (Heroku Platinum support, if available)

Account: [YOUR_HEROKU_ACCOUNT_EMAIL]
App: grayledger-production
Issue: [BRIEF DESCRIPTION]

Include in ticket:
- Heroku app name: grayledger-production
- Symptom: [specific error or behavior]
- When it started: [timestamp UTC]
- Steps to reproduce: [if applicable]
- Heroku release version: $(heroku releases -a grayledger-production)
- Recent logs: [attach last 100 lines from heroku logs -a grayledger-production]
```

**Level 3: AWS Support** (if S3/infrastructure issue, SLA: varies by plan)

```
AWS Support: https://console.aws.amazon.com/support
Email: [AWS account owner email]
Phone: [AWS account phone number]

Service: S3 (if file storage issue)
Region: us-east-1
Issue: [BRIEF DESCRIPTION]

Include:
- S3 bucket: grayledger-production-uploads
- Symptom: [specific error]
- Error timestamp: [UTC]
- Request ID: [from error response if available]
```

**Level 4: Database Specialist** (if corruption suspected)

- Contact Heroku Premium Support for database-specific assistance
- May require professional recovery service (expensive, last resort)
- Prevent with: regular backups, testing before prod changes

### On-Call Escalation

```
If you are on-call and encounter a critical incident:

1. DECLARE INCIDENT
   - Slack: #incident-channel (if exists)
   - Status page: Update status to "Major Outage"
   - Notify: engineering lead, product manager

2. TIMELINE
   - T+0: Declare incident
   - T+5: Initial diagnosis
   - T+15: Decide on restore vs rollback
   - T+30: Execute recovery plan
   - T+60: Post-incident review scheduled

3. COMMUNICATION
   - Update status page every 15 minutes
   - Public statement: "We're investigating a service issue"
   - Internal: Include specific error details and ETA

4. EXECUTION
   - Don't panic (backups exist, data is safe)
   - Don't make changes without verification
   - Test on staging first
   - Document every action taken
```

---

## Recovery Testing

### Monthly Disaster Recovery Drill

**Schedule:** First Friday of each month at 10am UTC
**Duration:** 30 minutes
**Participants:** At least one engineer + product manager

#### Drill 1: Backup Verification (5 minutes)

```bash
# Run backup verification procedure
heroku pg:backups -a grayledger-production
# Verify all checks pass
```

**Pass Criteria:**
- Daily backups exist
- Status shows "Completed"
- Most recent backup within 24 hours

#### Drill 2: Local Restore Test (15 minutes)

```bash
# Follow "Restore: Heroku → Local" procedure
heroku pg:backups:download a001 -a grayledger-production
pg_restore ... grayledger_development
rails test  # Run test suite against restored data
```

**Pass Criteria:**
- Local database restored successfully
- All tests pass
- Data matches production (row counts, checksums)

#### Drill 3: Staging Restore Test (10 minutes)

```bash
# Follow "Restore: Heroku → Staging" procedure
heroku pg:backups:restore a001 DATABASE -a grayledger-staging
curl https://grayledger-staging.herokuapp.com/health
heroku run 'rails test' -a grayledger-staging
```

**Pass Criteria:**
- Staging restore succeeds
- Health check returns 200
- Test suite passes
- Response times normal (no hanging queries)

#### Document Results

```markdown
# Disaster Recovery Drill - [DATE]

**Date:** 2025-11-21
**Participants:** engineer@company.com, product@company.com

## Results

- [ ] Backup Verification: PASS/FAIL
  - Latest backup: 2025-11-21 02:00:00 UTC
  - Size: 245 MB

- [ ] Local Restore: PASS/FAIL
  - Download time: 3 minutes
  - Restore time: 8 minutes
  - Test results: 329/329 passing

- [ ] Staging Restore: PASS/FAIL
  - Restore time: 2 minutes (Heroku faster)
  - Health check: 200 OK
  - Test results: 329/329 passing

**Conclusion:** Disaster recovery is in good shape. We can restore production in ~15 minutes.

**Action Items (if any):**
- [ ] [Something to improve]
```

---

## Post-Incident Actions

### Immediately After Recovery (First Hour)

1. **Restore to Monitoring**
   ```bash
   # Verify all monitors are firing correctly
   heroku logs --tail -a grayledger-production
   # Watch for 5 minutes, confirm normal operation
   ```

2. **Customer Communication**
   - Update status page: "Issue resolved"
   - Send email to affected customers (if applicable)
   - Include brief explanation and root cause (once determined)

3. **Data Verification**
   ```bash
   # Check for any data corruption
   heroku pg:psql -a grayledger-production << 'EOF'
   -- Check for orphaned records
   SELECT COUNT(*) FROM line_items WHERE entry_id NOT IN (SELECT id FROM entries);

   -- Check for balance integrity
   SELECT entry_id, SUM(amount_cents) as balance FROM line_items GROUP BY entry_id HAVING SUM(amount_cents) != 0;
   EOF
   ```

4. **Notify Stakeholders**
   - Engineering lead
   - Product manager
   - Finance (if customer data affected)
   - Compliance (if audit trail affected)

### Within 24 Hours

1. **Root Cause Analysis**
   - Gather timeline of events
   - Identify what failed
   - Determine why it failed
   - Document findings

2. **Create Action Items**
   ```markdown
   ## Incident: [Name] - 2025-11-21

   **Timeline:**
   - 14:35 UTC: Deployment v256
   - 14:37 UTC: Alerts firing (high error rate)
   - 14:45 UTC: Rollback executed
   - 14:47 UTC: Service recovered

   **Root Cause:**
   Migration v12345 had a bug in transaction isolation that corrupted
   the entries table under high concurrency.

   **Action Items:**
   - [ ] Fix migration logic (PR #234)
   - [ ] Add concurrency test to test suite
   - [ ] Require staging test run for all migrations
   - [ ] Review code review checklist for migration safety
   ```

3. **Update This Runbook**
   - Add lessons learned
   - Update procedures if anything was unclear
   - Add new section if new issue type discovered

4. **Blameless Post-Mortem**
   - No one person is responsible
   - Focus on process and prevention
   - Document for future engineers
   - Share findings with team

### Within One Week

1. **Implement Preventive Measures**
   ```bash
   # Examples of what might be added:
   - Pre-deployment checklist updated
   - New test case added
   - Monitoring alert added
   - Documentation clarified
   ```

2. **Update Runbooks**
   - Is this covered in current runbooks?
   - Would additional documentation help?
   - Update step-by-step procedures

3. **Track Metrics**
   ```ruby
   # Add to monitoring dashboard
   - Mean time to detect (MTTD): [X minutes]
   - Mean time to recovery (MTTR): [Y minutes]
   - Impact: [Z customers affected]
   - Data loss: [none / some]
   ```

---

## Key Takeaways

| Action | Frequency | Time | Severity |
|--------|-----------|------|----------|
| Verify backups exist | Daily | 5 min | P1 |
| Test local restore | Monthly | 15 min | P2 |
| Test staging restore | Monthly | 10 min | P2 |
| Full drill | Quarterly | 30 min | P2 |
| Review this runbook | Annually | 30 min | P3 |

---

## Related Documentation

- [ADR 01.003: Hosting & Deployment](../adrs/01.foundation/01.003.hosting-deployment.md)
- [Heroku Postgres Backups Guide](https://devcenter.heroku.com/articles/heroku-postgres-backups)
- [PostgreSQL pg_restore Documentation](https://www.postgresql.org/docs/current/app-pgrestore.html)
- [Incident Response Guide](incident-response.md) (if exists)

---

**Document Status:** Final
**Last Reviewed:** 2025-11-21
**Next Review:** 2026-05-21 (6 months)

**Questions?** Contact the DevOps or platform engineering team.
