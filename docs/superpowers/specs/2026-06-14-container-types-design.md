# Container Types Design

Date: 2026-06-14

## Motivation

Separate the current monolithic `Bucket` + delegated_type hierarchy into explicit domain types. Each container concept becomes its own model with a dedicated table. Bucket stays as a thin metadata shell for cross-cutting ownership, identity, and pinning — but hierarchy moves to domain-level FKs.

## Current State

- `Bucket` holds everything: metadata (name, colour, icon, pinning) + hierarchy (`bucket_parent_id`) + delegated behavior (`bucketable_type`/`bucketable_id`)
- `Collection` is a thin delegated type (just `include Bucketable`)
- `TimeSpread` is a delegated type with period logic
- "Future Log" is a root Collection bucket with hardcoded name `'Future Log'`
- "Year Goals" is a child Collection bucket nested under Future Log
- Monthly logs are TimeSpread buckets nested under Future Log via `bucket_parent_id`

## Target State

### New tables

```ruby
create_table :collections            # id, user_id, timestamps
create_table :bundles                # id, collection_id, user_id, timestamps
create_table :future_buckets         # id, user_id, timestamps
create_table :monthly_buckets        # id, future_bucket_id nullable, user_id, period_from, period_to, timestamps
```

### Bucket stays (with changes)

```ruby
# Drop: bucket_parent_id, children_buckets association
# Keep: delegated_type covering Collection, Bundle, FutureBucket, MonthlyBucket
# Keep: name, colour, icon, user_id, pinned
```

### Models

```ruby
class Collection < ApplicationRecord
  include Bucketable
  has_many :bundles, dependent: :destroy
end

class Bundle < ApplicationRecord
  include Bucketable
  belongs_to :collection
end

class FutureBucket < ApplicationRecord
  include Bucketable
  has_many :monthly_buckets, dependent: :nullify
end

class MonthlyBucket < ApplicationRecord
  include Bucketable, Periodable
  belongs_to :future_bucket, optional: true
end
```

### Bullet unchanged

`Bullet` keeps `bucket_id` pointing to the container's Bucket. Querying all bullets in a Collection including its Bundles:

```ruby
bucket_ids = [@collection.bucket.id] + @collection.bundles.map { |b| b.bucket.id }
Bullet.where(bucket_id: bucket_ids)
```

### Hierarchy moved to domain FKs

```
Collection ── has_many :bundles ── Bundle
FutureBucket ── has_many :monthly_buckets ── MonthlyBucket
```

- `bucket_parent_id` column on `buckets` is dropped
- `Bundle` has `collection_id`, `MonthlyBucket` has `future_bucket_id`
- MonthlyBucket can exist without a FutureBucket (`optional: true`)
- Nesting is flat (no nested bundles)

### Year Goals

Year Goals are not a separate container. They exist as bullets within FutureBucket, optionally tagged with a project. The old "Year Goals" Collection bucket's bullets are migrated to FutureBucket's bucket.

### Migration Plan

1. Create `bundles`, `future_buckets`, `monthly_buckets` tables
2. Add these types to `Bucket`'s delegated type declaration
3. Data migration (inside transaction):
   - Find root Collection bucket named "Future Log" → create FutureBucket, reassign its Bucket's `bucketable`
   - Convert all TimeSpread records → MonthlyBucket records, set `future_bucket_id` via parent FK chain
   - Find "Year Goals" child Collection → reassign its bullets' `bucket_id` to FutureBucket's Bucket, delete empty Bucket+Collection
   - Drop `timespreads` table (after verification)
4. Drop `bucket_parent_id` from `buckets`
5. Update `Bucket` model to remove `parent`/`children_buckets` associations

### Routes

```ruby
resources :collections       # show renders bundles as sections
resources :bundles           # CRUD, scoped under collection
resource :future             # show/create, POST :months for adding MonthlyBuckets
resource :monthly_bucket, controller: 'monthly_buckets'  # replaces timespreads
resources :buckets, only: %i[index show]  # hub stays
```

### Controllers

- `CollectionsController` — largely unchanged; show page renders direct bullets + bundles at top
- `BundlesController` — new; standard CRUD, show renders its bullets
- `FuturesController` — simplified from current; finds FutureBucket by convention
- `MonthlyBucketsController` — replaces `TimespreadsController` with same logic

### Open Questions (deferred)

- FutureBucket singleton enforcement (convention for now, not DB constraint)
- FutureBucket naming: currently hardcoded "Future Log" but will be renameable via Bucket's name
- CollectionsController pagination: if per-bundle section rendering is sufficient, no `CollectionItem` join model needed
