# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Active Feature

**🚧 IN DEVELOPMENT 🚧**

- **Feature:** Rails 8 Minimal Stack (ADR 01.001)
- **Branch:** `feature/adr-01.001-rails-8-minimal-stack`
- **PRD:** [dev/prd-from-adr-01.001.md](dev/prd-from-adr-01.001.md)
- **Tasks:** [dev/TASKS.md](dev/TASKS.md)
- **Status:** Wave 1 - Foundation (0/25 tasks complete)
- **Next:** TASK-1.1 - Initialize Rails 8 Application

## Project Overview

This is a **Rails 8 AI-driven accounting application** designed to replace traditional bookkeeping for US small businesses. Architecture decisions are documented in `docs/adrs/` and implementation follows these decisions exactly.

The product vision: AI handles 100% of bookkeeping (bank feeds, receipt OCR, categorization, tax compliance) while keeping one human in the loop for anomalies.

## Repository Structure

```
grayledger/
├── app/                    # Rails application code (to be created)
├── config/                 # Rails configuration (to be created)
├── db/                     # Database migrations (to be created)
├── test/                   # Minitest test suite (to be created)
├── docs/adrs/              # Architecture Decision Records
│   ├── 01.foundation/      # Rails 8 stack, deployment, database
│   ├── 02.auth/           # Passwordless OTP, Pundit authorization
│   ├── 03.tenancy/        # Row-level company tenancy
│   ├── 04.ledger/         # Double-entry bookkeeping core
│   ├── 05.banks/          # Plaid integration
│   ├── 06.ai/             # AI strategy, pgvector, anomaly queue
│   ├── 07.invoicing/      # AI-first invoicing and AR
│   ├── 08.documents/      # S3 + GPT-4o Vision
│   ├── 09.assets-loans/   # Auto-depreciation/amortization
│   ├── 10.tax/            # TaxCloud sales tax
│   ├── 11.cogs/           # Percentage-based COGS
│   ├── 12.imports/        # No user-facing middleware
│   ├── 13.reports-1099/   # 1099 and tax package exports
│   └── 14.platform/       # Superuser god-mode
├── dev/                    # Development planning docs
│   ├── prd-from-adr-*.md  # Product requirements from ADRs
│   └── TASKS.md           # Current feature task breakdown
└── CLAUDE.md              # This file

All ADRs live in `docs/adrs/` organized by domain (see structure above).

## Core Architectural Principles

### 1. Minimal Stack (ADR 01.001)
- **Rails 8** with Hotwire (Turbo 8 + Stimulus 3) only—no React/Vue/SPA
- **Zero build step**: Importmaps + TailwindCSS (via gems, no Node.js)
- **Solid Queue** for background jobs (no Redis/Sidekiq)
- **PostgreSQL + pgvector** for both relational data and AI embeddings
- **Pundit** for authorization, **Pagy** for pagination, **money-rails** for currency
- **Active Storage + S3** for file uploads (direct upload pattern)
- Explicitly forbidden: Devise, factory_bot, RSpec, Sidekiq, view_component

### 2. Custom Double-Entry Ledger (ADR 04.001, 04.002, 04.003)
**Never use a third-party ledger gem.** Core models are built from scratch:

```ruby
Entry (description, posted_at)
  ├─ validates: must_balance (line_items.sum(:amount_cents) == 0)
  └─ has_many LineItems

LineItem (amount_cents, account_id, entry_id)
  └─ amount_cents signed: positive = debit, negative = credit

Account (code, name, parent_id, account_type)
  └─ 30 immutable parent accounts (seeded, locked forever)
  └─ unlimited user sub-accounts
```

**Critical rules:**
- Every entry must balance to zero (database constraint)
- Account balances are **never stored**—always calculated via `SUM(line_items.amount_cents)` with indexes on `[account_id, posted_at]`
- 30 parent accounts map exactly to IRS Schedule C/1065/1120-S lines (tax-ready by design)
- All writes are atomic inside `Entry.transaction { }` blocks

### 3. Row-Level Tenancy (ADR 03.001)
- Every tenant-scoped model includes `BelongsToCompany` concern
- `belongs_to :company` + `default_scope { where(company: Current.company) }`
- Request lifecycle: `ApplicationController#require_company!` sets `Current.company`
- No gems (no acts_as_tenant, no apartment)—pure row-level foreign keys
- Platform god-mode can override `Current.company` for emergency support

### 4. AI-First with Human Loop (ADR 06.003, 08.001)
**AI categorizes transactions, OCRs receipts, but humans approve anomalies.**

