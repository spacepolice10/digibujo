# User settings — section state, simplified

**Date:** 2026-06-17
**Status:** Approved
**Scope:** Security fix (drop `public_send` and string-interpolated dispatch) + simplify the model layer + split the HTTP route into two action routes + rename columns for clarity. No schema or architectural rework.

## Context

The home page renders four collapsible sections (Logs, Projects, Collections, Spreads) whose open/closed state is persisted per user. The current implementation supports that with:

- a `user_settings` table holding four boolean columns (`logs_open`, `projects_open`, `collections_open`, `spreads_open`)
- a `User::Settings` model with two methods that dispatch on a string key via `public_send` (`section_open?(key)` and `set_section_open(key, value)`)
- a `SECTIONS = %w[logs projects collections spreads]` constant used as the dispatch key set
- a `User::Configurable` concern providing `has_one :settings`, an `after_create :create_settings` callback, and a `settings!` lazy accessor
- a `Home::SectionsController#update` action that PATCHes the section's open state
- a `Section` Stimulus controller that POSTs on every `<details>` toggle

For four booleans, this is more stack than the problem warrants, and two parts of it smell:

1. `public_send("#{key}_open?")` and `public_send("#{key}_open=", value)` rely on the convention that the column name is `"#{key}_open"`. If a section is added to `SECTIONS` but the column is missing, the model raises `NoMethodError` from deep inside ActiveRecord rather than a clear "unknown section" error.
2. `set_section_open` does not validate `SECTIONS` membership at all — the controller does. The model is unsafe to call directly. The current test even asserts the `NoMethodError` fallback, locking in the bad behavior.

The table-based typed-columns design is sound (AGENTS.md requires it; the previous JSON column on `users` was deliberately removed). What we want is the same data shape with less code and no dynamic dispatch.

## Design

### Summary

- **One constant as the single source of truth:** `User::Settings::SECTION_COLUMNS` — a frozen hash mapping section name to boolean column symbol.
- **`SECTIONS` is derived from `SECTION_COLUMNS.keys`** so the two cannot drift.
- **`User::Settings` is gutted to a 1-association model** with the constant and `belongs_to :user`. No methods. Columns are accessed as plain ActiveRecord attributes.
- **`User::Configurable` is deleted.** Its 3 lines fold directly into `User` (`has_one :settings`, `after_create :create_settings`, `def settings!`).
- **Two HTTP routes** replace the single `PATCH /home/sections/:id`:
  - `POST /home/sections/:id/expand`
  - `POST /home/sections/:id/collapse`
- **Columns are renamed** from `*_open` to `*_expanded` so the column name and the action verb agree (`expand_section` ↔ `logs_expanded`).
- **No `public_send` and no string interpolation** anywhere in this flow. Section validation is a hash lookup; column updates are an `update!(column => value)` call.

### File changes

#### `app/models/user/settings.rb` (gut)
```ruby
# frozen_string_literal: true

# rubocop:disable Style/ClassAndModuleChildren
class User::Settings < ApplicationRecord
  SECTION_COLUMNS = {
    "logs"        => :logs_expanded,
    "projects"    => :projects_expanded,
    "collections" => :collections_expanded,
    "spreads"     => :spreads_expanded
  }.freeze
  SECTIONS = SECTION_COLUMNS.keys.freeze

  belongs_to :user
end
# rubocop:enable Style/ClassAndModuleChildren
```

#### `app/models/user.rb` (fold in the concern)
Remove `include User::Configurable`. Add directly:
```ruby
has_one :settings, class_name: 'User::Settings', dependent: :destroy
after_create :create_settings

def settings!
  settings || create_settings!
end
```

#### `app/models/user/configurable.rb` (delete)
The file is removed entirely. Its concerns move into `User`.

#### New migration: `db/migrate/20260617000001_rename_user_settings_columns.rb`
```ruby
class RenameUserSettingsColumns < ActiveRecord::Migration[8.1]
  def change
    rename_column :user_settings, :logs_open,        :logs_expanded
    rename_column :user_settings, :projects_open,    :projects_expanded
    rename_column :user_settings, :collections_open, :collections_expanded
    rename_column :user_settings, :spreads_open,     :spreads_expanded
  end
end
```

#### `config/routes.rb`
Replace the `resources :sections, only: :update, module: :home` block inside the `resource :home` scope with:
```ruby
scope module: :home do
  post 'sections/:id/expand',   to: 'sections#expand',   as: :expand_section
  post 'sections/:id/collapse', to: 'sections#collapse', as: :collapse_section
end
```

