# Caching Patterns & Performance Optimization

## Overview

This document describes the caching strategy for GrayLedger, targeting sub-200ms response times for all user-facing operations. We use Rails' built-in caching (Solid Cache in production) with a service-based approach.

## Caching Architecture

### Cache Stores

**Development:**
- MemoryStore (in-process, single-server only)
- Toggle with `rails dev:cache`

**Test:**
- MemoryStore (isolated per test)
- Automatically cleared between tests

**Production:**
- Solid Cache (database-backed, no Redis required)
- Configured in `config/environments/production.rb`
- Survives restarts, works across multiple servers

### CacheService API

The `CacheService` class provides a consistent interface for all caching operations:

```ruby
class CacheService
  # Fetch with caching (returns cached or executes block)
  def self.fetch_cached(key, expires_in: 1.hour, force_miss: false, &block)

  # Generate nested cache keys
  def self.nested_key(namespace, segments = [])
    # => "namespace:segment1:segment2:..."
  end

  # Warm cache with pre-computed values
  def self.warm_cache(keys_with_blocks, expires_in: 1.hour)

  # Delete cache entries
  def self.delete(key)
  def self.delete_pattern(pattern)
  def self.clear_all

  # Direct access
  def self.read(key)
  def self.write(key, value, expires_in: 1.hour)
  def self.exists?(key)
end
```

## Caching Patterns

### Pattern 1: Simple Object Caching

Cache expensive database queries or calculations:

```ruby
# app/controllers/users_controller.rb
def show
  @user = CacheService.fetch_cached("user:#{params[:id]}", expires_in: 1.hour) do
    User.find(params[:id])
  end
end
```

**TTL Guidelines:**
- User profiles: 1 hour
- Post listings: 30 minutes
- Search results: 15 minutes
- Real-time data: 1-5 minutes

### Pattern 2: Nested Cache Keys

Use hierarchical keys for related data:

```ruby
# Generate consistent nested keys
cache_key = CacheService.nested_key("ledger", [company_id, date, account_id])

result = CacheService.fetch_cached(cache_key, expires_in: 4.hours) do
  calculate_account_balance(company_id, date, account_id)
end
```

**Key structure:**
```
ledger:123:2025-01-15:5000
│       │   │          │
│       │   │          └── Account ID
│       │   └───────────── Date (YYYY-MM-DD)
│       └───────────────── Company ID
└────────────────────────── Namespace
```

### Pattern 3: Russian Doll Caching

Cache nested associations to avoid recalculating parents:

```ruby
# app/models/company.rb
class Company < ApplicationRecord
  has_many :accounts
  
  def cached_balance
    CacheService.fetch_cached(
      CacheService.nested_key("company", [id, "balance"]),
      expires_in: 1.hour
    ) do
      accounts.sum(:balance_cents)
    end
  end
end

# app/models/account.rb
class Account < ApplicationRecord
  belongs_to :company
  
  after_save :invalidate_company_cache
  
  def invalidate_company_cache
    CacheService.delete(
      CacheService.nested_key("company", [company_id, "balance"])
    )
  end
end
```

When an account changes, it automatically invalidates the parent company's cache.

### Pattern 4: Cache Warming

Pre-load frequently accessed data during application startup:

```ruby
# config/initializers/cache_warming.rb
if Rails.env.production?
  Rails.application.config.after_initialize do
    # Warm cache with static data
    CacheService.warm_cache(
      "system:currencies" => -> { Currency.all.to_a },
      "system:countries" => -> { Country.all.to_a },
      "system:tax_rates" => -> { TaxRate.defaults.to_a }
    )
  end
end
```

### Pattern 5: Conditional Caching

Skip cache for certain conditions:

```ruby
def load_entries
  # Don't cache if filtering by specific date range
  force_miss = @date_from.present? && @date_to.present?
  
  CacheService.fetch_cached(
    "entries:#{company_id}:all",
    expires_in: 30.minutes,
    force_miss: force_miss
  ) do
    Entry.where(company: Current.company).to_a
  end
end
```

