# Unified Bullet Composer — Design Spec

## Problem

30+ turbo-frames on `monthly_buckets/show`, multiple `create.*.turbo_stream.erb` variants, `@render_context` / `@monthly_bucket_id` plumbing through controllers and forms — the composer system has grown context-specific variants that can be unified.

## Approach

**Two orthogonal axes:**
1. **Server context** — nested routes let the controller know what bucketable (MonthlyBucket) owns the bullet, so it can render the right partial without hidden fields
2. **Client targeting** — CSS class `bullet_pops_on_<date>` on composer frames; `turbo_stream.before targets:` locates the insertion point without needing IDs or render_context

## File Plan

### Remove (4 files)

- `app/views/bullets/create.monthly_bucket_by_date.turbo_stream.erb`
- `app/views/bullets/create.monthly_bucket_unplanned.turbo_stream.erb`
- `app/views/bullets/create.project.turbo_stream.erb`
- `app/views/monthly_buckets/_day_composer.html.erb`

### Modify (8 files)

- `app/views/bullets/create.turbo_stream.erb` — unified, one-liner `before`
- `app/views/bullets/_bulletable_form.html.erb` — optional `url:` override, drop hidden context fields
- `app/views/daylogs/show.html.erb` — add `class="bullet_pops_on_<%= @selected_date %>"`
- `app/views/collections/show.html.erb` — add `class="bullet_pops_on_"`
- `app/views/projects/show.html.erb` — add `class="bullet_pops_on_"`
- `app/views/monthly_buckets/show.html.erb` — add class per frame, move frames inside date-entries, nested routes
- `app/controllers/bullets_controller.rb` — remove `@render_context`, `@monthly_bucket_id`, variant methods
- `config/routes.rb` — add nested bullets under monthly_buckets

### Create (4 files)

- `app/controllers/monthly_buckets/bullets_controller.rb` — nested controller, new + create
- `app/views/monthly_buckets/bullets/_bullet.html.erb` — compact monthly-bucket bullet partial
- `app/views/monthly_buckets/bullets/new.html.erb` — composer form wrapper (no turbo-frame)
- `app/views/monthly_buckets/bullets/create.turbo_stream.erb` — monthly bucket turbo response

## HTML Convention

All composer `<turbo-frame>` elements carry a class in the form `bullet_pops_on_<key>`, where key is:

| pops_on | bucketable | Key | Example |
|---------|------------|-----|---------|
| present | any | ISO8601 date | `bullet_pops_on_2026-06-15` |
| nil, bucket exists | MonthlyBucket | unplanned | `bullet_pops_on_unplanned` |
| nil | Collection / Daylog / Project / none | empty string | `bullet_pops_on_` |

## Turbo Stream — BulletsController (daylog, collection, project)

```
app/views/bullets/create.turbo_stream.erb:

<%= turbo_stream.before targets: ".bullet_pops_on_#{@bullet.pops_on}" do %>
  <%= render @bullet %>
<% end %>

<% if @bullet.pops_on.present? && @bullet.pops_on > Date.current %>
  <%= turbo_stream.update "toasts" do %>
    <%= render "shared/toasts", type: "notify",
          messages: ["Scheduled for #{@bullet.pops_on.strftime('%B %d')}"] %>
  <% end %>
<% end %>
```

No `update` on the composer frame — the form stays open for consecutive entries.

## Turbo Stream — MonthlyBuckets::BulletsController

```
app/views/monthly_buckets/bullets/create.turbo_stream.erb:

<%= turbo_stream.before targets: ".bullet_pops_on_#{@bullet.pops_on}" do %>
  <%= render "monthly_buckets/bullets/bullet", bullet: @bullet %>
<% end %>
```

Same pattern, different partial.

## Monthly Bucket Bullet Partial

`app/views/monthly_buckets/bullets/_bullet.html.erb` — hardcodes the compact + draggable behaviour that was previously controlled by the `monthly_bucket:` parameter:

- Renders just `bullet--line` (name only)
- No select checkbox
- `draggable="true"` with `bullet-drag` Stimulus controller

## \_bulletable\_form — url: override

```erb
<%= form_with model: bullet,
      url: local_assigns[:url].presence,
      namespace: ... %>
```

When `url:` is passed (from monthly bucket's new), the form POSTs to the nested route. Otherwise (daylog/collection), Rails infers `POST /bullets`.

Hidden fields `render_context` and `monthly_bucket_id` are removed from the form. Only `pops_on` and `bucket_id` remain.

## Monthly Bucket Show — layout change

Per-date composer frames move **inside** `.monthly-bucket--date-entries` so `before` inserts the bullet inside the same container, before the composer.

Unplanned composer gets class `bullet_pops_on_` (empty date key).

## BulletsController — removals

- Remove `@render_context`, `@monthly_bucket_id` from `new`
- Remove `render_create_turbo_stream` / `create_turbo_stream_variant?` methods
- `create` always renders `format.turbo_stream` (single template)

`@default_project_id` / `@default_person_id` remain for project context.

## Routes

```ruby
resources :monthly_buckets, only: %i[show new create] do
  resources :bullets, only: %i[new create],
           controller: "monthly_buckets/bullets"
end
```

Generates:
- `GET  /monthly_buckets/:id/bullets/new  → monthly_buckets/bullets#new`
- `POST /monthly_buckets/:id/bullets      → monthly_buckets/bullets#create`
