# Container Types Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current Bucket+TimeSpread hierarchy with explicit Collection/Bundle/FutureBucket/MonthlyBucket domain types.

**Architecture:** Bucket stays as a metadata shell (ownership, identity, pinning) using `delegated_type`. Hierarchy moves off Bucket onto domain-level FKs (bundles.collection_id, monthly_buckets.future_bucket_id). TimeSpread is replaced by MonthlyBucket. FutureBucket is a new first-class type replacing the "root Collection bucket = Future Log" convention.

**Tech Stack:** Rails 8.1, SQLite, Minitest, Delegated Type pattern

---

## File Map

### New files
- `app/models/bundle.rb`
- `app/models/future_bucket.rb`
- `app/models/monthly_bucket.rb`
- `app/controllers/bundles_controller.rb`
- `app/controllers/monthly_buckets_controller.rb`
- `app/helpers/monthly_buckets_helper.rb` (moved from timespreads references)
- `app/views/bundles/` (show, index, _bundle, etc.)
- `app/views/monthly_buckets/` (show, empty, new, _form, _day_composer, _monthly_bucket)
- `db/migrate/20260614140000_create_container_tables.rb`
- `db/migrate/20260614140001_migrate_to_new_types.rb`
- `db/migrate/20260614140002_cleanup_old_types.rb`

### Modified files
- `app/models/bucket.rb` — add 3 new delegated types, drop parent/children
- `app/models/collection.rb` — add `has_many :bundles`
- `app/models/user.rb` — update `timespreads` → `monthly_buckets` scope
- `app/helpers/application_helper.rb` — update `bucket_palette_path`
- `app/controllers/futures_controller.rb` — use FutureBucket
- `app/controllers/buckets_controller.rb` — update joins
- `app/controllers/collections_controller.rb` — minor updates if needed
- `app/views/futures/show.html.erb` — update timespread references
- `app/views/buckets/index.html.erb` — update timespread references
- `app/views/bullets/_metadata.html.erb` — update timespread references
- `app/views/bullets/new.html.erb` — update timespread_id
- `app/views/bullets/pops/create.turbo_stream.erb` — update timespread references
- `app/views/bullets/pops/destroy.turbo_stream.erb` — update timespread references
- `app/views/bullets/_turbo_stream_update.html.erb` — update timespread references
- `app/views/bullets/create.timespread_by_date.turbo_stream.erb` — rename/update
- `app/views/bullets/create.timespread_unplanned.turbo_stream.erb` — rename/update
- `app/views/menu/_menu.html.erb` — update link text/label
- `config/routes.rb` — add bundles, monthly_buckets; rename timespread routes
- `test/test_helper.rb` — update `create_timespread!` to `create_monthly_bucket!`
- `test/models/timespread_test.rb` → `test/models/monthly_bucket_test.rb`
- `test/controllers/timespreads_controller_test.rb` → `test/controllers/monthly_buckets_controller_test.rb`
- All test files using `create_timespread!`

### Deleted files (end state)
- `app/models/time_spread.rb`
- `app/controllers/timespreads_controller.rb`
- `app/views/timespreads/` (entire directory)
- `app/views/bullets/create.timespread_by_date.turbo_stream.erb`
- `app/views/bullets/create.timespread_unplanned.turbo_stream.erb`

---

## Phase 1: Create new tables and models

### Task 1: Migration to create new tables

**Files:**
- Create: `db/migrate/20260614140000_create_container_tables.rb`
- Test: `bin/rails db:migrate`

- [ ] **Step 1: Write migration**

```ruby
class CreateContainerTables < ActiveRecord::Migration[8.1]
  def change
    create_table :bundles do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :future_buckets do |t|
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :monthly_buckets do |t|
      t.references :future_bucket, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :period_from
      t.date :period_to
      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Run migration**

Run: `bin/rails db:migrate`
Expected: Tables `bundles`, `future_buckets`, `monthly_buckets` created.

- [ ] **Step 3: Commit**

```bash
git add db/migrate/20260614140000_create_container_tables.rb db/schema.rb
git commit -m "feat: create bundles, future_buckets, monthly_buckets tables"
```

### Task 2: Create Bundle model

**Files:**
- Create: `app/models/bundle.rb`
- Modify: `app/models/bucket.rb`
- Test: `bin/rails test test/models/bucket_test.rb`

- [ ] **Step 1: Create Bundle model**

```ruby
class Bundle < ApplicationRecord
  include Bucketable
  belongs_to :collection
end
```

- [ ] **Step 2: Update Bucket model to register Bundle**

Add `Bundle` to `delegated_type` declaration:

```ruby
delegated_type :bucketable, types: %w[Collection Bundle FutureBucket MonthlyBucket], dependent: :destroy
```

Remove `TimeSpread` from the types list.

- [ ] **Step 3: Update Collection model**

```ruby
class Collection < ApplicationRecord
  include Bucketable
  has_many :bundles, dependent: :destroy