- **Confidence threshold**: ≥95% auto-posts, <95% goes to Anomaly Queue
- **pgvector memory**: Every human correction creates an embedding, future identical transactions hit 99.9% confidence
- **GPT-4o Vision**: Receipt uploads → JSON extraction (vendor, date, amount, suggested accounts)
- All AI decisions include confidence scores and explanations shown to user

### 5. No User-Facing Middleware (ADR 12.001)
**Religious commitment:** Users never create accounts with third-party services.

- ✅ **Allowed (invisible):** Plaid, TaxCloud, OpenAI/Anthropic, S3, Stripe webhooks
- ❌ **Forbidden:** Forcing users to use Expensify, A2X, TaxJar dashboard, Zapier, Hubdoc
- Fallback: CSV upload for edge cases

### 6. Platform God-Mode (ADR 14.001)
Emergency support backdoor for platform staff:

- Any user with email ending in `@grayledger.io` (or hardcoded allowlist) gets superuser powers
- Can log in as any user via `/god/login_as/:user_id`
- Can override `Current.company`, view/edit any record, force-post entries
- All actions logged permanently in `platform_audit_logs` table

## Key Domain Patterns

### Authentication (ADR 02.001)
- **Passwordless OTP via email** (Rails 8 native, no Devise)
- 6-digit hashed tokens stored in `LoginToken` model, 10-minute expiry
- Magic link + copy-paste flow

### Bank Feeds (ADR 05.001)
- **Plaid exclusive** (official `plaid` gem)
- Daily sync + webhooks for real-time transactions
- `BankTransaction` model → AI processes → creates `Entry` or sends to Anomaly Queue

### Receipts & Documents (ADR 08.001)
- S3 direct upload (Active Storage) → `DocumentProcessorJob` (Solid Queue)
- GPT-4o Vision extracts structured JSON → creates balanced `Entry` with attachment
- Supports receipts, invoices, Amazon settlements, loan docs

### Sales Tax (ADR 10.001)
- **TaxCloud server-side only** ($19/mo flat, covers all transactions)
- Rooftop-accurate rates across 13,000+ jurisdictions
- Rate stored on invoice line items for audit trail
- Fallback: `customer.default_tax_rate` if API down (flagged for review)

### COGS Recognition (ADR 11.001)
- Default method: **percentage of gross revenue** (user-set once)
- Monthly button posts single entry: `Debit 5000 COGS / Credit 1300 Inventory`
- IRS-approved for <$30M gross receipts (consistent method)
- Optional override: flat dollar amount

## Working with ADRs

### Reading ADRs
All ADRs follow the same structure:
- **Status:** accepted/rejected/superseded
- **Date:** YYYY-MM-DD
- **Context:** Problem being solved
- **Decision:** Exact technical approach with code examples
- **Consequences:** Trade-offs and outcomes

### Creating New ADRs
When adding architecture decisions:
1. Use next sequential number in the appropriate domain folder
2. Format: `XX.YYY.short-kebab-description.md` (e.g., `04.004.void-entry-pattern.md`)
3. Include runnable code examples in fenced Ruby/SQL blocks
4. Explain the "why" and trade-offs, not just the "what"

### Modifying ADRs
- Never edit accepted ADRs—create a new one that supersedes it
- Mark old ADR as `Status: superseded by XX.YYY`

## Philosophy & Constraints

1. **Solo-maintainable forever**: Any Rails dev in 2025–2035 can understand every line
2. **Boring technology**: Prefer Rails conventions over clever abstractions
3. **No gem rot**: Minimal dependencies, own the critical path (ledger, tenancy)
4. **AI is a tool, not magic**: Always show confidence, always allow human override
5. **Tax compliance first**: Perfect books for IRS filing is the core promise
6. **Zero middleware lock-in**: Product must work standalone without requiring users to use third-party dashboards

## Development Workflow

### Feature Implementation Process
1. Read ADR thoroughly
2. Create feature branch: `feature/adr-XX.XXX-description`
3. Generate PRD from ADR: `dev/prd-from-adr-XX.XXX.md`
4. Create task breakdown: `dev/TASKS.md` with dependency waves
5. Update `CLAUDE.md` with active feature
6. Implement tasks wave-by-wave
7. Run full test suite (100% pass required)
8. Create PR and merge to main

### Checkpoint System
After completing each wave of tasks:
- Update `dev/TASKS.md` with completed tasks
- Commit work with descriptive message
- Run tests to validate
- User says "next?" to proceed to next wave

This ensures incremental progress with frequent validation points.
