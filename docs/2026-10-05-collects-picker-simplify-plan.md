# Collects Picker Simplify Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the collects picker to icon+name rows, cap at 10 collections, keep search, and fix the turbo-stream replace target.

**Architecture:** Drop GearedPagination from `Bullets::CollectsController#new`. Return `scope.limit(10)`. Wrap “New collection” + list in `#collects-collections-list` and replace that id on turbo-stream search. Strip count/date from collection rows.

**Tech Stack:** Rails, Turbo Streams, Stimulus combobox (unchanged), Minitest

## Global Constraints

- Collection rows: coloured icon + name only (no bullet count, no created date).
- Hard cap: 10 collections after `matching_name` / `order(:name)`.
- Keep combobox search → `responseKind: "turbo-stream"`.
- Replace target id: `collects-collections-list` (includes “New collection”).
- Do not commit unless the user asks.

---

## File structure

| File | Responsibility |
|------|----------------|
| `app/controllers/bullets/collects_controller.rb` | Load ≤10 matching collections; no page object |
| `app/views/bullets/collects/_collection.html.erb` | Icon + name submit row |
| `app/views/bullets/collects/_collections_list.html.erb` | Stable replaceable list wrapper |
| `app/views/bullets/collects/_picker.html.erb` | Drop `collections_page` local |
| `app/views/bullets/collects/new.html.erb` | Drop `collections_page` local |
| `app/views/bullets/collects/new.turbo_stream.erb` | Replace `collects-collections-list` |
| `test/controllers/bullets/collects_controller_test.rb` | Cover limit, turbo target, row content |

---

### Task 1: Tests for limit, turbo target, and simplified rows

**Files:**
- Modify: `test/controllers/bullets/collects_controller_test.rb`
- Test: same file

**Interfaces:**
- Consumes: `new_collect_path`, `create_collection!`, `create_bullet!`
- Produces: failing expectations for no pagination, `collects-collections-list` turbo replace, ≤10 collections, no count/date metadata

- [ ] **Step 1: Write the failing tests**

Replace the pagination-focused tests and add coverage:

```ruby
test 'new renders collections list without pagination' do
  create_collection!(@user, name: 'Ideas')
  card = create_bullet!(@user, body: 'Move me')

  get new_collect_path, params: { bullet_ids: card.id.to_s }

  assert_select '#collects-collections-list'
  assert_select '#paginated-collects-collections', count: 0
  assert_select '[data-controller="pagination"]', count: 0
end

test 'new turbo stream replaces list container for live search' do
  create_collection!(@user, name: 'alpha')
  create_collection!(@user, name: 'beta')
  card = create_bullet!(@user, body: 'Move me')

  get new_collect_path,
      params: { bullet_ids: card.id.to_s, q: 'alp' },
      headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

  assert_response :success
  assert_match %(turbo-stream action="replace" target="collects-collections-list"), response.body
  assert_match 'alpha', response.body
  assert_no_match 'beta', response.body
end

test 'new returns at most 10 collections' do
  11.times { |i| create_collection!(@user, name: format('Collection %02d', i)) }
  card = create_bullet!(@user, body: 'Move me')

  get new_collect_path, params: { bullet_ids: card.id.to_s }

  assert_response :success
  assert_select '#collects-collections-list button.picker--item', count: 10
end

test 'new collection rows omit bullet count and date' do
  collection = create_collection!(@user, name: 'Ideas')
  card = create_bullet!(@user, body: 'Counted')
  card.collect!(collection_id: collection.id)

  get new_collect_path, params: { bullet_ids: card.id.to_s }

  assert_response :success
  assert_match 'Ideas', response.body
  assert_no_match(/bullet/i, response.body)
  assert_no_match collection.created_at.strftime('%b %d'), response.body
end
```

Also rename/remove the old tests:
- Remove `test 'new renders paginated collections list'`
- Remove/replace `test 'new turbo stream replaces list containers for live search'` (replaced above)

Keep existing search/filter and “New collection” link tests.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
mise exec -- env -u BUNDLE_PATH bin/rails test test/controllers/bullets/collects_controller_test.rb
```

Expected: FAIL on new assertions (`#collects-collections-list` missing, still targeting `paginated-collects-collections`, more than 10 buttons or count/date still present).

- [ ] **Step 3: Commit only if user asks** — skip by default.

---

### Task 2: Controller limit of 10

**Files:**
- Modify: `app/controllers/bullets/collects_controller.rb`

**Interfaces:**
- Consumes: `Current.user.collections.active.matching_name(params[:q]).order(:name)`
- Produces: `@collections` (≤10); no `@collections_page`

- [ ] **Step 1: Implement controller**