end
```

- [ ] **Step 4: Run tests to verify nothing broke (Bundle is new, no data yet)**

Run: `bin/rails test`
Expected: Existing tests still pass (Bundle has no data, no queries using it yet).

- [ ] **Step 5: Commit**

```bash
git add app/models/bundle.rb app/models/bucket.rb app/models/collection.rb
git commit -m "feat: add Bundle delegated type model"
```

### Task 3: Create FutureBucket model

**Files:**
- Create: `app/models/future_bucket.rb`

- [ ] **Step 1: Create FutureBucket model**

```ruby
class FutureBucket < ApplicationRecord
  include Bucketable
  has_many :monthly_buckets, dependent: :nullify
end
```

- [ ] **Step 2: Commit**

```bash
git add app/models/future_bucket.rb
git commit -m "feat: add FutureBucket delegated type model"
```

### Task 4: Create MonthlyBucket model

**Files:**
- Create: `app/models/monthly_bucket.rb`

- [ ] **Step 1: Create MonthlyBucket model**

```ruby
class MonthlyBucket < ApplicationRecord
  include Bucketable, Periodable
  belongs_to :future_bucket, optional: true

  scope :covering, lambda { |date = Date.current|
    where(period_from: date.beginning_of_month)
  }

  def self.current(user)
    joins(:bucket).where(buckets: { user_id: user.id }).covering.first
  end

  def current?
    period_from == Date.current.beginning_of_month
  end

  before_validation :snap_period_from
  validate :period_unique_per_user

  private

  def snap_period_from
    self.period_from = period_from.beginning_of_month if period_from.present?
  end

  def period_unique_per_user
    return if bucket&.future_bucket_id.present?
    return unless bucket&.user_id && period_from.present?

    return unless MonthlyBucket.covering(period_from)
                               .joins(:bucket)
                               .where.not(buckets: { id: bucket.id })
                               .where(buckets: { user_id: bucket.user_id })
                               .exists?

    errors.add(:base, "A spread already exists for #{period_from.strftime('%B %Y')}")
  end
end
```

Note: The `period_unique_per_user` validation uses `future_bucket_id` instead of the old `bucket_parent_id`. A root MonthlyBucket (no future_bucket) enforces uniqueness. A child MonthlyBucket (with future_bucket) is considered part of a FutureBucket and doesn't need its own uniqueness constraint.

- [ ] **Step 2: Add `monthly_bucket?` method to Bucket for compatibility**

```ruby
def timespread?
  bucketable_type == 'TimeSpread'
end

def monthly_bucket?
  bucketable_type == 'MonthlyBucket'
end
```

- [ ] **Step 3: Commit**

```bash
git add app/models/monthly_bucket.rb app/models/bucket.rb
git commit -m "feat: add MonthlyBucket delegated type model"
```

---

## Phase 2: Data migration

### Task 5: Write data migration script

**Files:**
- Create: `db/migrate/20260614140001_migrate_to_new_types.rb`

- [ ] **Step 1: Write the data migration**

```ruby
class MigrateToNewTypes < ActiveRecord::Migration[8.1]
  def up
    # 1. Find the "Future Log" root Collection bucket
    future_log_bucket = Bucket.find_by(
      bucketable_type: 'Collection',
      bucket_parent_id: nil,
      name: 'future log'
    )

    if future_log_bucket
      # Create FutureBucket record
      future_bucket = FutureBucket.create!
      future_log_bucket.update!(
        bucketable_type: 'FutureBucket',
        bucketable_id: future_bucket.id
      )

      # 2. Migrate child TimeSpread buckets to MonthlyBucket
      child_buckets = Bucket.where(bucket_parent_id: future_log_bucket.id, bucketable_type: 'TimeSpread')
      child_buckets.each do |child_bucket|
        time_spread = child_bucket.bucketable
        monthly_bucket = MonthlyBucket.create!(
          future_bucket_id: future_bucket.id,
          period_from: time_spread.period_from,
          period_to: time_spread.period_to
        )
        child_bucket.update!(
          bucketable_type: 'MonthlyBucket',
          bucketable_id: monthly_bucket.id
        )
        time_spread.destroy!
      end

      # 3. Find "Year Goals" child Collection -> reassign bullets to FutureBucket
      year_goals_bucket = Bucket.find_by(
        bucket_parent_id: future_log_bucket.id,
        bucketable_type: 'Collection',
        name: 'year goals'
      )

      if year_goals_bucket
        Bullet.where(bucket_id: year_goals_bucket.id).update_all(bucket_id: future_log_bucket.id)
        year_goals_bucket.bucketable.destroy!
        year_goals_bucket.destroy!
      end
    end

    # 4. Migrate standalone TimeSpread buckets (no parent) to MonthlyBucket
    Bucket.where(bucketable_type: 'TimeSpread').find_each do |bucket|
      time_spread = bucket.bucketable
      monthly_bucket = MonthlyBucket.create!(
        period_from: time_spread.period_from,
        period_to: time_spread.period_to
      )
      bucket.update!(
        bucketable_type: 'MonthlyBucket',
        bucketable_id: monthly_bucket.id
      )
      time_spread.destroy!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