#### `app/controllers/home/sections_controller.rb`
`update` is replaced by `expand` and `collapse`. The hash lookup is the only validation step:
```ruby
module Home
  class SectionsController < ApplicationController
    def expand
      update_column(true)
    end

    def collapse
      update_column(false)
    end

    private

    def update_column(value)
      column = User::Settings::SECTION_COLUMNS[params[:id]]
      return head :unprocessable_entity unless column

      Current.user.settings!.update!(column => value)
      head :ok
    end
  end
end
```

#### `app/controllers/home_controller.rb`
Rename `@section_open` → `@section_expanded_status`. The helper uses `SECTION_COLUMNS` directly (no `public_send`):
```ruby
def section_expanded_status
  User::Settings::SECTION_COLUMNS.index_with { |_, column| Current.user.settings![column] }
end
```

#### `app/views/home/show.html.erb`
Rename the `open:` local to `expanded:` and read from `@section_expanded_status`:
```erb
<%= render layout: "home/section", locals: { key: "logs", title: "Logs", expanded: @section_expanded_status["logs"] } do %>
```

#### `app/views/home/_section.html.erb`
Local renamed; values renamed; second value added:
```erb
<details class="home--section" <%= "open".html_safe if expanded %>
        data-controller="section"
        data-section-expand-url-value="<%= home_expand_section_path(key) %>"
        data-section-collapse-url-value="<%= home_collapse_section_path(key) %>">
```

#### `app/javascript/controllers/section_controller.js`
Single `url` value replaced by two values. On toggle, POST to the matching URL.
```js
static values = {
  expandUrl: String,
  collapseUrl: String
};

onToggle() {
  this.persist(this.element.open);
}

persist(open) {
  const url = open ? this.expandUrlValue : this.collapseUrlValue;
  if (!url) return;
  post(url, { body: new FormData() }).catch(() => {});
}
```

### Tests

#### `test/models/user/settings_test.rb`
Gut to the structure-level assertions:
- `SECTION_COLUMNS` has 4 entries
- every value in `SECTION_COLUMNS` corresponds to a real column on `user_settings` (use `User::Settings.column_names`)
- `SECTIONS` matches `SECTION_COLUMNS.keys`
- `belongs_to :user`

The old `section_open?` and `set_section_open` tests are removed — those methods no longer exist on the model.

#### `test/models/user_test.rb`
Add two tests for the folded-in `settings!`:
- `settings!` creates the row when missing
- `settings!` returns the existing row

(The existing `has_one :settings` and `creating a user auto-creates settings` tests stay.)

#### `test/controllers/home/sections_controller_test.rb`
Restructured into `expand` and `collapse` groups. For each:
- persists the right value to the right column
- 422 on unknown section id
- works when no settings row exists (the `settings!` lazy-create path)

#### `test/controllers/home_controller_test.rb`
Update the "show respects collapsed section preferences" test to:
```ruby
@user.settings.update!(spreads_expanded: false)
get home_path
assert_select 'details.home--section[open]', count: 3
```

#### `AGENTS.md`
Update the "User Settings" section to reflect:
- `User::Settings::SECTION_COLUMNS` is the source of truth; `SECTIONS` is derived
- HTTP routes are `POST /home/sections/:id/expand` and `.../collapse`
- No `User::Configurable` concern; `has_one :settings`, `after_create :create_settings`, and `settings!` live on `User`
- Columns are `*_expanded`

## Why not collapse to `users` columns or use `localStorage`?

- **Booleans on `users`** — would shrink the stack one more level, but the dedicated `user_settings` table was a deliberate design decision (AGENTS.md codifies it) and is already there. The simplification we want is at the model/concern level, not the table level.
- **`localStorage`** — would eliminate the server side, but breaks cross-device sync and the AGENTS.md "settings as real columns" rule. Out of scope for a security/cleanup change.

## Risks

1. **Schema/mapping drift.** The hash and the columns are still in two places. A model test that asserts `SECTION_COLUMNS.size == 4` and that every value is a real column on `user_settings` will surface drift. We will add that assertion.
2. **Stimulus empty body.** Today's `persist` posts `FormData` with one field. The new version posts an empty `FormData`. We will confirm with a quick integration test that Rails accepts the empty body (it should — `update_column` reads no params).
3. **Other consumers of the old API.** `set_section_open` and `section_open?` have no callers outside the controller and the test. The model and the home view reference `@section_open` / `@section_open["logs"]` only. A `git grep` confirms no other touch points.

## Out of scope

- Moving booleans to `users`
- Adding new sections (this PR is purely a refactor)
- Replacing the Stimulus controller with `<details name>`/form behavior
- Generalizing `User::Settings` for non-section preferences (deferred until a second use case appears)
