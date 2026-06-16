# Unified Bullet Composer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify bullet composer across all views: single turbo-stream template, `before targets:` with `bullet_pops_on_<date>` class, nested routes for monthly bucket, BulletCreator service, extracted `_form_fields` partial.

**Architecture:** BulletCreator PORO handles creation logic (build, save, finalize). `_form_fields` partial extracted from `_bulletable_form`. Monthly bucket gets its own nested controller with compact bullet partial. All composer frames carry `bullet_pops_on_<date>` class; the unified template does `turbo_stream.before targets:` targeting that class.

**Tech Stack:** Rails 8.1, Turbo Streams, Stimulus, Minitest

---

### Task 1: BulletCreator service

**Files:**
- Create: `app/services/bullet_creator.rb`
- Test: `test/services/bullet_creator_test.rb`

- [ ] **Step 1: Write the service**

```ruby
# frozen_string_literal: true

class BulletCreator
  attr_reader :bullet

  def initialize(user, params)
    @user = user
    @params = params
  end

  def call
    build_bullet
    if @bullet.save
      update_bulletable!
      finalize_content!
      @bullet.reload
    end
    self
  end

  def success?
    @bullet.errors.none?
  end

  private

  def build_bullet
    type_name = @params[:bulletable_type].presence || 'Task'
    attributes = @params.except(:bulletable_type, :bulletable_attributes, :render_context, :monthly_bucket_id)
    @bullet = @user.bullets.new(attributes.merge(bulletable: type_name.constantize.new))
  end

  def update_bulletable!
    attrs = @params[:bulletable_attributes]
    return unless attrs.present? && @bullet.bulletable.is_a?(Note)

    @bullet.bulletable.update!(attrs.permit(:mood, :awaits_research, :idea))
  end

  def finalize_content!
    body_record = ActionText::RichText.find_by(record: @bullet, name: 'body')
    @bullet.apply_project_tags_from_content!(rich_text_record: body_record) if body_record
    @bullet.apply_people_tags_from_content!(rich_text_record: body_record) if body_record
    @bullet.sanitize_rich_body_tag_attachables!
    purge_blank_rich_body!
  end

  def purge_blank_rich_body!
    return unless @bullet.rich_body.blank?

    ActionText::RichText.find_by(record: @bullet, name: 'rich_body')&.destroy
  end
end
```

- [ ] **Step 2: Write service test**

```ruby
# frozen_string_literal: true

require 'test_helper'

class BulletCreatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test 'creates bullet with default type' do
    result = BulletCreator.new(@user, { body: 'Test body', pops_on: Date.current.iso8601 }).call
    assert result.success?
    assert_equal 'Task', result.bullet.bulletable_type
    assert_equal 'Test body', result.bullet.body.to_plain_text
  end

  test 'creates bullet with specified type' do
    result = BulletCreator.new(@user, { bulletable_type: 'Note', body: 'A note', mood: 'positive' }).call
    assert result.success?
    assert_equal 'Note', result.bullet.bulletable_type
    assert_equal 'positive', result.bullet.bulletable.mood
  end

  test 'creates bullet with bucket_id' do
    collection = create_collection!(@user, name: 'Test')
    result = BulletCreator.new(@user, { bulletable_type: 'Task', body: 'Collected', bucket_id: collection.bucket.id }).call
    assert result.success?
    assert_equal collection.bucket.id, result.bullet.bucket_id
  end

  test 'tags project from body attachment' do
    project = create_project!(@user, name: 'Tagged')
    body_html = ActionText::Content.new('').append_attachables(project).to_html
    result = BulletCreator.new(@user, { bulletable_type: 'Task', body: body_html }).call
    assert result.success?
    assert_includes result.bullet.projects, project
  end

  test 'fails with validation error' do
    result = BulletCreator.new(@user, { bulletable_type: 'Task', body: '' }).call
    assert_not result.success?
    assert result.bullet.errors[:body].any?
  end

  test 'purges blank rich_body' do
    result = BulletCreator.new(@user, { bulletable_type: 'Task', body: 'Only body', rich_body: '' }).call
    assert result.success?
    assert_not result.bullet.rich_body?
  end
end
```

