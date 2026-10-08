# Completions replace Archives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dual done/archived states with a single `done_at` finished state; completed bullets hide from daylog, live in a Completed list, and auto-delete after 30 days.

**Architecture:** `Completable` gains `not_done`/`expired_done` scopes and owns `RETENTION_DAYS`; `Timeline` queries `not_done`; a new `CompletedController#index` serves `done`; the cleanup job purges `expired_done`; collections hard-delete; the `archives` table and all archive UI go away.

**Tech Stack:** Rails 8.1, Ruby 4.0, Hotwire (Turbo), SQLite, Minitest (`bin/rails test`), RuboCop (`bin/ci` runs Minitest + RuboCop + Brakeman).

**Spec:** `docs/2026-10-07-completions-replace-archives-design.md`

## Global Constraints

- Retention window is exactly 30 days (`RETENTION_DAYS = 30`), driven by `done_at`.
- Completed bullets: Turbo `replace` on complete (check flashes), excluded from daylog/upcoming/search/export queries on reload.
- Collections: `destroy` is hard; member bullets survive untagged (existing `bullet_collections dependent: :destroy` behavior).
- No "hide without done" state is preserved; no export of the Completed list; no permanent done history.
- Follow existing pagination pattern `per_page: [15, 30, 50]` via `set_page_and_extract_portion_from`.

## Review Focus

- Done bullet still appearing in daylog after reload (query missed a caller) — expect it gone everywhere except Completed.
- Completed bullet still searchable via FTS (stale `Search::Record` row) — expect zero hits after `complete!`, restored after `uncomplete!`.
- Collect into a deleted collection raising 500 instead of clean not-found — expect 404/record-not-found path.
- Archived-row backfill losing timestamps (done_at set to now instead of `archives.created_at`) — expect original archive date preserved.
- 30-day boundary off-by-one (30-day-old done purged early or 31-day-old kept) — expect `...30.days.ago` exclusive-end semantics matching old `expired_archived`.

---

### Task 1: Done hides from daylog

**Files:**
- Modify: `app/models/concerns/completable.rb`
- Modify: `app/models/timeline.rb:14`
- Test: `test/models/timeline_test.rb`
- Test: `test/models/bullet/filter_test.rb` (call-site updates only)

**Interfaces:**
- Consumes: `Bullet::Filter#filtered(relation)` — unchanged signature.
- Produces: `Completable.not_done` (`ActiveRecord::Relation`), `Completable.expired_done` (`ActiveRecord::Relation`), `Completable::RETENTION_DAYS = 30` — used by Tasks 3 and 5.

- [ ] **Step 1: Write the failing test** in `test/models/timeline_test.rb`: completed bullet excluded from `filtered`/`on`/`prev_page`, uncompleted bullet included.

```ruby
test 'filtered excludes completed bullets' do
  user = users(:one)
  timeline = Timeline.new(user)
  bullet = create_bullet!(user, body: 'Done line')
  bullet.complete!
  assert_not_includes timeline.filtered, bullet
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `bin/rails test test/models/timeline_test.rb -v`
Expected: FAIL (done bullet still in `filtered` because `Timeline` only excludes `active`).

- [ ] **Step 3: Implement** `not_done`/`expired_done` scopes + `RETENTION_DAYS` in `app/models/concerns/completable.rb`, and change `app/models/timeline.rb:14` from `user.bullets.active` to `user.bullets.not_done`.

- [ ] **Step 4: Run to verify it passes**

Run: `bin/rails test test/models/timeline_test.rb test/models/bullet/filter_test.rb -v`
Expected: PASS (update the three `filter.filtered(@user.bullets.active)` call sites in `filter_test.rb:20,33,44` to `.not_done`).

- [ ] **Step 5: Commit**

```bash
git add app/models/concerns/completable.rb app/models/timeline.rb test/models/timeline_test.rb test/models/bullet/filter_test.rb
git commit -m "feat: hide completed bullets from timeline"
```

### Task 2: Search, filter, and collect follow done

**Files:**
- Modify: `app/models/bullet/searchable.rb:8`
- Modify: `app/models/collection/searchable.rb:8`
- Modify: `app/models/bullet/filter.rb:55`
- Modify: `app/models/concerns/collectable.rb:7`
- Modify: `app/controllers/bullets/collects_controller.rb:12-15`
- Test: `test/models/search/selection_test.rb:96-105`
- Test: `test/controllers/bullets/collects_controller_test.rb:192-194`

**Interfaces:**
- Consumes: `Completable.not_done` from Task 1 (no signature change needed here).
- Produces: `Bullet::Searchable#searchable? == !done?`; collection lookup without `active` scope — used by Task 4.