- [ ] **Step 2: Run migration**

Run: `bin/rails db:migrate`
Expected: All existing TimeSpread records converted to MonthlyBucket. Future Log Bucket now points to FutureBucket. Year Goals bullets reassigned.

- [ ] **Step 3: Verify in console**

Run: `bin/rails runner "puts Bucket.pluck(:bucketable_type).uniq.sort"`
Expected: `["Bundle", "Collection", "FutureBucket", "MonthlyBucket"]` (no "TimeSpread")

- [ ] **Step 4: Commit**

```bash
git add db/migrate/20260614140001_migrate_to_new_types.rb db/schema.rb
git commit -m "feat: migrate data to new container types"
```

---

## Phase 3: Update routes, controllers, views

### Task 6: Update routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add Bundle and MonthlyBucket routes, rename timespread routes**

In `config/routes.rb`:

```ruby
# Replace:
#   get 'timespread', to: 'timespreads#current', as: :timespread
#   resources :timespreads, only: %i[show new create]

# With:
get 'monthly_bucket', to: 'monthly_buckets#current', as: :monthly_bucket
resources :monthly_buckets, only: %i[show new create]

# Add:
resources :bundles, only: %i[index show new create destroy]
```

- [ ] **Step 2: Run test to verify routes**

Run: `bin/rails routes | grep monthly_bucket`
Expected: Routes for monthly_bucket#current, monthly_buckets#show/new/create

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add bundle and monthly_bucket routes"
```

### Task 7: Create MonthlyBucketsController

**Files:**
- Create: `app/controllers/monthly_buckets_controller.rb`
- Delete: `app/controllers/timespreads_controller.rb`

- [ ] **Step 1: Create MonthlyBucketsController**

Same logic as TimespreadsController, with model references changed:

```ruby
class MonthlyBucketsController < ApplicationController
  before_action :set_monthly_bucket, only: :show

  def current
    @monthly_bucket = MonthlyBucket.current(Current.user)
    if @monthly_bucket
      assign_data
      render :show
    else
      render :empty
    end
  end

  def show
    assign_data
  end

  def new
    @monthly_bucket = MonthlyBucket.new(MonthlyBucket.default_period)
    @monthly_bucket.build_bucket(name: Date.current.strftime("%B %Y"))
  end

  def create
    @monthly_bucket = MonthlyBucket.new(monthly_bucket_params.slice(:period_from, :period_to))
    @monthly_bucket.build_bucket(
      user: Current.user,
      name: monthly_bucket_params[:name],
      colour: monthly_bucket_params[:colour],
      icon: monthly_bucket_params[:icon]
    )

    if @monthly_bucket.save
      redirect_to monthly_bucket_path(@monthly_bucket), notice: "Monthly spread created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_monthly_bucket
    @monthly_bucket = Current.user.monthly_buckets.find(params[:id])
  end

  def assign_data
    @bucket = @monthly_bucket.bucket
    @period_days = @monthly_bucket.period_days
    scoped = Current.user.bullets.where(bucket_id: @bucket.id, archived: false)
    @bullets_by_date = if @period_days
      scoped.where(pops_on: @period_days).includes(:bulletable).group_by(&:pops_on)
    else
      {}
    end
    @unplanned_bullets = scoped.where(pops_on: nil).chronological.includes(:bulletable)
  end

  def monthly_bucket_params
    params.require(:monthly_bucket).permit(:name, :period_from, :period_to, :colour, :icon)
  end
end
```

Note: `MonthlyBucket.current(user)` is a new class method we need to add (like `TimeSpread.current`).

`MonthlyBucket.current(user)` is already defined in the model (Task 4). The `covering` scope was moved there from TimeSpread.

- [ ] **Step 2: Delete TimespreadsController**

```bash
rm app/controllers/timespreads_controller.rb
```

- [ ] **Step 4: Commit**

```bash
git add app/controllers/monthly_buckets_controller.rb app/models/monthly_bucket.rb
git rm app/controllers/timespreads_controller.rb
git commit -m "feat: add MonthlyBucketsController replacing TimespreadsController"
```

### Task 8: Create MonthlyBucket views

**Files:**
- Create: `app/views/monthly_buckets/` (from `app/views/timespreads/` with model renames)
- Delete: `app/views/timespreads/`

- [ ] **Step 1: Copy and update timespread views to monthly_buckets**

For each view in `app/views/timespreads/`:
- Replace `@time_spread` → `@monthly_bucket`
- Replace `time_spread` → `monthly_bucket` in local variable names
- Replace `TimeSpread` → `MonthlyBucket` in class references
- Replace `timespread_path` → `monthly_bucket_path`
- Replace `new_timespread_path` → `new_monthly_bucket_path`
- Replace `timespreads_path` → `monthly_buckets_path`
- Replace CSS class `timespread--` → `monthly-bucket--`
- Replace URL param `timespread_id` → `monthly_bucket_id` (in composer refs)

Views to create:
- `app/views/monthly_buckets/show.html.erb`
- `app/views/monthly_buckets/empty.html.erb`
- `app/views/monthly_buckets/new.html.erb`
- `app/views/monthly_buckets/_form.html.erb`
- `app/views/monthly_buckets/_day_composer.html.erb`
- `app/views/monthly_buckets/_monthly_bucket.html.erb`

- [ ] **Step 2: Create show view**

```erb
<% content_for(:title) { @monthly_bucket.name } %>

