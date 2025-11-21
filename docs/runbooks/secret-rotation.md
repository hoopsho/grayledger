# Secret Rotation Runbook

**Purpose:** Procedural guide for rotating production API keys and credentials every 90 days to maintain security best practices.

**Schedule:** 90-day rotation cycle with calendar reminders
**Last Updated:** 2025-11-21
**Maintained By:** Platform Team

---

## Quick Reference

| Secret | Rotation Frequency | Procedure | Testing | Rollback |
|--------|-------------------|-----------|---------|----------|
| OpenAI API Key | 90 days | Create new, test dev, update Heroku | Monitor 24h | Restore old key in Heroku |
| Plaid Secret | 90 days | Generate in dashboard, test sandbox | Monitor 48h | Deactivate new, reactivate old |
| TaxCloud API Key | 90 days | Request from support, test sandbox | Monitor 24h | Revert to old key |
| AWS IAM Keys | 90 days | Create new pair, test locally | Monitor 24h | Deactivate new, keep old 7d |

---

## 90-Day Rotation Schedule

### Calendar Setup

Add recurring calendar reminders for **Day 1 and Day 85** of each 90-day cycle:

**Day 1 (Cycle Start):**
- Log entry: "Secret rotation cycle started"
- Verification: All secrets last rotated within 90 days
- Action: None (just informational checkpoint)

**Day 85 (Rotation Due Soon):**
- Reminder: "Secret rotation due in 5 days"
- Action: Schedule 2-hour rotation window
- Notification: Check calendar for next rotation date

**Rotation Window:**
- Schedule: Friday afternoon (2-hour window)
- Duration: 2-3 hours total (includes testing + monitoring)
- Preparation: Review all procedures below 1 day before

**Post-Rotation Monitoring:**
- Day 1: Monitor all logs for errors (especially first 24h)
- Day 2-3: Spot-check transaction syncing, tax calculations, uploads

### Heroku Calendar Integration

Store rotation dates in Heroku config for reference:

```bash
# View next rotation dates
heroku config:get SECRET_ROTATION_NEXT_OPENAI
heroku config:get SECRET_ROTATION_NEXT_PLAID
heroku config:get SECRET_ROTATION_NEXT_TAXCLOUD
heroku config:get SECRET_ROTATION_NEXT_AWS
```

Update after each rotation:

```bash
heroku config:set SECRET_ROTATION_NEXT_OPENAI=2026-02-20
```

---

## Pre-Rotation Checklist

Before starting any secret rotation:

- [ ] **Backup Database:** Create manual backup before touching any credentials
  ```bash
  heroku pg:backups:capture --app grayledger-production
  ```

- [ ] **Review Change Log:** Check recent deployments (no in-progress changes)
  ```bash
  heroku releases --app grayledger-production | head -5
  ```

- [ ] **Verify App Health:** Confirm no active alerts or errors
  ```bash
  heroku logs --tail --app grayledger-production | head -20
  ```

- [ ] **Notify Team:** (if applicable) Notify team of scheduled rotation

- [ ] **Documentation:** Review relevant service documentation

---

## Secret 1: OpenAI API Key Rotation

**Service:** OpenAI (ChatGPT/GPT-4o for transaction categorization)
**Frequency:** Every 90 days
**Risk Level:** High (if leaked: unauthorized API charges)
**Time Estimate:** 15 minutes

### Pre-Rotation Steps

1. **Log into OpenAI Dashboard**
   - Go to https://platform.openai.com/api/keys
   - Authenticate with main account credentials

2. **Verify Current Key**
   - Confirm OPENAI_API_KEY is set in Heroku
     ```bash
     heroku config:get OPENAI_API_KEY --app grayledger-production | head -c 20
     ```
   - Should show first 20 chars: `sk-...` (masked)

### Rotation Steps

1. **Create New API Key**
   - In OpenAI dashboard: Click "Create new secret key"
   - Name it: `grayledger-production-2025-11-21` (include date)
   - Copy the new key (appears once, save to secure location)