- [ ] **Step 1: Write the failing tests**: change `selection_test.rb` "archive! removes bullet from recent selections" to `complete!` removes from selections and FTS; change `collects_controller_test.rb` "rejects collect into archived collection" to expect collect into a destroyed (nonexistent) collection raises/shows not-found.

- [ ] **Step 2: Run to verify they fail**

Run: `bin/rails test test/models/search/selection_test.rb test/controllers/bullets/collects_controller_test.rb -v`
Expected: FAIL (searchable still checks `archived?`; collect still scopes `.active`).

- [ ] **Step 3: Implement**: `bullet/searchable.rb` → `!done?`; `collection/searchable.rb` → `true` (remove `archived?` check); `filter.rb:55`, `collectable.rb:7`, `collects_controller.rb:12-15` → drop `.active` (plain `user.collections.find(_by)…`).

- [ ] **Step 4: Run to verify they pass**

Run: `bin/rails test test/models/search/selection_test.rb test/controllers/bullets/collects_controller_test.rb test/models/bullet_test.rb -v`
Expected: PASS (also fix `bullet_test.rb:137` `.active.upcoming` → `.not_done.upcoming`).

- [ ] **Step 5: Commit**

```bash
git add app/models/bullet/searchable.rb app/models/collection/searchable.rb app/models/bullet/filter.rb app/models/concerns/collectable.rb app/controllers/bullets/collects_controller.rb test/
git commit -m "feat: search and collect follow done state"
```

### Task 3: Completed list + navigation

**Files:**
- Create: `app/controllers/completed_controller.rb`
- Create: `app/views/completed/index.html.erb`
- Create: `test/controllers/completed_controller_test.rb`
- Modify: `config/routes.rb:24,56`
- Modify: `app/controllers/searches_controller.rb:6-8`
- Modify: `app/views/searches/_navigation.html.erb:16-25`
- Modify: `app/views/searches/show.html.erb:9`
- Test: `test/controllers/home_controller_test.rb`, `test/controllers/searches_controller_test.rb`

**Interfaces:**
- Consumes: `Completable.done` + `done_at` ordering (existing).
- Produces: `completed_index_path` route + `CompletedController#index` listing `done.order(done_at: :desc)` — used by Task 6 (uncomplete entry point).

- [ ] **Step 1: Write the failing test** in `test/controllers/completed_controller_test.rb`: done bullets appear ordered by `done_at desc` with pagination; not-done bullets absent; counter in navigation shows `completed_count`.

```ruby
test 'index lists done bullets newest first' do
  sign_in_as @user
  old = create_bullet!(@user, body: 'Old done')
  old.complete!
  old.update!(done_at: 2.days.ago)
  fresh = create_bullet!(@user, body: 'Fresh done')
  fresh.complete!
  get completed_index_path
  assert_response :success
  assert_select 'main h1', 'Completed'
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `bin/rails test test/controllers/completed_controller_test.rb -v`
Expected: FAIL with routing error (`completed_index_path` undefined).

- [ ] **Step 3: Implement** `CompletedController#index` (mirror `ArchivedController#index` but `Current.user.bullets.includes(:collections).done.order(done_at: :desc)`), view (mirror `archived/index.html.erb` with `completed_index_path`), routes (`resources :completed, only: :index`), `SearchesController#show` (`@completed_count = Current.user.bullets.done.count`, `@collections` without `.active`), navigation partial (icon `check`, text `Completed`, `completed_index_path`, `completed_count`), `searches/show.html.erb` local rename.

- [ ] **Step 4: Run to verify it passes**

Run: `bin/rails test test/controllers/completed_controller_test.rb test/controllers/home_controller_test.rb test/controllers/searches_controller_test.rb -v`
Expected: PASS (update `home_controller_test.rb:20,95-100` archived asserts to completed).