<div class="layout--page monthly-bucket--page" data-controller="bulk-menu">
  <div class="layout--header">
    <div class="layout--header-actions">
      <%= link_to buckets_path, class: "button--secondary" do %>
        <i class="icon" style="--icon-mask: var(--icon-arrow-left)" aria-hidden="true"></i>
        Index
      <% end %>
    </div>
    <h2 class="monthly-bucket"><%= @monthly_bucket.name %></h2>
    <% if @monthly_bucket.period? %>
      <p class="utilities--text-sm">
        <%= @monthly_bucket.period_from.strftime("%b %-d") %> – <%= @monthly_bucket.period_to.strftime("%b %-d, %Y") %>
      </p>
    <% end %>
  </div>

  <div class="monthly-bucket--spread" data-bulk-menu-target="list">
    <section class="monthly-bucket--by-date" aria-label="Planned by date" data-controller="scroll">
      <% if @period_days %>
        <% @period_days.each do |date| %>
          <div class="monthly-bucket--date-row"<% if date == Date.current %> data-scroll-target="current"<% end %>>
            <div class="monthly-bucket--date-label">
              <span><%= date.day %></span>
              <span><%= date.strftime("%a")[0] %></span>
            </div>
            <div id="<%= dom_id(@monthly_bucket, "date_#{date}_bullets") %>"
                 class="monthly-bucket--date-entries"
                 data-controller="time-spread-drop"
                 data-time-spread-drop-pop-url-value="<%= pop_path %>"
                 data-time-spread-drop-pops-on-value="<%= date.iso8601 %>"
                 data-action="dragover->time-spread-drop#dragover dragleave->time-spread-drop#dragleave drop->time-spread-drop#drop">
              <% (@bullets_by_date[date] || []).each do |bullet| %>
                <%= render_monthly_bucket_bullet(bullet) %>
              <% end %>
            </div>
            <turbo-frame id="<%= dom_id(@monthly_bucket, "date_#{date}_composer") %>">
              <%= render "monthly_buckets/day_composer", monthly_bucket: @monthly_bucket, date: date, bucket: @bucket %>
            </turbo-frame>
          </div>
        <% end %>
      <% else %>
        <p class="monthly-bucket--by-date-empty">No period set for this spread.</p>
      <% end %>
    </section>

    <section class="monthly-bucket--unplanned" aria-label="Unplanned">
      <h3 class="utilities--text-sm">Unplanned</h3>
      <div id="<%= dom_id(@monthly_bucket, :unplanned_bullets) %>"
           class="monthly-bucket--unplanned-entries"
           data-controller="time-spread-drop"
           data-time-spread-drop-pop-url-value="<%= pop_path %>"
           data-action="dragover->time-spread-drop#dragover dragleave->time-spread-drop#dragleave drop->time-spread-drop#drop">
        <% @unplanned_bullets.each do |bullet| %>
          <%= render_monthly_bucket_bullet(bullet) %>
        <% end %>
      </div>
      <turbo-frame id="<%= dom_id(@monthly_bucket, :unplanned_composer) %>">
        <%= render "bullets/composer",
              attributes: {
                bucket_id: @bucket.id,
                render_context: "monthly_bucket_unplanned",
                monthly_bucket_id: @monthly_bucket.id
              } %>
      </turbo-frame>
    </section>
  </div>

  <%= render "bullets/bulk_menu" %>