2. **Test in Development**
   ```bash
   # Set new key locally
   export OPENAI_API_KEY=sk-new...

   # Test API call
   rails runner '
     require "openai"
     client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])
     response = client.chat(
       parameters: {
         model: "gpt-4o-mini",
         messages: [{ role: "user", content: "Test" }]
       }
     )
     puts "SUCCESS: #{response["id"]}"
   '
   ```
   - Expected: No errors, returns OpenAI response ID

3. **Update Heroku Config**
   ```bash
   heroku config:set OPENAI_API_KEY=sk-new... --app grayledger-production
   ```
   - Heroku restarts dynos automatically
   - Deployment takes <30 seconds

4. **Verify Update**
   ```bash
   # Confirm new key is set
   heroku config:get OPENAI_API_KEY --app grayledger-production | head -c 20

   # Check logs for errors
   heroku logs --tail --app grayledger-production | grep -i "openai\|error"
   ```

### Testing (24-Hour Monitoring)

**Immediate Tests (within 1 minute):**
- [ ] App loads without errors: https://grayledger-production.herokuapp.com
- [ ] Check logs: `heroku logs --tail` (no OpenAI auth errors)

**Functional Tests (5-10 minutes):**
- [ ] Create test transaction via UI
- [ ] Verify categorization suggestion works (uses OpenAI API)
- [ ] Check suggestion confidence score displays

**Extended Monitoring (24 hours):**
- [ ] Monitor error logs for "OpenAI" or "authentication" errors
  ```bash
  heroku logs --app grayledger-production --since 1h | grep -i "openai"
  ```
- [ ] Check Papertrail for any rate limit errors
- [ ] Verify transaction volume normal (no blocked categorizations)

### Rollback (If Issues Found)

If new key fails:

```bash
# Revert to old key immediately
heroku config:set OPENAI_API_KEY=sk-old... --app grayledger-production

# Verify revert
heroku logs --tail --app grayledger-production
```

### Post-Rotation Cleanup

After 24 hours of successful monitoring:

1. **Delete Old Key**
   - Go to OpenAI dashboard: https://platform.openai.com/api/keys
   - Find old key (last chars match previous OPENAI_API_KEY)
   - Click "Delete" (cannot be undone)

2. **Update Rotation Schedule**
   ```bash
   heroku config:set SECRET_ROTATION_NEXT_OPENAI=2026-02-20 --app grayledger-production
   ```

3. **Document Rotation**
   - Log entry: "OpenAI key rotated 2025-11-21"
   - Checked: Transaction categorization working
   - Old key: Deleted
   - Next rotation: 2026-02-20

---

## Secret 2: Plaid Secret Rotation

**Service:** Plaid (Bank account linking and transaction sync)
**Frequency:** Every 90 days
**Risk Level:** Critical (if leaked: account access to all linked bank accounts)
**Time Estimate:** 25 minutes

### Pre-Rotation Steps

1. **Verify Current Keys**
   ```bash
   # Check what's in Heroku
   heroku config:get PLAID_CLIENT_ID --app grayledger-production
   heroku config:get PLAID_SECRET --app grayledger-production
   heroku config:get PLAID_ENV --app grayledger-production
   ```

2. **List Connected Bank Accounts**
   - This helps identify test vs production accounts
   - Used later to verify sync continues working

### Rotation Steps

1. **Access Plaid Dashboard**
   - Go to https://dashboard.plaid.com
   - Navigate to Settings → Keys

2. **Generate New Secret**
   - Click "Generate New Secret" button
   - New secret appears immediately
   - Copy new secret (save to secure location)
   - Note: Client ID typically doesn't change

3. **Test New Secret in Sandbox**
   - First, verify sandbox environment works
   - Create temporary test config:
     ```bash
     export PLAID_CLIENT_ID=<your-client-id>
     export PLAID_SECRET=<new-secret>
     export PLAID_ENV=sandbox

     # Test Plaid API call
     rails runner '
       require "plaid"
       config = Plaid::Configuration.new
       config.api_key["clientId"] = ENV["PLAID_CLIENT_ID"]
       config.api_key["secret"] = ENV["PLAID_SECRET"]
       api_client = Plaid::ApiClient.new(config)
       client = Plaid::PlaidApi.new(api_client)

       # Simple institutions endpoint test
       response = client.institutions_get_by_id({
         institution_id: "ins_3",  # Wells Fargo (sandbox)
         country_codes: ["US"]
       })
       puts "SUCCESS: #{response.institution.name}"
     '
     ```
   - Expected: Returns institution details, no auth errors