### Pattern 6: Fragment Caching in Views

Use Rails' built-in fragment caching for expensive view partials:

```erb
<!-- app/views/dashboards/summary.html.erb -->
<% cache(CacheService.nested_key("dashboard", [Current.company.id, "summary"]), expires_in: 30.minutes) do %>
  <div class="dashboard-summary">
    <%= render "summary_stats" %>
    <%= render "recent_entries" %>
  </div>
<% end %>
```

**Note:** Fragment cache automatically invalidates when the associated record updates if you use `cache` in partials:

```erb
<!-- app/views/entries/_entry.html.erb -->
<% cache entry, expires_in: 1.hour do %>
  <div class="entry">
    <p><%= entry.description %></p>
    <p><%= entry.amount %></p>
  </div>
<% end %>
```

## Cache Invalidation

### Automatic Invalidation

Delete cache when data changes:

```ruby
# app/models/entry.rb
class Entry < ApplicationRecord
  after_save :invalidate_cache
  after_destroy :invalidate_cache
  
  def invalidate_cache
    # Invalidate related caches
    [
      CacheService.nested_key("ledger", [company_id, posted_date.to_date]),
      CacheService.nested_key("account", [account_id, posted_date.to_date])
    ].each { |key| CacheService.delete(key) }
  end
end
```

### Pattern-Based Invalidation

For related keys with wildcard patterns (when using Redis-compatible stores):

```ruby
# Only works with Redis; no-op with memory store
CacheService.delete_pattern("user:#{user_id}:*")
```

### Manual Cache Clearing

For administrative operations:

```ruby
# app/controllers/admin/cache_controller.rb
def clear
  CacheService.clear_all
  redirect_to admin_dashboard_path, notice: "Cache cleared"
end
```

## Performance Benchmarks

### Running Benchmarks

Run the cache performance benchmark suite:

```bash
# Run cache benchmarks
rails benchmark:cache

# Save results to file
SAVE_RESULTS=1 rails benchmark:cache

# Run all benchmarks
rails benchmark:all
```

### Benchmark Targets

| Metric | Target | Acceptable | Notes |
|--------|--------|-----------|-------|
| Cache hit time (per request) | < 1ms | < 5ms | In-memory read |
| Cache miss time (per request) | < 10ms | < 50ms | With block execution |
| Nested key generation (per key) | < 10µs | < 100µs | String concatenation |
| Warm cache (per key) | < 1ms | < 10ms | Batch pre-load |
| Delete operation (per key) | < 1ms | < 5ms | Single key removal |
| Average response time | < 50ms | < 200ms | Including cache lookup |
| P95 response time | < 100ms | < 200ms | 95th percentile |
| P99 response time | < 150ms | < 300ms | 99th percentile |

### Sample Results (MemoryStore - Development)

```
=== Cache Hit vs Miss Performance ===
Cache Hit (100 reads):        4.18ms (0.0418ms per read)
Cache Miss (100 fetches):     7.80ms (0.0780ms per fetch)
Speedup: 1.87x

=== Nested Cache Key Generation ===
Total time (1000 iterations):  2.69ms
Average per iteration:         2.69µs

=== Cache Warm-Up Performance ===
Warming 10 keys: 1.25ms
Average per key: 0.13ms

=== Cache Delete Performance ===
Deleting 100 keys: 3.11ms
Average per delete: 0.031ms

=== Complex Object Caching ===
Reading complex object 100 times: 23.2ms
Average per read: 0.232ms

=== Sub-200ms Response Time Target ===
Average response time: 0.12ms
Min response time: 0.08ms
Max response time: 0.22ms
Requests under 200ms: 100%
```

**Key Observations:**
- All metrics well under targets
- Cache hits are ~2x faster than misses (expected with lightweight operations)
- Nested key generation is extremely fast (2.69µs)
- Complex object handling is efficient (0.232ms per read)
- Sub-200ms target is easily met (100% of requests)