</div>
```

- [ ] **Step 3: Create remaining views (empty, new, _form, _day_composer, _monthly_bucket)**

For each remaining view, copy from `app/views/timespreads/` and apply these substitutions:
- `@time_spread` → `@monthly_bucket`
- `time_spread` (local var) → `monthly_bucket`
- `TimeSpread` → `MonthlyBucket`
- `timespread_path` → `monthly_bucket_path`
- `new_timespread_path` → `new_monthly_bucket_path`
- `timespreads_path` → `monthly_buckets_path`
- `.timespread--` CSS classes → `.monthly-bucket--`
- `timespread_id` → `monthly_bucket_id`
- `create_timespread!` → `create_monthly_bucket!`

- [ ] **Step 4: Delete old timespread views**

```bash
rm -rf app/views/timespreads
```

- [ ] **Step 5: Commit**

```bash
git add app/views/monthly_buckets/
git rm -r app/views/timespreads/
git commit -m "feat: add monthly_bucket views replacing timespread views"
```

### Task 9: Update helpers

**Files:**
- Modify: `app/helpers/application_helper.rb`

- [ ] **Step 1: Update `bucket_palette_path`**

```ruby
def bucket_palette_path(bucket)
  bucketable = bucket.bucketable
  case bucketable
  when Collection then collection_path(bucketable)
  when Bundle then bundle_path(bucketable)
  when FutureBucket then future_path
  when MonthlyBucket then monthly_bucket_path(bucketable)
  else raise ArgumentError, "Unknown bucketable type: #{bucketable.class}"
  end
end
```

- [ ] **Step 2: Add `render_monthly_bucket_bullet` alias**

```ruby
def render_monthly_bucket_bullet(bullet)
  render_bullet(bullet, draggable: true, timespread: true)
end
```

- [ ] **Step 3: Commit**

```bash
git add app/helpers/application_helper.rb
git commit -m "feat: update helpers for new container types"
```

### Task 10: Update FuturesController

**Files:**
- Modify: `app/controllers/futures_controller.rb`

- [ ] **Step 1: Update FuturesController to use FutureBucket**

The controller currently finds a root Collection bucket by convention. After migration, it should find the user's FutureBucket bucket instead.

```ruby
class FuturesController < ApplicationController
  def show
    @future = Current.user.buckets
                     .where(bucketable_type: 'FutureBucket')
                     .joins(:children_buckets)
                     .distinct
                     .first

    if @future
      @children = @future.children_buckets.includes(:bucketable)
      render :show
    else
      render :empty
    end
  end

  def create
    today = Date.current

    Bucket.transaction do
      future_bucket_record = FutureBucket.create!
      @future = Current.user.buckets.create!(
        bucketable: future_bucket_record,
        user: Current.user,
        name: 'Future Log'
      )

      current_monthly = MonthlyBucket.covering(today)
                                     .joins(:bucket)
                                     .where(buckets: { user_id: Current.user.id })
                                     .first

      current_monthly ||= MonthlyBucket.create!(
        period_from: today.beginning_of_month,
        period_to: today.end_of_month
      ) { |mb| mb.build_bucket(user: Current.user, name: today.strftime('%B %Y')) }

      current_monthly.update!(future_bucket_id: future_bucket_record.id)
    end

    redirect_to future_path, notice: 'Future log created'
  end

  def months
    today = Date.current
    future = Current.user.buckets
                    .where(bucketable_type: 'FutureBucket')
                    .joins(:children_buckets)
                    .distinct
                    .first

    if future
      last_child = future.children_buckets
                         .where(bucketable_type: 'MonthlyBucket')
                         .joins(:bucketable)
                         .maximum('monthly_buckets.period_to')

      next_month = (last_child || today.beginning_of_month) + 1.month

      Bucket.transaction do
        MonthlyBucket.create!(
          period_from: next_month.beginning_of_month,
          period_to: next_month.end_of_month
        ) { |mb| mb.build_bucket(user: Current.user, name: next_month.strftime('%B %Y'), bucket_parent: future) }
      end
    end

    redirect_to future_path, notice: 'Month added'
  end
end
```

- [ ] **Step 2: Update `children_buckets` reference**

The `children_buckets` association on Bucket uses `bucket_parent_id`, which is still present in the schema. In Phase 4 we'll drop it — but for now, the association stays and works.

- [ ] **Step 3: Commit**

```bash
git add app/controllers/futures_controller.rb
git commit -m "feat: update FuturesController to use FutureBucket type"
```

### Task 11: Update BucketsController

**Files:**
- Modify: `app/controllers/buckets_controller.rb`
- Modify: `app/views/buckets/index.html.erb`

- [ ] **Step 1: Update BucketsController#index**

Change the Future Log query to look for `FutureBucket` type instead of root Collection:

```ruby
def index
  @projects = Current.user.projects.first(8)

  @future = Current.user.buckets
                   .where(bucketable_type: 'FutureBucket')
                   .joins(:children_buckets)
                   .distinct
                   .first

  @collections = Current.user.collections.first(8)
  @timespreads = Current.user.monthly_buckets.first(8)
  @activities = Current.user.bullet_activities
                       .includes(:bullet)
                       .order(created_at: :desc)
                       .limit(10)