- [ ] **Step 3: Run tests**

Run: `bin/rails test test/services/bullet_creator_test.rb`
Expected: all pass

- [ ] **Step 4: Commit**

```bash
git add app/services/bullet_creator.rb test/services/bullet_creator_test.rb
git commit -m "feat: add BulletCreator service object"
```

---

### Task 2: Extract `_form_fields` partial

**Files:**
- Create: `app/views/bullets/_form_fields.html.erb`
- Modify: `app/views/bullets/_bulletable_form.html.erb`

- [ ] **Step 1: Create `_form_fields.html.erb`**

The shared form body — everything between `form_with do |f|` and `end`:

```erb
<%# locals: (f:, bullet:, submitted_attributes: {}, default_project: nil, default_person: nil, editing: false) %>
<% editor_value = bullet.editor_content(default_projects: Array(default_project).compact, default_people: Array(default_person).compact) %>
<% expand_dialog_id = dom_id(bullet, :expand) %>
<% type_name = bullet.bulletable_type.presence || "Task" %>
<% bulletable_form = bullet.bulletable || type_name.constantize.new %>

<% bullet_column_names = %w[pops_on bucket_id] %>
<% submitted_attributes.each do |name, value| %>
  <% if bullet_column_names.include?(name.to_s) %>
    <%= f.hidden_field name, value: value %>
  <% else %>
    <%= hidden_field_tag "bullet[#{name}]", value %>
  <% end %>
<% end %>

<div class="bullet-form-composer">
  <div class="bullet-form-type-row">
    <% if editing %>
      <%= f.hidden_field :bulletable_type %>
    <% else %>
      <%= f.select :bulletable_type,
            Bullet.bulletable_types,
            { selected: type_name },
            class: "bullet-form-type-select",
            data: {
              bullet_composer_target: "typeSelect",
              action: "change->bullet-composer#typeChanged"
            } %>
    <% end %>

    <span class="bullet--marker <%= bullet.marker_styles %>"
          data-bullet-composer-target="marker"
          aria-hidden="true">
      <i class="icon"
         style="--icon-mask: var(--icon-<%= bullet.marker_icon %>)"
         data-bullet-composer-target="markerIcon"
         aria-hidden="true"></i>
    </span>
  </div>

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

  <div class="bullet-form-actions">
    <button type="button"
            class="button--secondary button--icon"
            data-action="bullet-composer#pickFile"
            aria-label="Add attachment">
      <i class="icon" style="--icon-mask: var(--icon-paperclip)" aria-hidden="true"></i>
    </button>
    <button type="button"
            class="button--secondary"
            commandfor="<%= expand_dialog_id %>"
            command="show-modal">
      Expand
    </button>
    <input type="file"
           multiple
           class="utilities--sr-only"
           data-bullet-composer-target="fileInput"
           data-action="change->bullet-composer#fileInputChanged">
  </div>

  <div class="bullet-form-note-options"
       data-bullet-composer-target="noteOptions"
       <%= "hidden" unless type_name == "Note" %>>
    <% note_form = bullet.bulletable.is_a?(Note) ? bullet.bulletable : Note.new %>
    <%= f.fields_for :bulletable, note_form do |nf| %>
      <div class="mood-picker">
        <% moods = { positive: "😊", negative: "😞", inspired: "✨", frustrated: "😣" } %>
        <% moods.each do |name, emoji| %>
          <label class="mood-option">
            <%= nf.radio_button :mood, name, class: "utilities--sr-only" %>
            <span class="mood_marker"><%= emoji %></span>
          </label>
        <% end %>
      </div>
      <div class="flag-picker">
        <label class="flag-option">
          <%= nf.check_box :awaits_research %>
          <span>Research</span>
        </label>
        <label class="flag-option">
          <%= nf.check_box :idea %>
          <span>Idea</span>
        </label>
      </div>
    <% end %>
  </div>
</div>

<div class="attachment--previews"
     data-bullet-composer-target="previews"
     hidden></div>

<div data-bullet-composer-target="attachmentsField"></div>

<div class="bullet-form-footer">
  <%= f.button type: "submit", class: "button--primary button--icon" do %>
    <i class="icon" style="--icon-mask: var(--icon-arrow-up)" aria-hidden="true"></i>
  <% end %>
</div>

<%= render "shared/dialog", id: expand_dialog_id, data_target: "expandDialog" do %>
  <div class="bullet-form-expand">
    <h2 class="bullet-form-expand-title">Expanded content</h2>
    <%= f.rich_text_area :rich_body,
          placeholder: "Code, files, markdown…",
          preset: "expand" %>
    <div class="bullet-form-expand-footer">
      <button type="button"
              class="button--secondary"
              commandfor="<%= expand_dialog_id %>"
              command="close">
        Cancel
      </button>
      <button type="button"
              class="button--primary"
              data-action="bullet-composer#submitExpand">
        Save
      </button>
    </div>
  </div>
<% end %>
```