4. **Update Heroku Config**
   ```bash
   heroku config:set PLAID_SECRET=<new-secret> --app grayledger-production
   ```
   - Heroku restarts dynos automatically

5. **Verify Update**
   ```bash
   heroku config:get PLAID_SECRET --app grayledger-production | head -c 20
   heroku logs --tail --app grayledger-production | grep -i "plaid"
   ```

### Testing (48-Hour Monitoring)

**Immediate Tests (5 minutes):**
- [ ] App loads without errors
- [ ] Bank connection screen renders (no auth errors)
- [ ] Check logs for "Plaid" auth errors

**Functional Tests (1 hour):**
- [ ] Link a test bank account (sandbox)
- [ ] Verify transactions sync from linked account
- [ ] Check transaction counts match Plaid dashboard
- [ ] Test webhook notification (new transaction arrives)

**Extended Monitoring (48 hours):**
- [ ] Monitor all bank syncs (1-2 accounts if production)
  ```bash
  heroku logs --app grayledger-production --since 48h | grep -i "plaid"
  ```
- [ ] Verify no rate limit errors
- [ ] Check webhook deliveries (Plaid dashboard → Webhooks)
- [ ] Spot-check transaction accuracy

### Rollback (If Issues Found)

If new secret causes sync failures:

```bash
# Revert to old secret
heroku config:set PLAID_SECRET=<old-secret> --app grayledger-production

# Verify revert
heroku logs --tail --app grayledger-production

# Re-trigger sync from Plaid dashboard if needed
```

### Post-Rotation Cleanup

After 48 hours of successful monitoring:

1. **Deactivate Old Secret**
   - Go to Plaid dashboard: Settings → Keys
   - Find old secret (last chars match previous PLAID_SECRET)
   - Click "Deactivate" (NOT delete yet, for recovery if needed)

2. **Wait 7 Days, Then Delete**
   - After 7 days: Return to dashboard
   - Click "Delete" on old secret (cannot be undone)

3. **Update Rotation Schedule**
   ```bash
   heroku config:set SECRET_ROTATION_NEXT_PLAID=2026-02-20 --app grayledger-production
   ```

4. **Document Rotation**
   - Log entry: "Plaid secret rotated 2025-11-21"
   - Tested: Bank sync working, 2 accounts verified
   - Old secret: Deactivated
   - Next rotation: 2026-02-20

---

## Secret 3: TaxCloud API Key Rotation

**Service:** TaxCloud (Sales tax rate calculation)
**Frequency:** Every 90 days
**Risk Level:** Medium (if leaked: unauthorized tax calculation requests, API charges)
**Time Estimate:** 20 minutes (includes support email wait)

### Pre-Rotation Steps

1. **Verify Current Key**
   ```bash
   heroku config:get TAXCLOUD_API_LOGIN --app grayledger-production
   heroku config:get TAXCLOUD_API_KEY --app grayledger-production
   ```

2. **Prepare Support Request**
   - TaxCloud doesn't have self-service key rotation
   - Must contact support: support@taxcloud.com

### Rotation Steps

1. **Request Key Rotation from TaxCloud Support**
   - Send email to: support@taxcloud.com
   - Subject: "API Key Rotation Request - grayledger account"
   - Body:
     ```
     Hello TaxCloud Support,

     I need to rotate my API credentials for security purposes (90-day rotation policy).

     Current API Login: <current-api-login>
     Account Name: grayledger (production)
     Request: Please generate new API key for this account

     Timeline: Can implement new key within 24 hours of receipt.

     Thank you,
     [Your Name]
     ```

2. **Wait for Support Response**
   - Typical response time: 2-4 business hours
   - Support will provide new API key via email
   - Save new key to secure location

