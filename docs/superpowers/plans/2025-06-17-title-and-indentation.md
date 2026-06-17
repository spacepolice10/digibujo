# Title Bulletable Type & Visual Indentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `Title` bulletable type (simple heading, no body) and a boolean `indented` flag for visual nesting in bullet lists.

**Architecture:** Follow the existing `delegated_type` pattern for `Title` (new `titles` table + `Title` model). Add `indented` directly to `bullets`. Update composer, views, CSS, and Stimulus to handle both features.

**Tech Stack:** Rails 8.1.2, SQLite, Minitest, Stimulus, Propshaft, Turbo Streams

---

## File Map

| File | Responsibility |
|------|---------------|
| `db/migrate/20250617_add_indented_to_bullets_and_create_titles.rb` | Add `indented` column to bullets; create `titles` table |
| `app/models/title.rb` | New `Title` model with `Bulletable` |
| `app/models/bullet.rb` | Include `Title` in delegated_type list; relax `body_or_rich_body_present` for Titles |
| `app/controllers/bullets_controller.rb` | Permit `indented` and `bulletable_attributes[:text]` |
| `app/models/bullet_creator.rb` | Permit `indented` and `text` for Title bulletables |
| `app/javascript/controllers/bullet_composer_controller.js` | Toggle body editor / text input / expand button when Title is selected |
| `app/views/bullets/_form_fields.html.erb` | Add indent checkbox; conditional plain text input for Title |
| `app/views/bullets/_bullet.html.erb` | Render Title as heading; add `data-bullet-indented` |
| `app/views/bullets/_compact.html.erb` | Render Title in monthly bucket spread |
| `app/assets/stylesheets/bullet.css` | Style indented margin and Title heading |
| `test/models/title_test.rb` | Title validations |
| `test/controllers/bullets_controller_test.rb` | Create Title bullet; update indented flag |

---

## Task 1: Migration

**Files:**
- Create: `db/migrate/20250617120000_add_indented_to_bullets_and_create_titles.rb`

- [ ] **Step 1: Write migration**

```ruby
class AddIndentedToBulletsAndCreateTitles < ActiveRecord::Migration[8.1]
  def change
    add_column :bullets, :indented, :boolean, default: false, null: false

    create_table :titles do |t|
      t.string :text, null: false
      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Run migration**

Run: `bin/rails db:migrate`
Expected: migration completes without error

- [ ] **Step 3: Commit**

```bash
git add db/migrate/20250617120000_add_indented_to_bullets_and_create_titles.rb db/schema.rb
git commit -m "feat: add indented column to bullets and create titles table"
```

---

## Task 2: Title Model

**Files:**
- Create: `app/models/title.rb`
- Create: `test/models/title_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
# frozen_string_literal: true

require 'test_helper'

class TitleTest < ActiveSupport::TestCase
  test 'validates text presence' do
    title = Title.new(text: '')
    assert_not title.valid?
    assert_includes title.errors[:text], "can't be blank"
  end

  test 'is valid with text' do
    title = Title.new(text: 'My Heading')
    assert title.valid?
  end

  test 'name returns text' do
    title = Title.new(text: 'Hello')
    assert_equal 'Hello', title.name
  end

  test 'temporal? is false' do
    title = Title.new(text: 'X')
    assert_not title.temporal?
  end

  test 'completable? is false' do
    title = Title.new(text: 'X')
    assert_not title.completable?
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/title_test.rb`
Expected: FAIL — `Title` model not found / uninitialized constant

- [ ] **Step 3: Implement Title model**

```ruby
# frozen_string_literal: true

class Title < ApplicationRecord
  include Bulletable

  validates :text, presence: true

  def temporal?      = false
  def completable?   = false
  def marker_icon    = :none
  def marker_styles  = ''
  def name           = text
  def excerpt        = text
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/title_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/title.rb test/models/title_test.rb
git commit -m "feat: add Title bulletable model"
```

---

## Task 3: Update Bullet Model

**Files:**
- Modify: `app/models/bullet.rb`
- Modify: `test/controllers/bullets_controller_test.rb` (will add tests in Task 9)

- [ ] **Step 1: Update delegated_type and validation**

In `app/models/bullet.rb`:

Change line 15 from:
```ruby
  delegated_type :bulletable, types: %w[Task Note Event], dependent: :destroy, optional: true
```
to:
```ruby
  delegated_type :bulletable, types: %w[Task Note Event Title], dependent: :destroy, optional: true
```

Change `body_or_rich_body_present` validation to:

```ruby
  def body_or_rich_body_present
    return if bulletable_type == 'Title'
    return if body.present? || rich_body.present?
    return if attachments.attached?

    errors.add(:body, "can't be blank")
  end