- [ ] **Step 2: Simplify `_bulletable_form.html.erb`**

Replace with a thin wrapper using `url:` override:

```erb
<%# locals: (bullet:, attributes: {}, default_project: nil, default_person: nil, editing: false, url: nil) %>
<% editor_id = "bullet_editor_#{bullet.object_id}" %>

<%= form_with model: bullet,
      url: url.presence,
      namespace: editor_id,
      class: "bullet-form",
      data: {
        controller: "bullet-composer",
        bullet_composer_direct_upload_url_value: rails_direct_uploads_url,
        action: "keydown->bullet-composer#handleKeydown"
      } do |f| %>

  <%= render "bullets/form_fields",
        f: f,
        bullet: bullet,
        submitted_attributes: attributes.compact,
        default_project: default_project,
        default_person: default_person,
        editing: editing %>
<% end %>
```

- [ ] **Step 3: Commit**

```bash
git add app/views/bullets/_form_fields.html.erb app/views/bullets/_bulletable_form.html.erb
git commit -m "refactor: extract _form_fields from _bulletable_form, add url: override"
```

---

### Task 3: Simplify BulletsController

**Files:**
- Modify: `app/controllers/bullets_controller.rb`

- [ ] **Step 1: Remove context plumbing, use BulletCreator**

Replace `create`, `create_bullet_from`, `update_bulletable!`, `finalize_bullet_content!`, `purge_blank_rich_body!`, `render_create_turbo_stream`, `create_turbo_stream_variant?` with:

```ruby
# frozen_string_literal: true

class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]

  def new
    @bullet = Current.user.bullets.build(
      pops_on: params[:pops_on],
      bucket_id: params[:bucket_id]
    )
    type_name = params[:bulletable_type].presence || 'Task'
    @bullet.bulletable_type = type_name
    @bullet.bulletable = type_name.constantize.new
    @default_project_id = params[:default_project_id]
    @default_person_id = params[:default_person_id]
  end

  def create
    result = BulletCreator.new(Current.user, bullet_params).call
    @bullet = result.bullet
    if result.success?
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render_invalid_create }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def show; end

  def update
    if @bullet.update(bullet_params.except(:bulletable_attributes))
      update_bulletable!(@bullet)
      finalize_bullet_content!(@bullet)
      BulletActivityRecorder.record_updated!(bullet: @bullet)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bullet.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to daylog_path(date: (@bullet.pops_on || Date.current).iso8601) }
    end
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:id])
  end

  def bullet_params
    params.require(:bullet).permit(
      :body, :rich_body, :pops_on, :bulletable_type, :bucket_id,
      attachments: [],
      bulletable_attributes: %i[mood awaits_research idea]
    )
  end

  def update_bulletable!(bullet)
    attrs = params.dig(:bullet, :bulletable_attributes)
    return unless attrs.present? && bullet.bulletable.is_a?(Note)

    bullet.bulletable.update!(attrs.permit(:mood, :awaits_research, :idea))
  end

  def finalize_bullet_content!(bullet)
    body_record = ActionText::RichText.find_by(record: bullet, name: 'body')
    bullet.apply_project_tags_from_content!(rich_text_record: body_record) if body_record
    bullet.apply_people_tags_from_content!(rich_text_record: body_record) if body_record
    bullet.sanitize_rich_body_tag_attachables!
    purge_blank_rich_body!(bullet)
  end

  def purge_blank_rich_body!(bullet)
    return unless bullet.rich_body.blank?

    ActionText::RichText.find_by(record: bullet, name: 'rich_body')&.destroy
  end

  def render_invalid_create
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: @bullet.errors.full_messages }
    )
  end
end
```