3. **Test New Key in Sandbox**
   ```bash
   export TAXCLOUD_API_LOGIN=<your-api-login>
   export TAXCLOUD_API_KEY=<new-api-key>

   # Test TaxCloud API call
   rails runner '
     require "tax_cloud"

     # Configure with new key
     TaxCloud.configure do |config|
       config.api_login_id = ENV["TAXCLOUD_API_LOGIN"]
       config.api_key = ENV["TAXCLOUD_API_KEY"]
     end

     # Simple lookup test
     request = TaxCloud::Request.new(
       cart_id: "test-#{Time.now.to_i}",
       cartItems: [
         TaxCloud::CartItem.new(
           cartItemIndex: 0,
           itemId: "test-item",
           description: "Test Item",
           quantity: 1,
           price: 100.00,
           taxCode: "00000"
         )
       ],
       deliveryAddresses: [
         TaxCloud::Address.new(
           address1: "123 Main St",
           city: "New York",
           state: "NY",
           zip5: "10001"
         )
       ]
     )

     response = TaxCloud::Lookup.new(request).request
     puts "SUCCESS: Tax rate lookup returned"
   '
   ```
   - Expected: No auth errors, returns tax rates

4. **Update Heroku Config**
   ```bash
   heroku config:set TAXCLOUD_API_KEY=<new-api-key> --app grayledger-production
   # Note: API_LOGIN typically doesn't change, but update if support indicates
   ```
   - Heroku restarts dynos automatically

5. **Verify Update**
   ```bash
   heroku config:get TAXCLOUD_API_KEY --app grayledger-production | head -c 20
   heroku logs --tail --app grayledger-production | grep -i "taxcloud"
   ```

### Testing (24-Hour Monitoring)

**Immediate Tests (5 minutes):**
- [ ] App loads without errors
- [ ] Create test invoice with tax-applicable items
- [ ] Check logs for "TaxCloud" auth errors

**Functional Tests (30 minutes):**
- [ ] Create invoice with taxable items (all states)
- [ ] Verify tax rate calculation matches TaxCloud
- [ ] Check tax rounded correctly (2 decimals)
- [ ] Create order in different state (verify rate change)

**Extended Monitoring (24 hours):**
- [ ] Monitor all invoice tax calculations
  ```bash
  heroku logs --app grayledger-production --since 24h | grep -i "taxcloud"
  ```
- [ ] Verify no rate limit errors
- [ ] Check invoice counts and tax amounts in dashboard
- [ ] Spot-check 2-3 invoices against manual rates

### Rollback (If Issues Found)

If new key causes tax calculation failures:

```bash
# Revert to old key
heroku config:set TAXCLOUD_API_KEY=<old-api-key> --app grayledger-production

# Verify revert
heroku logs --tail --app grayledger-production

# Email support: "Please reactivate old key temporarily"
```

### Post-Rotation Cleanup

After 24 hours of successful monitoring:

1. **Confirm Deactivation**
   - Email support: "Please deactivate old API key <old-key> for account grayledger"
   - TaxCloud will confirm deactivation

2. **Update Rotation Schedule**
   ```bash
   heroku config:set SECRET_ROTATION_NEXT_TAXCLOUD=2026-02-20 --app grayledger-production
   ```

3. **Document Rotation**
   - Log entry: "TaxCloud API key rotated 2025-11-21"
   - Tested: Invoice tax calculations, 5 states verified
   - Old key: Deactivated by support
   - Next rotation: 2026-02-20

---

## Secret 4: AWS IAM Keys Rotation

**Service:** AWS (S3 file uploads, receipts, documents)
**Frequency:** Every 90 days
**Risk Level:** High (if leaked: unauthorized S3 uploads, potential data exposure)
**Time Estimate:** 20 minutes

### Pre-Rotation Steps

1. **Verify Current Keys**
   ```bash
   heroku config:get AWS_ACCESS_KEY_ID --app grayledger-production | head -c 20
   heroku config:get AWS_SECRET_ACCESS_KEY --app grayledger-production | head -c 20
   ```

2. **Access AWS Console**
   - Go to AWS IAM: https://console.aws.amazon.com/iam
   - Navigate to Users → Find `grayledger-s3-upload` user

### Rotation Steps

1. **Create New Access Key Pair**
   - In AWS IAM: Users → `grayledger-s3-upload` → Security credentials
   - Click "Create access key"
   - Choose "Application running outside AWS" (for Heroku)
   - Note: Display new key details (access key ID + secret access key)
   - Download key file as backup (CSV)
   - **Important:** Save both parts to secure location (appears once)