```

- [ ] **Step 2: Run existing tests**

Run: `bin/rails test test/controllers/bullets_controller_test.rb`
Expected: PASS (no regressions)

- [ ] **Step 3: Commit**

```bash
git add app/models/bullet.rb
git commit -m "feat: include Title in bulletable types and relax body validation for Titles"
```

---

## Task 4: Update Controller & Creator Strong Params

**Files:**
- Modify: `app/controllers/bullets_controller.rb`
- Modify: `app/models/bullet_creator.rb`

- [ ] **Step 1: Permit `indented` and `text`**

In `app/controllers/bullets_controller.rb`, change `bullet_params` to:

```ruby
  def bullet_params
    params.require(:bullet).permit(
      :body, :rich_body, :pops_on, :bulletable_type, :bucket_id, :indented,
      attachments: [],
      bulletable_attributes: %i[text mood awaits_research idea]
    )
  end
```

In `app/controllers/bullets_controller.rb`, change `update_bulletable!` to:

```ruby
  def update_bulletable!(bullet)
    attrs = params.dig(:bullet, :bulletable_attributes)
    return unless attrs.present?
    return unless bullet.bulletable.is_a?(Note) || bullet.bulletable.is_a?(Title)

    permitted = if bullet.bulletable.is_a?(Note)
                  attrs.permit(:mood, :awaits_research, :idea)
                else
                  attrs.permit(:text)
                end

    bullet.bulletable.update!(permitted)
  end
```

In `app/models/bullet_creator.rb`, change `update_bulletable!` to:

```ruby
  def update_bulletable!
    attrs = @params[:bulletable_attributes]
    return unless attrs.present?
    return unless @bullet.bulletable.is_a?(Note) || @bullet.bulletable.is_a?(Title)

    permitted = if @bullet.bulletable.is_a?(Note)
                  attrs.permit(:mood, :awaits_research, :idea)
                else
                  attrs.permit(:text)
                end

    @bullet.bulletable.update!(permitted)
  end
```

- [ ] **Step 2: Run existing tests**

Run: `bin/rails test test/controllers/bullets_controller_test.rb`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add app/controllers/bullets_controller.rb app/models/bullet_creator.rb
git commit -m "feat: permit indented and title text in bullet params"
```

---

## Task 5: Update Composer View

**Files:**
- Modify: `app/views/bullets/_form_fields.html.erb`

- [ ] **Step 1: Add indent checkbox and Title text input**

In `_form_fields.html.erb`, after the `bullet-form-type-row` div (around line 39), add:

```erb
  <label class="bullet-form-indent-option">
    <%= f.check_box :indented %>
    <span>Indent</span>
  </label>
```

Wrap the `body` rich-text editor (lines 41–59) in a conditional div:

```erb
  <div class="bullet-form-body-editor" data-bullet-composer-target="bodyEditor">
    <%= f.rich_text_area :body,
          value: editor_value,
          autofocus: !editing,
          placeholder: "What's on your mind?",
          multiline: false,
          preset: "inline" do %>
      <lexxy-prompt trigger="#"
                    name="project"
                    src="<%= project_suggestions_path %>"
                    remote-filtering
                    supports-space-in-searches>
      </lexxy-prompt>
      <lexxy-prompt trigger="@"
                    name="person"
                    src="<%= person_suggestions_path %>"
                    remote-filtering
                    supports-space-in-searches>
      </lexxy-prompt>
    <% end %>
  </div>
```

Add a plain text input for Title (after the body editor div):

```erb
  <div class="bullet-form-title-input" data-bullet-composer-target="titleInput" hidden>
    <% title_form = bullet.bulletable.is_a?(Title) ? bullet.bulletable : Title.new %>
    <%= f.fields_for :bulletable, title_form do |tf| %>
      <%= tf.text_field :text, placeholder: "Heading text…", class: "bullet-form-title-text" %>
    <% end %>
  </div>
```

Hide Expand button when Title is selected. Wrap the Expand button (lines 68–73) in a conditional:

```erb
    <button type="button"
            class="button--secondary"
            commandfor="<%= expand_dialog_id %>"
            command="show-modal"
            data-bullet-composer-target="expandButton">
      Expand
    </button>
```

- [ ] **Step 2: Verify view renders without error**

Start server or open a daylog page in browser and ensure composer loads.

- [ ] **Step 3: Commit**

```bash
git add app/views/bullets/_form_fields.html.erb
git commit -m "feat: add indent checkbox and Title text input to composer"
```

---

## Task 6: Update Stimulus Controller

**Files:**
- Modify: `app/javascript/controllers/bullet_composer_controller.js`

- [ ] **Step 1: Add Title to TYPE_MARKERS and new targets**

Add to `static targets` array:
```js
  "bodyEditor",
  "titleInput",
  "expandButton",
```