- [ ] **Step 5: Commit**

```bash
git add app/controllers/completed_controller.rb app/views/completed/ config/routes.rb app/controllers/searches_controller.rb app/views/searches/ test/
git commit -m "feat: add Completed list"
```

### Task 4: Collections hard-delete

**Files:**
- Modify: `app/models/collection.rb:4`
- Modify: `app/controllers/collections_controller.rb:11,55-57,63`
- Test: `test/controllers/collections_controller_test.rb:176-187`
- Test: `test/controllers/bullets/exports_controller_test.rb:78-79`

**Interfaces:**
- Consumes: collection lookup without `.active` (Task 2).
- Produces: `CollectionsController#destroy` hard-deletes — nothing downstream depends on archived collections.

- [ ] **Step 1: Write the failing test**: `collections_controller_test.rb` destroy asserts record gone and member bullets survive untagged.

```ruby
test 'destroy hard-deletes collection and keeps bullets untagged' do
  collection = create_collection!(@user, name: 'Gone')
  bullet = create_bullet!(@user, body: 'Stays', collection: collection)
  delete collection_path(collection)
  assert_not Collection.exists?(collection.id)
  assert Bullet.exists?(bullet.id)
  assert_empty bullet.reload.collections
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `bin/rails test test/controllers/collections_controller_test.rb -v`
Expected: FAIL (destroy still calls `archive!`, record persists).

- [ ] **Step 3: Implement**: drop `Archivable` from `Collection`, `destroy` → `@collection.destroy` with notice "Collection deleted", `set_collection`/`index` without `.active`; fix exports test (`archived collection` → destroyed collection → 404).

- [ ] **Step 4: Run to verify it passes**

Run: `bin/rails test test/controllers/collections_controller_test.rb test/controllers/bullets/exports_controller_test.rb -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/models/collection.rb app/controllers/collections_controller.rb test/controllers/collections_controller_test.rb test/controllers/bullets/exports_controller_test.rb
git commit -m "feat: hard-delete collections"
```

### Task 5: Cleanup job purges expired done

**Files:**
- Modify: `app/jobs/clean_soft_deleted_records_job.rb:7-8`
- Modify: `test/jobs/clean_soft_deleted_records_job_test.rb`

**Interfaces:**
- Consumes: `Completable.expired_done` from Task 1.
- Produces: 30-day purge of done bullets — terminal, no downstream interface.

- [ ] **Step 1: Write the failing test**: rewrite job test — expired done destroyed, recent done kept, no collection branch, blob purge unchanged.

```ruby
test 'destroys expired done bullets' do
  bullet = create_bullet!(@user, body: 'Old news')
  bullet.complete!
  bullet.update!(done_at: (Completable::RETENTION_DAYS + 1).days.ago)
  assert_difference -> { Bullet.count }, -1 do
    CleanSoftDeletedRecordsJob.perform_now
  end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `bin/rails test test/jobs/clean_soft_deleted_records_job_test.rb -v`
Expected: FAIL (job still queries `expired_archived`).

- [ ] **Step 3: Implement** `Bullet.expired_done.destroy_all`, delete the `Collection.expired_archived` line.

- [ ] **Step 4: Run to verify it passes**

Run: `bin/rails test test/jobs/clean_soft_deleted_records_job_test.rb -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/jobs/clean_soft_deleted_records_job.rb test/jobs/clean_soft_deleted_records_job_test.rb
git commit -m "feat: purge expired completed bullets"
```

### Task 6: Remove archive UI surface

**Files:**
- Modify: `app/views/bullets/_bulk_menu.html.erb:96-114` (delete Archive form)
- Modify: `app/views/bullets/show.html.erb:57-70` (Archive/Unarchive dropdown → Complete/Uncomplete via `completion_path`)
- Modify: `app/views/bullets/exports/show.html.erb:22-24` (drop `archived?` tag)
- Modify: `app/views/bullets/_bullet.json.jbuilder:7` (drop `archived` key)
- Modify: `app/views/features/show.html.erb:26,41` (Archive copy → Completed)
- Modify: `app/controllers/bullets_controller.rb:41` (comment wording)
- Test: `test/controllers/bullets_controller_test.rb:41,137-146,225-257`, `test/controllers/bullets/exports_controller_test.rb:43-54`, `test/controllers/timelines_controller_test.rb:50-53`, `test/controllers/upcoming_controller_test.rb:21-24`, `test/models/activity_recording_test.rb:23-32`