2. **Test Locally with New Keys**
   ```bash
   # Set new AWS credentials locally
   export AWS_ACCESS_KEY_ID=AKIA...
   export AWS_SECRET_ACCESS_KEY=new-secret-key
   export AWS_REGION=us-east-1
   export AWS_S3_BUCKET=grayledger-production

   # Test S3 upload
   rails runner '
     require "aws-sdk-s3"

     client = Aws::S3::Client.new(
       region: ENV["AWS_REGION"],
       credentials: Aws::Credentials.new(
         ENV["AWS_ACCESS_KEY_ID"],
         ENV["AWS_SECRET_ACCESS_KEY"]
       )
     )

     # Simple put object test
     response = client.put_object(
       bucket: ENV["AWS_S3_BUCKET"],
       key: "test-upload-#{Time.now.to_i}.txt",
       body: "Test upload from IAM key rotation"
     )

     puts "SUCCESS: Uploaded to #{response.etag}"
   '
   ```
   - Expected: File appears in S3 bucket, no auth errors

3. **Update Heroku Config**
   ```bash
   heroku config:set \
     AWS_ACCESS_KEY_ID=AKIA... \
     AWS_SECRET_ACCESS_KEY=new-secret-key \
     --app grayledger-production
   ```
   - Heroku restarts dynos automatically

4. **Verify Update**
   ```bash
   heroku config:get AWS_ACCESS_KEY_ID --app grayledger-production | head -c 20
   heroku logs --tail --app grayledger-production | grep -i "aws\|s3"
   ```

### Testing (24-Hour Monitoring)

**Immediate Tests (5 minutes):**
- [ ] App loads without errors
- [ ] Check logs for "AWS" or "S3" auth errors

**Functional Tests (15 minutes):**
- [ ] Upload test receipt via UI
- [ ] Verify receipt appears in S3 bucket
- [ ] Verify file size and permissions correct
- [ ] Download receipt and verify content intact

**Extended Monitoring (24 hours):**
- [ ] Monitor all receipt uploads
  ```bash
  heroku logs --app grayledger-production --since 24h | grep -i "s3"
  ```
- [ ] Verify no permission errors
- [ ] Check S3 bucket storage increasing normally
- [ ] Spot-check 2-3 uploaded files in S3 console

### Rollback (If Issues Found)

If new keys cause upload failures:

```bash
# Revert to old keys
heroku config:set \
  AWS_ACCESS_KEY_ID=AKIA-old... \
  AWS_SECRET_ACCESS_KEY=old-secret-key \
  --app grayledger-production

# Verify revert
heroku logs --tail --app grayledger-production
```

### Post-Rotation Cleanup

After 24 hours of successful monitoring:

1. **Deactivate Old Access Key**
   - In AWS IAM: Users → `grayledger-s3-upload` → Security credentials
   - Find old access key (first 4 chars match previous AWS_ACCESS_KEY_ID)
   - Click "Deactivate" (NOT delete yet)
   - Status should show "Inactive"

2. **Wait 7 Days (Security Cooling-Off Period)**
   - Keep deactivated key for 7 days in case emergency revert needed
   - Set calendar reminder: "Delete old AWS key in 7 days"

3. **Delete Old Access Key (Day 7)**
   - Return to AWS IAM: Users → `grayledger-s3-upload` → Security credentials
   - Click "Delete" on deactivated key (cannot be undone)
   - Confirm deletion

4. **Update Rotation Schedule**
   ```bash
   heroku config:set SECRET_ROTATION_NEXT_AWS=2026-02-20 --app grayledger-production
   ```

5. **Document Rotation**
   - Log entry: "AWS IAM keys rotated 2025-11-21"
   - Tested: Receipt upload working, 3 files verified
   - Old key: Deactivated, will delete 2025-11-28
   - Next rotation: 2026-02-20

---

## Post-Rotation Verification Checklist

After rotating all secrets, verify everything still works:

- [ ] **Application Health**
  ```bash
  heroku logs --tail --app grayledger-production | head -20
  ```
  - No errors in logs
  - App responding to requests