Update `TYPE_MARKERS`:
```js
const TYPE_MARKERS = {
  Task: { icon: "square", styles: "bullet--task-marker" },
  Note: { icon: "line-dashed", styles: "bullet--note-marker" },
  Event: { icon: "circle", styles: "bullet--event-marker" },
  Title: { icon: "none", styles: "" },
}
```

Update `updateTypeUi()`:

```js
  updateTypeUi() {
    if (!this.hasTypeSelectTarget) return

    const type = this.typeSelectTarget.value
    const marker = TYPE_MARKERS[type] || TYPE_MARKERS.Task
    const isTitle = type === "Title"

    if (this.hasMarkerTarget) {
      this.markerTarget.className = `bullet--marker ${marker.styles}`
    }
    if (this.hasMarkerIconTarget) {
      this.markerIconTarget.style.setProperty("--icon-mask", `var(--icon-${marker.icon})`)
    }
    if (this.hasNoteOptionsTarget) {
      this.noteOptionsTarget.hidden = type != "Note"
    }
    if (this.hasBodyEditorTarget) {
      this.bodyEditorTarget.hidden = isTitle
    }
    if (this.hasTitleInputTarget) {
      this.titleInputTarget.hidden = !isTitle
    }
    if (this.hasExpandButtonTarget) {
      this.expandButtonTarget.hidden = isTitle
    }
  }
```

Update `reset()` so it doesn't try to clear `trix-editor` for Title (already safe, but ensure focus goes to title input when Title is selected):

```js
    const inlineEditor = this.element.querySelector('trix-editor[preset="inline"]')
    if (inlineEditor?.editor) {
      inlineEditor.editor.setSelectedRange([0, 0])
      inlineEditor.focus()
    }

    const titleText = this.element.querySelector('.bullet-form-title-text')
    if (titleText && !this.hasBodyEditorTarget?.hidden) {
      titleText.focus()
    }
```

(Actually, the existing reset focuses the inline editor. We can leave it — when Title is selected the inline editor is hidden and focus is harmless. If desired, add conditional focus to title input.)

- [ ] **Step 2: Verify in browser**

Open daylog, switch type to Title, confirm body editor hides and text input appears.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/bullet_composer_controller.js
git commit -m "feat: toggle body editor and expand button for Title type in composer"
```

---

## Task 7: Update Bullet Partial

**Files:**
- Modify: `app/views/bullets/_bullet.html.erb`

- [ ] **Step 1: Add indented data attribute and Title branch**

Add `data-bullet-indented` to the turbo-frame tag:

```erb
<turbo-frame id="<%= dom_id(bullet) %>"
             class="bullet<%= " bullet--monthly-bucket" if monthly_bucket %>"
             data-bullet-type="<%= bullet.bulletable_type.downcase %>"
             data-bullet-indented="<%= bullet.indented %>"
```

Replace the inner body block (around lines 25–53) with a conditional for Title:

```erb
  <div class="bullet--body">
    <% if bullet.bulletable_type == "Title" %>
      <h3 class="bullet--title"><%= bullet.name %></h3>
    <% elsif monthly_bucket %>
      <span class="bullet--line"><%= bullet.name %></span>
    <% else %>
      <% if bullet.body.to_plain_text.presence || bullet.rich_body? %>
        <div class="bullet--name">
          <% if bullet.bulletable_type == "Note" %>
            <%= link_to bullet.excerpt, bullet_path(bullet), data: { turbo_frame: "_top" } %>
          <% else %>
            <%= link_to bullet.body, bullet_path(bullet), data: { turbo_frame: "_top" } %>
          <% end %>

          <% if bullet.attachments.attached? %>
            <span class="pill" aria-label="Has attachments">
              <i class="icon" style="--icon-mask: var(--icon-paperclip)" aria-hidden="true"></i>
            </span>
          <% end %>
          <% if bullet.meta_labels.any? %>
            <span class="bullet--flags">
              <% bullet.meta_labels.each do |label| %>
                <span class="pill pill--<%= label[:colour] %>"><%= label[:emoji] %></span>
              <% end %>
            </span>
          <% end %>
        </div>
      <% end %>
      <%= render "bullets/attachments", bullet: bullet %>
      <%= render "bullets/metadata", bullet: bullet %>
    <% end %>
  </div>