end
```

Add `has_many :monthly_buckets, through: :buckets` to User model:

```ruby
# In app/models/user.rb
has_many :monthly_buckets, through: :buckets, source: :bucketable, source_type: 'MonthlyBucket'
```

- [ ] **Step 2: Update buckets index view**

In `app/views/buckets/index.html.erb`:
- Replace `new_timespread_path` → `new_monthly_bucket_path`
- Replace `timespreads/time_spread` partial → `monthly_buckets/monthly_bucket`
- Replace `timespread` CSS class references
- Replace "Time spreads" heading → "Monthly spreads"
- Replace link text "+ Add monthly log" → "+ Add monthly bucket"

- [ ] **Step 3: Commit**

```bash
git add app/controllers/buckets_controller.rb app/models/user.rb app/views/buckets/index.html.erb
git commit -m "feat: update BucketsController and view for new types"
```

### Task 12: Create BundlesController and views

**Files:**
- Create: `app/controllers/bundles_controller.rb`
- Create: `app/views/bundles/show.html.erb`
- Create: `app/views/bundles/_bundle.html.erb`
- Modify: `app/views/collections/show.html.erb`

- [ ] **Step 1: Create BundlesController**

```ruby
class BundlesController < ApplicationController
  before_action :set_collection
  before_action :set_bundle, only: %i[show destroy]

  def show
    @bullets = Current.user.bullets
                      .where(bucket_id: @bundle.bucket.id)
                      .where(archived: false)
                      .distinct
                      .chronological
  end

  def create
    @bundle = @collection.bundles.new
    if save_bundle_with_bucket(@bundle)
      redirect_back fallback_location: collection_path(@collection), notice: "Bundle created"
    else
      redirect_back fallback_location: collection_path(@collection), alert: "Could not create bundle"
    end
  end

  def destroy
    @bundle.bucket.destroy
    redirect_back fallback_location: collection_path(@collection), notice: "Bundle deleted"
  end

  private

  def set_collection
    @collection = Current.user.collections.find(params[:collection_id])
  end

  def set_bundle
    @bundle = @collection.bundles.find(params[:id])
  end

  def save_bundle_with_bucket(bundle)
    ActiveRecord::Base.transaction do
      bundle.save!
      Current.user.buckets.create!(
        bucketable: bundle,
        name: bundle_params[:name],
        colour: bundle_params[:colour],
        icon: bundle_params[:icon]
      )
    end
  end

  def bundle_params
    params.require(:bundle).permit(:name, :colour, :icon)
  end
end
```

- [ ] **Step 2: Create bundle views**

`app/views/bundles/show.html.erb`:
```erb
<% content_for(:title) { @bundle.name } %>

<div class="layout--page">
  <div class="layout--header">
    <div class="layout--header-actions">
      <%= link_to collection_path(@collection), class: "button--secondary" do %>
        <i class="icon" style="--icon-mask: var(--icon-arrow-left)" aria-hidden="true"></i>
        <%= @collection.name %>
      <% end %>
    </div>
    <h2><%= @bundle.name %></h2>
  </div>

  <article class="layout--column">
    <div id="bullets">
      <%= render partial: "bullets/bullet", collection: @bullets, as: :bullet %>
    </div>
  </article>
</div>
```

`app/views/bundles/_bundle.html.erb`:
```erb
<li id="<%= dom_id(bundle.bucket, :list_item) %>" class="layout--list-item">
  <%= link_to [bundle.collection, bundle], class: "bucket--list-item-link" do %>
    <div class="bucket--list-item-name">
      <div class="bucket--list-item-marker" data-bucket-colour="<%= bundle.colour %>" aria-hidden="true">
        <% if bundle.icon.present? %>
          <i class="icon" style="--icon-mask: <%= bundle.icon_mask %>" aria-hidden="true"></i>
        <% end %>
      </div>
      <span class="utilities--line-clamp-1"><%= bundle.name %></span>
    </div>
    <div class="utilities--line-clamp-1">
      <span><%= bundle.bullets.count %> <%= "bullet".pluralize(bundle.bullets.count) %></span>
    </div>
  <% end %>
</li>
```

- [ ] **Step 3: Update collection show view to link to bundles**

In `app/views/collections/show.html.erb`, add a bundles section at the top:

```erb
<% if @collection.bundles.any? %>
  <section class="collection--bundles">
    <h3>Bundles</h3>
    <ul class="layout--list">
      <%= render partial: "bundles/bundle", collection: @collection.bundles, as: :bundle %>
    </ul>
  </section>