## Interpreting Results

### Cache Hit Performance
- **< 1ms:** Excellent (memory store)
- **< 10ms:** Good (database-backed)
- **> 50ms:** Investigate cache store or network latency

### Cache Miss Performance
- Dominated by block execution time
- Should be 10-20x slower than cache hit
- If only 2-3x slower: block is too fast to cache effectively

### Key Generation Performance
- Should always be < 100µs
- String concatenation overhead is negligible
- If slower: check if using expensive methods in segments

### Response Time Targets
- **Average < 50ms:** Target for typical operations
- **P95 < 200ms:** Accept occasional slower requests
- **P99 < 300ms:** Emergency fallback threshold

### Identifying Bottlenecks

If benchmarks show poor performance:

1. **Slow cache hits (> 10ms):**
   - Check database-backed cache (Solid Cache) query performance
   - Consider reducing object size
   - Verify indices exist on cache tables

2. **Slow cache misses (> 100ms):**
   - Profile the block execution
   - Check for N+1 queries
   - Consider breaking cache into smaller pieces

3. **Unbalanced speedup (< 5x):**
   - Block is too fast to cache effectively
   - Consider increasing cache TTL instead
   - Combine multiple small caches into one

## Best Practices

### Do
- ✓ Cache expensive database queries
- ✓ Cache expensive calculations
- ✓ Use nested keys for related data
- ✓ Invalidate cache on data changes
- ✓ Set appropriate TTLs per data type
- ✓ Monitor cache hit rates in production
- ✓ Use warm-up for static data

### Don't
- ✗ Cache user input or PII
- ✗ Cache frequently changing data (cache miss rate > 50%)
- ✗ Forget to invalidate cache on updates
- ✗ Use cache for authentication/authorization (use sessions)
- ✗ Cache large objects (> 1MB) without compression
- ✗ Share cache between unrelated features

## Configuration

### Development

Enable caching:
```bash
rails dev:cache
```

This creates `tmp/caching-dev.txt`. Delete to disable.

### Production

Solid Cache is configured automatically in `config/environments/production.rb`:

```ruby
config.cache_store = :solid_cache_store
```

**Monitoring:**
```ruby
# Check cache stats
Rails.cache.stats

# Check database size
SolidCache::Entry.count
SolidCache::Entry.size_in_mb
```

**Maintenance:**
```bash
# Clear old entries (older than TTL)
rails solid_cache:prune

# Vacuum cache table
rails solid_cache:vacuum
```

## Troubleshooting

### Cache Hits Not Working

```ruby
# Check if key exists
CacheService.exists?("user:123")

# Read raw value
CacheService.read("user:123")

# Check Rails.cache type
Rails.cache.class.name
```

### Memory Leaks with Cache

Monitor Solid Cache table size:

```sql
SELECT COUNT(*), SUM(octet_length(value::text)) 
FROM solid_cache_entries;
```

Set shorter TTLs or add automatic cleanup:

```ruby
# app/jobs/cache_cleanup_job.rb
class CacheCleanupJob < ApplicationJob
  def perform
    SolidCache::Entry.where("expires_at < ?", Time.current).delete_all
  end
end
```

### Cache Invalidation Issues

Verify invalidation is being called:

```ruby
class Entry < ApplicationRecord
  after_save :invalidate_cache
  
  def invalidate_cache
    key = CacheService.nested_key("entry", [id])
    Rails.logger.info "Invalidating cache: #{key}"
    CacheService.delete(key)
  end
end
```

Check logs for invalidation messages.

## References

- [Rails Caching Guide](https://guides.rubyonrails.org/caching_with_rails.html)
- [Solid Cache](https://github.com/rails/solid_cache)
- [CacheService Implementation](../app/services/cache_service.rb)
- [Benchmark Tests](../test/performance/cache_performance_test.rb)