- [ ] **OpenAI Categorization**
  - Create test transaction
  - Verify AI suggestion appears
  - Check suggestion confidence score

- [ ] **Plaid Bank Sync**
  - Verify recent transactions from linked accounts
  - Check sync status for all accounts
  - Confirm no "auth error" alerts

- [ ] **TaxCloud Tax Rates**
  - Create invoice with tax items
  - Verify tax rate calculation correct
  - Check multiple states if applicable

- [ ] **AWS S3 Uploads**
  - Upload test receipt
  - Verify appears in S3 bucket
  - Confirm file accessible

- [ ] **Overall Application**
  - Login works
  - Dashboard loads
  - No 500 errors in logs
  - Monitoring alerts quiet

---

## Emergency Secret Rotation

If a secret is **suspected compromised** (leaked in logs, exposed in code, etc.):

1. **Immediate Action (Now)**
   ```bash
   # Revoke compromised secret immediately
   # Example: suspected OpenAI key leaked
   heroku config:set OPENAI_API_KEY=<emergency-backup-key> --app grayledger-production
   ```

2. **Investigation (Next 1 hour)**
   - Check if secret appears in code: `git log -p | grep -i "sk-"`
   - Check if secret appears in logs: `heroku logs --since 1h | grep -i secret`
   - If found: Create git history clean-up commit (BFG Repo-Cleaner)

3. **Service-Specific Actions**
   - **OpenAI:** Immediately delete leaked key in OpenAI dashboard
   - **Plaid:** Immediately deactivate leaked secret in Plaid dashboard
   - **TaxCloud:** Email support immediately for emergency deactivation
   - **AWS:** Immediately deactivate leaked access key in IAM console

4. **Generate New Secrets** (Don't wait for 90-day rotation)
   - Follow normal rotation procedures above for each compromised secret
   - Use same procedures, but skip monitoring delays if emergency

5. **Notification**
   - If data breach risk: notify customers
   - Document incident in post-mortem

---

## Secret Storage Best Practices

### What NOT to Do

- ❌ Never commit secrets to git (use `.gitignore`)
- ❌ Never log secrets (filter them: `config.filter_parameters`)
- ❌ Never share secrets in Slack/email
- ❌ Never display secrets in browser console
- ❌ Never reuse old keys (create fresh ones)

### What TO Do

- ✅ Store secrets in Heroku config only
- ✅ Use AWS IAM roles (not access keys) when possible
- ✅ Rotate every 90 days (calendar reminders)
- ✅ Document each rotation with date and tested features
- ✅ Keep old keys deactivated for 7 days before deletion
- ✅ Monitor logs for auth errors after rotation

---

## Related Documentation

- [01.002 Heroku Deployment ADR](../adrs/01.foundation/01.002.heroku-postgres-pgvector.md) - Secret rotation details and context
- [Disaster Recovery Runbook](./disaster-recovery.md) - Database and deployment recovery
- [Heroku Setup Guide](../deployment/heroku-setup.md) - Initial Heroku configuration

---

## Support & Escalation

### If Rotation Fails

**Before reverting, try:**
1. Check logs: `heroku logs --tail --app grayledger-production`
2. Verify key syntax: Ensure no extra spaces or invalid characters
3. Test locally first: Export key to environment and test before updating Heroku

**If still failing, escalate:**
- **OpenAI:** Support @ openai.com
- **Plaid:** Support @ plaid.com
- **TaxCloud:** support@taxcloud.com
- **AWS:** AWS Support (may require paid plan)

### Troubleshooting by Symptom

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| 401 Unauthorized in logs | Wrong API key | Verify key copied correctly (no spaces) |
| Rate limit errors | Old key still being used somewhere | Verify Heroku config set correctly: `heroku config` |
| Service works locally, fails in prod | New key missing in Heroku | Run: `heroku config:set KEY=value` |
| Old key still working after rotation | Service cached old value | Restart dynos: `heroku restart` |
| Upload fails, auth error in S3 | AWS key permissions changed | Verify IAM policy still attached to user |

---

**Last Updated:** 2025-11-21
**Status:** Ready for implementation
**Next Review:** 2026-02-20 (90-day rotation window)