<% end %>
```

- [ ] **Step 4: Commit**

```bash
git add app/controllers/bundles_controller.rb app/views/bundles/ app/views/collections/show.html.erb
git commit -m "feat: add BundlesController and views"
```

### Task 13: Update all remaining view references

**Files:**
- Modify: `app/views/futures/show.html.erb`
- Modify: `app/views/bullets/_metadata.html.erb`
- Modify: `app/views/bullets/pops/create.turbo_stream.erb`
- Modify: `app/views/bullets/pops/destroy.turbo_stream.erb`
- Modify: `app/views/bullets/_turbo_stream_update.html.erb`
- Modify: `app/views/bullets/new.html.erb`
- Modify: `app/views/menu/_menu.html.erb`
- Create: `app/views/bullets/create.monthly_bucket_by_date.turbo_stream.erb`
- Create: `app/views/bullets/create.monthly_bucket_unplanned.turbo_stream.erb`
- Delete: `app/views/bullets/create.timespread_by_date.turbo_stream.erb`
- Delete: `app/views/bullets/create.timespread_unplanned.turbo_stream.erb`

- [ ] **Step 1: Update futures/show.html.erb**

Replace all `timespread_path` → `monthly_bucket_path` and `timespread?` → `monthly_bucket?` and `TimeSpread` → `MonthlyBucket` references.

- [ ] **Step 2: Update bullets/_metadata.html.erb**

Replace `timespread_path` → `monthly_bucket_path`, `timespread_hint` → `monthly_bucket_hint`, CSS classes as needed.

- [ ] **Step 3: Update turbo stream files**

Replace `timespread` with `monthly_bucket` in all render contexts, partial paths, and helper calls.

- [ ] **Step 4: Update bullets/new.html.erb**

Replace `timespread_id` param → `monthly_bucket_id`.

- [ ] **Step 5: Update menu/_menu.html.erb**

Replace `timespread_path` → `monthly_bucket_path` and "Time spread" → "Monthly spread".

- [ ] **Step 6: Create new turbo stream templates**

`app/views/bullets/create.monthly_bucket_by_date.turbo_stream.erb`:
```erb
<% monthly_bucket = Current.user.monthly_buckets.find(@monthly_bucket_id) %>
<% date = @bullet.pops_on %>

<%= turbo_stream.append dom_id(monthly_bucket, "date_#{date}_bullets") do %>
  <%= render_monthly_bucket_bullet(@bullet) %>
<% end %>

<%= turbo_stream.update dom_id(monthly_bucket, "date_#{date}_composer") do %>
  <%= render "monthly_buckets/day_composer", monthly_bucket: monthly_bucket, date: date, bucket: @bullet.bucket %>
<% end %>
```

`app/views/bullets/create.monthly_bucket_unplanned.turbo_stream.erb`:
```erb
<% monthly_bucket = Current.user.monthly_buckets.find(@monthly_bucket_id) %>

<%= turbo_stream.append dom_id(monthly_bucket, :unplanned_bullets) do %>
  <%= render_monthly_bucket_bullet(@bullet) %>
<% end %>

<%= turbo_stream.update dom_id(monthly_bucket, :unplanned_composer) do %>
  <%= render "bullets/composer", attributes: { bucket_id: @bullet.bucket_id, render_context: "monthly_bucket_unplanned", monthly_bucket_id: monthly_bucket.id } %>
<% end %>
```

- [ ] **Step 7: Clean up old turbo stream templates**

```bash
rm app/views/bullets/create.timespread_by_date.turbo_stream.erb
rm app/views/bullets/create.timespread_unplanned.turbo_stream.erb
```

- [ ] **Step 8: Update Bullet controller to pass `@monthly_bucket_id`**

In `app/controllers/bullets_controller.rb`, find where `@timespread_id` is set and rename to `@monthly_bucket_id`.

- [ ] **Step 9: Commit**

```bash
git add app/views/futures/ app/views/bullets/ app/views/menu/ app/controllers/bullets_controller.rb
git rm app/views/bullets/create.timespread_*.erb
git commit -m "feat: update all view references to use MonthlyBucket"
```

---

## Phase 4: Update tests and cleanup

### Task 14: Update test helper

**Files:**
- Modify: `test/test_helper.rb`

- [ ] **Step 1: Add `create_monthly_bucket!` helper**

```ruby
def create_monthly_bucket!(user, name:, period_from: nil, period_to: nil, colour: nil, icon: nil)
  period = MonthlyBucket.default_period
  monthly_bucket = MonthlyBucket.create!(
    period_from: period_from || period[:period_from],
    period_to: period_to || period[:period_to]
  )
  user.buckets.create!(
    bucketable: monthly_bucket,
    name: name,
    colour: colour,
    icon: icon
  )
  monthly_bucket