- [ ] **Step 2: Run tests**

Run: `bin/rails test test/controllers/bullets_controller_test.rb`
Expected: all pass (besides the create test asserting old update targeting — will update in Task 9)

- [ ] **Step 3: Commit**

```bash
git add app/controllers/bullets_controller.rb
git commit -m "refactor: use BulletCreator, remove render_context plumbing"
```

---

### Task 4: Create unified `bullets/create.turbo_stream.erb`

**Files:**
- Modify: `app/views/bullets/create.turbo_stream.erb`

- [ ] **Step 1: Replace with unified template**

```erb
<%= turbo_stream.before targets: ".bullet_pops_on_#{@bullet.pops_on}" do %>
  <%= render @bullet %>
<% end %>

<% if @bullet.pops_on.present? && @bullet.pops_on > Date.current %>
<%= turbo_stream.update "toasts" do %>
    <%= render "shared/toasts", type: "notify", messages: ["Scheduled for #{@bullet.pops_on.strftime('%B %d')}"] %>
<% end %>
<% end %>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/bullets/create.turbo_stream.erb
git commit -m "feat: unified turbo stream template using before targets"
```

---

### Task 5: Delete variant turbo stream templates

**Files:**
- Delete: `app/views/bullets/create.monthly_bucket_by_date.turbo_stream.erb`
- Delete: `app/views/bullets/create.monthly_bucket_unplanned.turbo_stream.erb`
- Delete: `app/views/bullets/create.project.turbo_stream.erb`

- [ ] **Step 1: Delete files**

Run: `git rm app/views/bullets/create.monthly_bucket_by_date.turbo_stream.erb app/views/bullets/create.monthly_bucket_unplanned.turbo_stream.erb app/views/bullets/create.project.turbo_stream.erb`

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: delete variant turbo stream templates"
```

---

### Task 6: Add `bullet_pops_on_` class to daylog, collection, project views

**Files:**
- Modify: `app/views/daylogs/show.html.erb`
- Modify: `app/views/collections/show.html.erb`
- Modify: `app/views/projects/show.html.erb`

- [ ] **Step 1: Update daylog composer frame**

```diff
- <turbo-frame id="bullet_composer">
+ <turbo-frame id="bullet_composer" class="bullet_pops_on_<%= @selected_date %>">
```

- [ ] **Step 2: Update collection composer frame**

```diff
- <turbo-frame id="bullet_composer">
+ <turbo-frame id="bullet_composer" class="bullet_pops_on_">
```

- [ ] **Step 3: Update project composer frame**

```diff
- <turbo-frame id="bullet_composer">
+ <turbo-frame id="bullet_composer" class="bullet_pops_on_">
```

- [ ] **Step 4: Commit**

```bash
git add app/views/daylogs/show.html.erb app/views/collections/show.html.erb app/views/projects/show.html.erb
git commit -m "feat: add bullet_pops_on_ classes to composer frames"
```

---

### Task 7: Create MonthlyBuckets::BulletsController

**Files:**
- Create: `app/controllers/monthly_buckets/bullets_controller.rb`
- Create: `app/views/monthly_buckets/bullets/new.html.erb`
- Create: `app/views/monthly_buckets/bullets/create.turbo_stream.erb`
- Create: `app/views/monthly_buckets/bullets/_bullet.html.erb`

- [ ] **Step 1: Create the controller**

```ruby
# frozen_string_literal: true