```

- [ ] **Step 2: Verify in browser**

Create a Title bullet and an indented bullet; confirm rendering.

- [ ] **Step 3: Commit**

```bash
git add app/views/bullets/_bullet.html.erb
git commit -m "feat: render Title as heading and support indented bullets"
```

---

## Task 8: Update Compact Partial

**Files:**
- Modify: `app/views/bullets/_compact.html.erb`

- [ ] **Step 1: Handle Title in monthly bucket spread**

Wrap the marker rendering in a conditional:

```erb
    <% unless bullet.bulletable_type == "Title" %>
      <span class="bullet--marker bullet-compact--marker <%= bullet.marker_styles %>" aria-hidden="true">
        <i class="icon" style="--icon-mask: var(--icon-<%= bullet.marker_icon %>)"></i>
        <% if bullet.mood_marker.present? %>
          <span class="bullet--mood-emoji"><%= bullet.mood_marker %></span>
        <% end %>
      </span>
    <% end %>
```

Make the name span bold for Titles:

```erb
    <span class="bullet-compact--name utilities--line-clamp-1<%= " bullet-compact--title" if bullet.bulletable_type == "Title" %>"><%= bullet.excerpt %></span>
```

- [ ] **Step 2: Add compact title style in CSS**

In `app/assets/stylesheets/bullet.css`, inside the `@layer components` block:

```css
  .bullet-compact--title {
    font-weight: var(--font-weight-bold);
  }
```

- [ ] **Step 3: Commit**

```bash
git add app/views/bullets/_compact.html.erb app/assets/stylesheets/bullet.css
git commit -m "feat: render Title in monthly bucket spread without marker"
```

---

## Task 9: Add CSS Styles

**Files:**
- Modify: `app/assets/stylesheets/bullet.css`

- [ ] **Step 1: Add indented margin and Title heading styles**

In `app/assets/stylesheets/bullet.css`, inside the `@layer components` block:

```css
  .bullet[data-bullet-indented="true"] {
    padding-inline-start: 2rem;
  }

  .bullet--title {
    margin: 0;
    font-size: var(--font-size-large);
    font-weight: var(--font-weight-bold);
    color: var(--color-fg-base);
  }
```

(Use the nearest existing CSS variables from `variables.css`. If `2rem` is too large, map to the closest spacing variable.)

- [ ] **Step 2: Verify in browser**

Confirm indented bullets shift right and Title bullets appear as large headings.

- [ ] **Step 3: Commit**

```bash
git add app/assets/stylesheets/bullet.css
git commit -m "feat: add CSS for indented bullets and Title headings"
```

---

## Task 10: Controller/Integration Tests

**Files:**
- Modify: `test/controllers/bullets_controller_test.rb`

- [ ] **Step 1: Add tests for Title creation and indentation**

Append to `test/controllers/bullets_controller_test.rb`:

```ruby
  test 'create Title bullet without body' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Title',
             bulletable_attributes: { text: 'My Heading' },
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    assert_response :success
    bullet = @user.bullets.order(:created_at).last
    assert_equal 'Title', bullet.bulletable_type
    assert_equal 'My Heading', bullet.name
    assert_not bullet.body.present?
  end

  test 'update indented flag' do
    patch bullet_path(@bullet),
          params: { bullet: { indented: true } },
          as: :turbo_stream

    assert_response :success
    assert @bullet.reload.indented
  end

  test 'create indented bullet' do
    post bullets_path,
         params: {
           bullet: {
             bulletable_type: 'Task',
             body: 'Indented task',
             indented: true,
             pops_on: Date.current.iso8601
           }
         },
         as: :turbo_stream

    assert_response :success
    bullet = @user.bullets.order(:created_at).last
    assert bullet.indented
  end
```

- [ ] **Step 2: Run new tests**

Run: `bin/rails test test/controllers/bullets_controller_test.rb`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/controllers/bullets_controller_test.rb
git commit -m "test: cover Title creation and indentation in bullets controller"
```

---

## Task 11: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 2: Run linter**

Run: `bin/rubocop`
Expected: No offenses

- [ ] **Step 3: Commit any fixes**

```bash
git commit -am "fix: rubocop / test cleanup" || echo "nothing to fix"
```

---

## Spec Coverage Check

| Spec Requirement | Task |
|------------------|------|
| `indented` boolean on bullets | Task 1 |
| `titles` table | Task 1 |
| `Title` model with Bulletable | Task 2 |
| Bullet delegated_type includes Title | Task 3 |
| Bullet skips body validation for Title | Task 3 |
| Indent checkbox in composer | Task 5 |
| Title shows plain text input, hides body/expand | Task 5, 6 |
| Title renders as heading in timeline | Task 7 |
| Title renders in monthly bucket spread | Task 8 |
| Indented bullets have visual margin | Task 7, 9 |
| Titles participate in bulk actions | Task 7 (checkbox kept) |
| Controller permits new params | Task 4 |
| Tests for Title and indentation | Task 10 |

**No gaps found.**

## Placeholder Scan

- No "TBD", "TODO", or vague steps.
- Every task contains exact file paths, code, and commands.
- Type names (`Title`, `indented`, `text`) are consistent throughout.
