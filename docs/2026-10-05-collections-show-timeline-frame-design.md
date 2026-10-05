# Collections show with timeline frame

## Goal

Add `collections#show` as the collection page: management panel + one lazy Turbo Frame for the timeline. Drop the collection header from `bullets/index` so that chrome lives only on show.

## Decisions

- **Approach:** show shell + `turbo_frame` with `src: bullets_path(collection:)` (same index, no nested bullets controller).
- **No redirects** for old `bullets?collection=` URLs; they remain valid as frame source / full-page feed without the panel.
- **Entry points** (search chips, create/update redirects) go to `collection_path`.
- **One frame only** — panel is normal HTML on show; timeline is the lazy frame.

## Design

### Routes

```ruby
resources :collections, except: %i[index] # adds :show; keep new/create/edit/update/destroy
```

### `CollectionsController#show`

- `before_action :set_collection` (active collection for current user)
- Renders `collections/show`

### `collections/show.html.erb`

- `content_for :title` = collection name
- `shared/back_tabbar`
- `main.timeline--window`
  - header panel: `h1` name + dropdown (Export → `export_bullets_path(collection:)`, Edit → `edit_collection_path`) — same actions as today’s index header
  - `turbo_frame_tag dom_id(@collection, :timeline), src: bullets_path(collection: @collection.name)` with a small loading placeholder
- `bullets/bulk_menu` (selection targets live inside the framed scroller)

### `bullets/index.html.erb`

- Remove the `<% if @filter.collection %>` header block entirely
- When `@filter.collection` present, wrap the scroller (load-more + sections) in:

```erb
<%= turbo_frame_tag dom_id(@filter.collection, :timeline) do %>
  … scroller …
<% end %>
```

- Daylog / date filters: no collection frame (unchanged aside from missing dead collection header branch)
- Composer still only when `@filter.empty?`
- `data-timeline-scroll-path-value` stays `bullets_path(@filter.to_params)` so `?before=` pagination is unchanged

### Call sites

- `searches/_navigation`, `searches/_results` → `collection_path(collection)` (or entry)
- `CollectionsController` create/update / collect return → `collection_path(@collection)`
- `collections/edit` cancel/back url if it pointed at `bullets_path(collection:)` → show

### Tests

- `CollectionsControllerTest`: `GET show` success; panel title/Export/Edit; frame with `src` to `bullets_path(collection:)`
- Collection feed assertions move off “header on bullets index” onto show; bullets index with `?collection=` still lists bullets, has matching frame id, **no** collection header
- Search / create-update redirect expectations → `collection_path`
- Existing `before` / export / filter tests stay on `bullets_path`

## Out of scope

- Redirecting `bullets?collection=` → show
- Composer on collection feeds
- Changing `Bullet::Filter` / pagination
- Collection index page
- Upcoming / other filters as show-style shells

## Success criteria

- Opening a collection from search lands on `/collections/:id` with panel + loaded timeline frame
- `bullets/index` has no collection management header
- Infinite scroll on a collection timeline still hits `bullets_path(collection:, before:)`