module MonthlyBuckets
  class BulletsController < ApplicationController
    before_action :set_monthly_bucket

    def new
      @bullet = Current.user.bullets.build(
        pops_on: params[:pops_on],
        bucket_id: @monthly_bucket.bucket.id
      )
      @bullet.bulletable_type = params[:bulletable_type].presence || 'Task'
      @bullet.bulletable = @bullet.bulletable_type.constantize.new
    end

    def create
      result = BulletCreator.new(Current.user, bullet_params.merge(
        bucket_id: @monthly_bucket.bucket.id
      )).call
      @bullet = result.bullet
      @monthly_bucket
      if result.success?
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to monthly_bucket_path(@monthly_bucket) }
        end
      else
        respond_to do |format|
          format.turbo_stream { render_invalid_create }
          format.html { render :new, status: :unprocessable_entity }
        end
      end
    end

    private

    def set_monthly_bucket
      @monthly_bucket = Current.user.monthly_buckets.find(params[:monthly_bucket_id])
    end

    def bullet_params
      params.require(:bullet).permit(
        :body, :rich_body, :pops_on, :bulletable_type, :bucket_id,
        attachments: [],
        bulletable_attributes: %i[mood awaits_research idea]
      )
    end

    def render_invalid_create
      render turbo_stream: turbo_stream.update(
        'toasts',
        partial: 'shared/toasts',
        locals: { type: 'errmsg', messages: @bullet.errors.full_messages }
      )
    end
  end
end
```

- [ ] **Step 2: Create `new.html.erb`**

No turbo-frame wrapper — loads inside the per-date `_self` frame:

```erb
<%= render "bullets/bulletable_form",
      bullet: @bullet,
      url: monthly_bucket_bullets_path(@monthly_bucket),
      attributes: { pops_on: @bullet.pops_on, bucket_id: @bullet.bucket_id }.compact %>
```

- [ ] **Step 3: Create `create.turbo_stream.erb`**

```erb
<%= turbo_stream.before targets: ".bullet_pops_on_#{@bullet.pops_on}" do %>
  <%= render "monthly_buckets/bullets/bullet", bullet: @bullet %>
<% end %>
```

- [ ] **Step 4: Create `_bullet.html.erb`**

Compact, draggable, no checkbox — like current `monthly_bucket: true`:

```erb
<%# locals: (bullet:) %>
<turbo-frame id="<%= dom_id(bullet) %>"
             class="bullet bullet--monthly-bucket"
             data-bullet-type="<%= bullet.bulletable_type.downcase %>"
             <% if bullet.completed? %>
             data-bullet-completed
             <% end %>
             draggable="true"
             data-controller="bullet-drag"
             data-bullet-drag-id-value="<%= bullet.id %>"
             data-action="dragstart->bullet-drag#dragstart dragend->bullet-drag#dragend">
  <div class="bullet--marker-slot">
    <span class="bullet--marker <%= bullet.marker_styles %>" aria-hidden="true">
      <i class="icon" style="--icon-mask: var(--icon-<%= bullet.marker_icon %>)" aria-hidden="true"></i>
      <% if bullet.mood_marker.present? %>
        <span class="bullet--mood-emoji"><%= bullet.mood_marker %></span>
      <% end %>
    </span>
  </div>
  <div class="bullet--body">
    <span class="bullet--line"><%= bullet.name %></span>
  </div>
</turbo-frame>
```

- [ ] **Step 5: Create `app/controllers/monthly_buckets/bullets_controller.rb` directory structure**

Run: `mkdir -p app/views/monthly_buckets/bullets`

- [ ] **Step 6: Commit**

```bash
git add app/controllers/monthly_buckets/bullets_controller.rb app/views/monthly_buckets/bullets/
git commit -m "feat: add monthly bucket nested bullets controller with compact bullet partial"
```

---

### Task 8: Update monthly_buckets show and composer

**Files:**
- Modify: `app/views/monthly_buckets/show.html.erb`
- Delete: `app/views/monthly_buckets/_day_composer.html.erb`

- [ ] **Step 1: Update `show.html.erb`**

Move composer frames inside `monthly-bucket--date-entries`, add `bullet_pops_on_` class, use nested route:

```erb
<% content_for(:title) { @monthly_bucket.name } %>

