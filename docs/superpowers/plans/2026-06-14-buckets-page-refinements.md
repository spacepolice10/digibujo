# Buckets Page Refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Polish the buckets page — remove inline +New buttons, add visible border and distinct bg to middle section.

**Architecture:** Two-file change. CSS adds card styling to `.buckets--content`. ERB view removes three `link_to` buttons.

**Tech Stack:** Rails 8, CSS layers, Propshaft

---

### Task 1: Add middle section card styling

**Files:**
- Modify: `app/assets/stylesheets/buckets.css` (add rules after line 98 existing `.buckets--content`)

- [ ] **Step 1: Add card styles to `.buckets--content`**

In `app/assets/stylesheets/buckets.css`, replace the existing `.buckets--content` block with:

```css
.buckets--content {
  min-width: 0;
  border: 1px solid var(--color-stroke-base);
  background: var(--color-bg-subtle);
  border-radius: var(--radius-strong);
  padding: var(--spacing-vertical) var(--spacing-horizontal);
}
```

- [ ] **Step 2: Verify CSS is valid**

Run: `bin/rubocop app/assets/stylesheets/buckets.css` (ignore CSS-as-Ruby false positives)

### Task 2: Remove inline +New buttons from view

**Files:**
- Modify: `app/views/buckets/index.html.erb`

- [ ] **Step 1: Remove +New from Projects heading**

In `app/views/buckets/index.html.erb`, change this:

```erb
    <div class="layout--header">
      <h2 class="project">Projects</h2>
      <div class="layout--header-actions">
        <%= link_to "+ New", new_project_path, class: "button--primary", data: { turbo_frame: "_top" } %>
      </div>
    </div>
```

To this:

```erb
    <div class="layout--header">
      <h2 class="project">Projects</h2>
    </div>
```

- [ ] **Step 2: Remove +New from Collections heading**

```erb
    <div class="layout--header">
      <h2 class="collection">Collections</h2>
      <div class="layout--header-actions">
        <%= link_to "+ New", new_collection_path, class: "button--primary", data: { turbo_frame: "_top" } %>
      </div>
    </div>
```

To:

```erb
    <div class="layout--header">
      <h2 class="collection">Collections</h2>
    </div>
```

- [ ] **Step 3: Remove +New from Time Spreads heading**

```erb
    <div class="layout--header">
      <h2 class="timespread">Time spreads</h2>
      <div class="layout--header-actions">
        <%= link_to "+ New", new_timespread_path, class: "button--primary", data: { turbo_frame: "_top" } %>
      </div>
    </div>
```

To:

```erb
    <div class="layout--header">
      <h2 class="timespread">Time spreads</h2>
    </div>
```

### Task 3: Verify

- [ ] **Step 1: Run rubocop on the controller**

```bash
bin/rubocop app/controllers/buckets_controller.rb
```

- [ ] **Step 2: Start the server and verify visually**

```bash
bin/dev
```

Load `/buckets` and confirm: no +New buttons in headings, middle section has a visible border with distinct background.