end
```

Keep `create_timespread!` temporarily for backward compat during migration, or replace all call sites directly.

- [ ] **Step 2: Commit**

```bash
git add test/test_helper.rb
git commit -m "feat: add create_monthly_bucket! test helper"
```

### Task 15: Update timespread tests → monthly_bucket tests

**Files:**
- Rename: `test/models/timespread_test.rb` → `test/models/monthly_bucket_test.rb`
- Rename: `test/controllers/timespreads_controller_test.rb` → `test/controllers/monthly_buckets_controller_test.rb`

- [ ] **Step 1: Rename and update model test**

Move `test/models/timespread_test.rb` → `test/models/monthly_bucket_test.rb` and replace:
- `TimeSpread` → `MonthlyBucket`
- `create_timespread!` → `create_monthly_bucket!`
- `time_spread` local var → `monthly_bucket`

- [ ] **Step 2: Rename and update controller test**

Move `test/controllers/timespreads_controller_test.rb` → `test/controllers/monthly_buckets_controller_test.rb` and replace:
- `TimeSpread` → `MonthlyBucket`
- `create_timespread!` → `create_monthly_bucket!`
- `timespread_path` → `monthly_bucket_path`
- `timespreads_path` → `monthly_buckets_path`
- `new_timespread_path` → `new_monthly_bucket_path`
- CSS class `.timespread--` → `.monthly-bucket--`
- View partial references

- [ ] **Step 3: Run tests**

Run: `bin/rails test test/models/monthly_bucket_test.rb test/controllers/monthly_buckets_controller_test.rb`
Expected: All pass.

- [ ] **Step 4: Commit**

```bash
git add test/models/monthly_bucket_test.rb test/controllers/monthly_buckets_controller_test.rb
git rm test/models/timespread_test.rb test/controllers/timespreads_controller_test.rb
git commit -m "test: rename timespread tests to monthly_bucket tests"
```

### Task 16: Update all other test files referencing TimeSpread

**Files to modify:**
- `test/controllers/bullets/collects_controller_test.rb`
- `test/controllers/bullets/pops_controller_test.rb`
- `test/controllers/bullets/completes_controller_test.rb`
- `test/controllers/bullets/pins_controller_test.rb`
- `test/controllers/buckets_controller_test.rb`

- [ ] **Step 1: Replace `create_timespread!` with `create_monthly_bucket!` in each test file**

Each file uses `create_timespread!` similarly. Replace the helper call and any `TimeSpread`/`timespread` references.

- [ ] **Step 2: Run full test suite**

Run: `bin/rails test`
Expected: All 179+ tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/
git commit -m "test: update all test references from TimeSpread to MonthlyBucket"
```

### Task 17: Cleanup — remove old types and columns

**Files:**
- Create: `db/migrate/20260614140002_cleanup_old_types.rb`
- Delete: `app/models/time_spread.rb`

- [ ] **Step 1: Write cleanup migration**

```ruby
class CleanupOldTypes < ActiveRecord::Migration[8.1]
  def change
    drop_table :timespreads
    remove_column :buckets, :bucket_parent_id, :integer
  end
end
```

- [ ] **Step 2: Remove TimeSpread model and `timespread?` method from Bucket**

```bash
rm app/models/time_spread.rb
```

And in `app/models/bucket.rb`, remove the `timespread?` method (keep `monthly_bucket?`).

- [ ] **Step 3: Remove `children_buckets` and `bucket_parent` from Bucket model**

```ruby
# Remove these lines:
# belongs_to :bucket_parent, class_name: 'Bucket', optional: true
# has_many :children_buckets, class_name: 'Bucket', foreign_key: :bucket_parent_id, dependent: :nullify
# scope :root_buckets, -> { where(bucket_parent_id: nil) }
```

- [ ] **Step 4: Run migration and tests**

Run: `bin/rails db:migrate && bin/rails test`
Expected: Migrations run, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/20260614140002_cleanup_old_types.rb db/schema.rb app/models/time_spread.rb app/models/bucket.rb
git rm app/models/time_spread.rb
git commit -m "feat: remove old types, bucket_parent_id, and TimeSpread model"
```

### Task 18: Remove old `timespread?` method from Bucket references in views

**Files:**
- `app/views/futures/show.html.erb` — `bucket.timespread?` → `bucket.monthly_bucket?`
- `app/views/bullets/_turbo_stream_update.html.erb` — `source_bucket&.timespread?` → `source_bucket&.monthly_bucket?` and `bullet.bucket&.timespread?` → `bullet.bucket&.monthly_bucket?`
- `app/views/bullets/pops/create.turbo_stream.erb` — `bucket&.timespread?` → `bucket&.monthly_bucket?`
- `app/views/bullets/pops/destroy.turbo_stream.erb` — `bucket&.timespread?` → `bucket&.monthly_bucket?`

- [ ] **Step 1: Replace all `timespread?` calls with `monthly_bucket?`**

Search for `timespread?` across all views and replace with `monthly_bucket?`.

- [ ] **Step 2: Run tests**

Run: `bin/rails test`
Expected: All pass.

- [ ] **Step 3: Commit**

```bash
git add app/views/
git commit -m "feat: replace timespread? with monthly_bucket? in all views"
```

### Task 19: Final pass — remove any remaining TimeSpread references

- [ ] **Step 1: Search for remaining references**

Run: `rg "TimeSpread|timespread" app/ test/ config/routes.rb --include "*.rb" --include "*.erb"`

Expected: No remaining references (all migrated to MonthlyBucket/FutureBucket/Bundle).

- [ ] **Step 2: Run full CI if available**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: remove all remaining TimeSpread references"
```