<div class="layout--page monthly-bucket--page">
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

  <div class="monthly-bucket--spread">
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
                 data-controller="monthly-bucket-drop"
                 data-monthly-bucket-drop-pop-url-value="<%= pop_path %>"
                 data-monthly-bucket-drop-pops-on-value="<%= date.iso8601 %>"
                 data-action="dragover->monthly-bucket-drop#dragover dragleave->monthly-bucket-drop#dragleave drop->monthly-bucket-drop#drop">
              <% (@bullets_by_date[date] || []).each do |bullet| %>
                <%= render "monthly_buckets/bullets/bullet", bullet: bullet %>
              <% end %>
              <turbo-frame class="bullet_pops_on_<%= date %>" id="composer_<%= date.iso8601 %>">
                <%= link_to new_monthly_bucket_bullet_path(@monthly_bucket, pops_on: date.iso8601),
                      data: { turbo_frame: "_self" },
                      class: "button--tertiary button--icon",
                      aria: { label: "Add to #{date.strftime('%B %-d')}" } do %>
                  <i class="icon" style="--icon-mask: var(--icon-plus)" aria-hidden="true"></i>
                <% end %>
              </turbo-frame>
            </div>
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
           data-controller="monthly-bucket-drop"
           data-monthly-bucket-drop-pop-url-value="<%= pop_path %>"
           data-action="dragover->monthly-bucket-drop#dragover dragleave->monthly-bucket-drop#dragleave drop->monthly-bucket-drop#drop">
        <% @unplanned_bullets.each do |bullet| %>
          <%= render "monthly_buckets/bullets/bullet", bullet: bullet %>
        <% end %>
        <turbo-frame class="bullet_pops_on_" id="composer_unplanned">
          <%= link_to new_monthly_bucket_bullet_path(@monthly_bucket),
                data: { turbo_frame: "_self" },
                class: "button--tertiary button--icon",
                aria: { label: "Add bullet" } do %>
            <i class="icon" style="--icon-mask: var(--icon-plus)" aria-hidden="true"></i>
          <% end %>
        </turbo-frame>
      </div>
    </section>
  </div>
</div>
```

- [ ] **Step 2: Delete `_day_composer.html.erb`**

Run: `git rm app/views/monthly_buckets/_day_composer.html.erb`

- [ ] **Step 3: Commit**

```bash
git add app/views/monthly_buckets/
git commit -m "feat: restructure monthly bucket show with nested routes and bullet_pops_on_ classes"
```

---

### Task 9: Update routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add nested bullets under monthly_buckets**

```diff
- resources :monthly_buckets, only: %i[show new create]
+ resources :monthly_buckets, only: %i[show new create] do
+   resources :bullets, only: %i[new create],
+            controller: "monthly_buckets/bullets"
+ end
```

- [ ] **Step 2: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add nested bullets routes under monthly_buckets"
```

---

### Task 10: Update integration tests

**Files:**
- Modify: `test/controllers/bullets_controller_test.rb`

- [ ] **Step 1: Update create test — no longer asserts update/reset of composer**

```ruby
test 'create turbo stream inserts bullet before composer' do
  collection = create_collection!(@user, name: 'Fresh collection')

  post bullets_path,
       params: {
         bullet: {
           bulletable_type: 'Task',
           body: 'Fresh task',
           pops_on: Date.current.iso8601,
           bucket_id: collection.bucket.id
         }
       },
       as: :turbo_stream

  assert_response :success
  assert_match(/turbo-stream action="before" targets="\.bullet_pops_on_#{Date.current.iso8601}"/, response.body)
  assert_match(/Fresh task/, response.body)
end
```

- [ ] **Step 2: Run tests**

Run: `bin/rails test test/controllers/bullets_controller_test.rb`
Expected: all pass

- [ ] **Step 3: Commit**

```bash
git add test/controllers/bullets_controller_test.rb
git commit -m "test: update create test for unified template targeting"
```

---

### Task 11: Run full test suite

- [ ] **Step 1: Run all tests**

Run: `bin/rails test`
Expected: all pass

- [ ] **Step 2: Run linter**

Run: `bin/rubocop`
Expected: no offenses

- [ ] **Step 3: Final commit if needed**

```bash
git commit -m "chore: fix lint issues"
```