```ruby
def new
  @collects_q = params[:q].to_s.strip.presence
  @collections = Current.user.collections
    .active
    .matching_name(params[:q])
    .order(:name)
    .limit(10)

  respond_to do |format|
    format.html
    format.turbo_stream
  end
end
```

Remove private `collectables_page`.

- [ ] **Step 2: Run limit test**

```bash
mise exec -- env -u BUNDLE_PATH bin/rails test test/controllers/bullets/collects_controller_test.rb -n "test_new_returns_at_most_10_collections"
```

Expected: PASS for limit once views still render buttons (may still fail other new tests until Task 3).

---

### Task 3: Views — simplified rows + fixed turbo replace

**Files:**
- Modify: `app/views/bullets/collects/_collection.html.erb`
- Modify: `app/views/bullets/collects/_collections_list.html.erb`
- Modify: `app/views/bullets/collects/_picker.html.erb`
- Modify: `app/views/bullets/collects/new.html.erb`
- Modify: `app/views/bullets/collects/new.turbo_stream.erb`

**Interfaces:**
- Consumes: `collections`, `bullet_ids`, `return_to`, `collects_q` (no `collections_page`)
- Produces: `#collects-collections-list` containing New collection + collection buttons

- [ ] **Step 1: Simplify `_collection.html.erb`**

```erb
<%# locals: (collection:, bullet_ids: "") %>
<li class="bulk-menu--picker-list-item" role="option">
  <%= form_with url: collect_path,
        method: :post,
        class: "dropdown--menu-form",
        data: { turbo_stream: true } do %>
    <%= hidden_field_tag :bullet_ids, bullet_ids, data: { bulk_menu_target: "idList" } %>
    <%= hidden_field_tag :collection_id, collection.id %>
    <button type="submit"
            class="picker--item"
            data-combobox-target="item">
      <%= icon(collection.icon, style: "color: #{colour(collection.colour)};") %>
      <span class="utilities--line-clamp-1"><%= collection.name %></span>
    </button>
  <% end %>
</li>
```

- [ ] **Step 2: Rewrite `_collections_list.html.erb`**

```erb
<%# locals: (bullet_ids:, return_to:, collects_q:, collections:) %>
<div id="collects-collections-list">
  <ul class="bulk-menu--picker-list" role="listbox">
    <li class="bulk-menu--picker-list-item" role="option">
      <%= link_to new_collection_path(bullet_ids: bullet_ids, return_to: return_to),
            class: "picker--item",
            data: {
              turbo_frame: "_top",
              combobox_target: "item"
            } do %>
        <%= icon("plus") %>
        <span class="utilities--line-clamp-1">New collection</span>
      <% end %>
    </li>
    <%= render partial: "bullets/collects/collection",
          collection: collections,
          locals: { bullet_ids: bullet_ids } %>
  </ul>
</div>
```

Note: `collects_q` stays in the locals comment/call sites for consistency with the picker even if unused in the list itself (or drop it from list locals and stop passing it — prefer drop unused local).

Preferred: drop `collects_q` from `_collections_list` locals entirely.

- [ ] **Step 3: Update callers**

`_picker.html.erb` — remove `collections_page:` and `collects_q:` from `collections_list` render if unused:

```erb
<%= render "bullets/collects/collections_list",
      bullet_ids: bullet_ids,
      return_to: return_to,
      collections: collections %>
```

Update locals comment at top of `_picker.html.erb` to drop `collections_page`.

`new.html.erb`:

```erb
<turbo-frame id="collects_picker_dropdown_id" class="bulk-menu--picker bulk-menu--picker--collects" popover>
  <%= render "picker",
        bullet_ids: params[:bullet_ids].to_s,
        return_to: @return_to,
        collects_q: @collects_q,
        collections: @collections %>
</turbo-frame>
```

`new.turbo_stream.erb`:

```erb
<%= turbo_stream.replace "collects-collections-list" do %>
  <%= render "bullets/collects/collections_list",
        bullet_ids: params[:bullet_ids].to_s,
        return_to: @return_to,
        collections: @collections %>
<% end %>
```

- [ ] **Step 4: Run full collects controller tests**

```bash
mise exec -- env -u BUNDLE_PATH bin/rails test test/controllers/bullets/collects_controller_test.rb
```

Expected: all PASS.

- [ ] **Step 5: Commit only if user asks** — skip by default.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Icon + name only | Task 3 |
| Limit 10, no pagination | Task 2 + Task 3 |
| Keep search | unchanged combobox; Task 1/3 turbo target |
| Fix turbo replace (no duplicate New collection) | Task 3 wrapper + stream |
| Tests | Task 1 |

## Self-review

- No placeholders.
- Turbo target id consistent: `collects-collections-list`.
- `collects_q` remains on picker/search form; not required on list partial.