**Interfaces:**
- Consumes: `completed_index_path` (Task 3); `completion_path` POST/DELETE (existing).
- Produces: no archive routes/keys remain — required by Task 7's deletions.

- [ ] **Step 1: Write the failing tests**: update `bullets_controller_test.rb` show/day assertions from `archive!`/`archive_path`/`Unarchive` to `complete!`/`completion_path`/`Uncomplete`; exports test asserts no `Archived` tag; upcoming/timelines tests use `complete!`.

- [ ] **Step 2: Run to verify they fail**

Run: `bin/rails test test/controllers/bullets_controller_test.rb test/controllers/timelines_controller_test.rb test/controllers/upcoming_controller_test.rb test/models/activity_recording_test.rb -v`
Expected: FAIL on at least the show/archive asserts.

- [ ] **Step 3: Implement** the view/partial/json/copy deletions and swaps listed above; keep completions Turbo as `replace`.

- [ ] **Step 4: Run to verify they pass**

Run: `bin/rails test test/controllers/bullets_controller_test.rb test/controllers/timelines_controller_test.rb test/controllers/upcoming_controller_test.rb test/controllers/bullets/exports_controller_test.rb test/models/activity_recording_test.rb -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/bullets/ app/controllers/bullets_controller.rb app/views/features/ test/
git commit -m "feat: remove archive UI"
```

### Task 7: Migration, dead-code removal, full suite

**Files:**
- Create: `db/migrate/20261007_drop_archives_backfill_done.rb`
- Delete: `app/models/archive.rb`, `app/models/concerns/archivable.rb`, `app/controllers/bullets/archives_controller.rb`, `app/views/bullets/archives/create.turbo_stream.erb`, `app/views/bullets/archives/destroy.turbo_stream.erb`, `app/controllers/archived_controller.rb`, `app/views/archived/index.html.erb`, `test/controllers/bullets/archives_controller_test.rb`
- Modify: `app/models/bullet.rb:4`, `config/routes.rb:24` (`resource :archive` line), `db/schema.rb` (via migrate)

**Interfaces:**
- Consumes: everything above; produces the final schema with no `archives` table.

- [ ] **Step 1: Write the failing test**: migration-level check — create archived-but-not-done bullet + archived collection via current code, then assert post-migration bullet is `done?` with preserved timestamp and collection is gone.

```ruby
test 'migration converts archived bullets to done and destroys archived collections' do
  bullet = create_bullet!(@user, body: 'Was archived')
  bullet.archive!
  archived_on = bullet.archive.created_at
  collection = create_collection!(@user, name: 'Was archived')
  collection.archive!
  # run migration, then:
  # assert bullet.reload.done? && bullet.done_at.to_date == archived_on.to_date
  # assert_not Collection.exists?(collection.id)
end
```

(Implement as a temporary minitest or console check around the migration; delete after green.)

- [ ] **Step 2: Run to verify it fails** (pre-migration state has `archives` table, no backfill).

Run: `bin/rails test test/controllers/bullets/archives_controller_test.rb -v`
Expected: PASS pre-deletion (proves the surface still exists before removal).

- [ ] **Step 3: Implement** migration: backfill `bullets.done_at = archives.created_at` where null, hard-destroy archived collections, delete stale `Search::Record` rows for newly-done bullets, `drop_table :archives`; delete the files listed; remove `Archivable` from `Bullet`, `resource :archive` from routes (keep `resources :archived` removal — already replaced in Task 3; this task removes leftovers).

- [ ] **Step 4: Run full verification**

Run: `bin/rails db:migrate && bin/rails test -v`
Expected: full suite PASS.
Run: `bin/ci` (or at minimum `rubocop` + `brakeman` if `bin/ci` is heavy in this env).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/ app/models/ app/controllers/ app/views/ config/routes.rb db/schema.rb test/
git commit -m "feat: drop archives table, completions own finished state"
```
