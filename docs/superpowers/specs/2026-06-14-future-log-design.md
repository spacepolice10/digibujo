# Future Log Design

## Summary
A Future Log (BuJo concept) as a Collection Bucket that contains child Buckets: a monthly TimeSpread for the current month, a Year Goals Collection, and on-demand monthly TimeSpreads for future months.

## Schema

```ruby
# Migration
add_reference :buckets, :parent, foreign_key: { to_table: :buckets }
```

## Model Changes

### Bucket
```ruby
belongs_to :parent, class_name: "Bucket", optional: true
has_many :children, class_name: "Bucket", foreign_key: :parent_id, dependent: :nullify

scope :root_buckets, -> { where(parent_id: nil) }
```

### TimeSpread
`period_unique_per_user` skips validation when the spread's bucket has a parent_id.

`TimeSpread.current(user)` unchanged — finds the current month's spread regardless of parentage.

## New Files

| File | Purpose |
|------|---------|
| `app/controllers/futures_controller.rb` | `show`, `create` |
| `app/views/futures/show.html.erb` | 3-column grid of children |
| `app/views/futures/empty.html.erb` | Empty state |
| `app/assets/stylesheets/future.css` | Future-specific styles |

## Controller

```ruby
class FuturesController < ApplicationController
  def show
    @future = Current.user.buckets
                    .root_buckets
                    .where(bucketable_type: "Collection")
                    .joins(:children).distinct
                    .first
    if @future
      @children = @future.children.includes(:bucketable)
      render :show
    else
      render :empty
    end
  end

  def create
    today = Date.current

    Bucket.transaction do
      @future = Bucket.create!(
        bucketable: Collection.new,
        user: Current.user,
        name: "Future Log"
      )

      current_monthlylog = TimeSpread.covering(today)
                               .joins(:bucket)
                               .where(buckets: { user_id: Current.user.id, parent_id: nil })
                               .first

      unless current_monthlylog
        current_monthlylog = TimeSpread.create!(
          period_from: today.beginning_of_month,
          period_to: today.end_of_month
        ) { |ts| ts.build_bucket(user: Current.user, name: today.strftime("%B %Y")) }
      end

      current_monthlylog.bucket.update!(parent_id: @future.id)

      Bucket.create!(
        bucketable: Collection.new,
        user: Current.user,
        name: "Year Goals",
        parent: @future
      )
    end

    redirect_to future_path, notice: "Future log created"
  end
end
```

## Route

```ruby
resource :future, only: [:show, :create], controller: 'futures'
```

## View

3-column grid showing each child bucket with its unplanned bullets and a "+ Add" composer. Clicking a month header navigates to `/timespreads/:id`. An "Add month" slot lets the user create new monthly TimeSpread children on demand.

## Buckets Index

- Collections and TimeSpreads filtered to `root_buckets` only (children hidden)
- Future Log appears in the Collections section, linking to `/future`

## Navigation

Future link added to the menu alongside existing links.

## Edge Cases

- Destroying a Future nullifies `parent_id` on children (they become independent)
- Creating a second Future is not prevented but the show query returns the first one
- Year Goals collection has per-user name uniqueness when root, children skip uniqueness
