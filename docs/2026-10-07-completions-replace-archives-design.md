# Completions replace Archives — Design

Date: 2026-10-07
Status: approved in chat, pending spec review
Goal: simplify mental model — one finished state instead of done vs archived.

## Intent (agreed)

- Motivation: simplify mental model, not code savings or noise cleanup alone.
- Completed bullets hide from daylog (show check via Turbo now, gone on reload) and live in a separate Completed list.
- Retention: 30 days in Completed, then hard-delete (same window as archives today).
- Collections: no soft-delete. Destroy is hard; member bullets survive untagged.
- Accepted loss: no more "hide without completing". A note leaves the daylog by being completed or hard-deleted.

## Current state (evidence)

- `app/models/concerns/archivable.rb:6-15`: `RETENTION_DAYS = 30`, `has_one :archive`, scopes `archived/active/expired_archived`.
- `app/models/concerns/completable.rb:6-8`: only `done` scope on `done_at`; `complete!`/`uncomplete!` toggle the timestamp.
- `app/models/timeline.rb:14`: `filter.filtered(user.bullets.active)` — done bullets stay visible.
- `app/views/bullets/completions/create.turbo_stream.erb:7`: `replace` (stays with check).
- `app/views/bullets/archives/create.turbo_stream.erb:7`: `remove_all` (disappears).
- `app/jobs/clean_soft_deleted_records_job.rb:7-8`: destroys `Bullet.expired_archived` + `Collection.expired_archived`.
- `app/controllers/archived_controller.rb`: paginated `archived.order(updated_at: :desc)`, 15/30/50.
- `config/routes.rb:24,56`: `resource :archive` + `resources :archived`.
- `app/models/concerns/searchable.rb:7-9,31-37`: `after_update_commit` upserts or removes the FTS row based on `searchable?`.

## Design (approach A: done-only)

### 1. Query model

- Move `RETENTION_DAYS = 30` from `Archivable` to `Completable`.
- `Completable` gains:
  - `scope :not_done, -> { where(done_at: nil) }`
  - `scope :expired_done, -> { done.where(done_at: ...RETENTION_DAYS.days.ago) }`
- `Timeline#filtered` becomes `filter.filtered(user.bullets.not_done)`.
- `Bullet::Searchable#searchable?` becomes `!done?`. No callback change needed: `complete!` fires `after_update_commit`, which removes the FTS row; `uncomplete!` re-adds it.
- `Collection` drops `Archivable`; `Collection::Searchable#searchable?` becomes unconditionally true (delete the override or return true).
- All `collections.active` callers become plain scoped queries ordered by name:
  `collections_controller.rb:11,62`, `searches_controller.rb:6`, `bullet/filter.rb:56`.

### 2. Completed list

- New `CompletedController#index`, mirroring `ArchivedController#index`: `Current.user.bullets.done.order(done_at: :desc)`, same `set_page_and_extract_portion_from` with `per_page: [15, 30, 50]`.
- View `completed/index.html.erb` mirrors `archived/index.html.erb` with title "Completed" and `completed_index_path` pagination.
- `SearchesController#show` exposes `@completed_count = Current.user.bullets.done.count`; `_navigation.html.erb` Archive entry becomes Completed (icon `check`, path `completed_index_path`, counter `completed_count`).
- Completions Turbo stays `replace`, so the user sees the check immediately; the next reload/pagination excludes the row via the `not_done` query. Uncomplete from the Completed list uses the existing `destroy.turbo_stream` replace path.

### 3. Removal surface

Delete: `Archive` model, `Archivable` concern, `Bullets::ArchivesController` + both turbo views, `ArchivedController` + `archived/index.html.erb`, `archives` table.
Routes: remove `resource :archive` and `resources :archived`; add `resources :completed, only: :index`.
Bulk menu (`_bulk_menu.html.erb:96-114`): delete the Archive form; hotkey `A` retired.
`CollectionsController#destroy`: `@collection.archive!` → `@collection.destroy`; notice "Collection archived" → "Collection deleted".
Collect/publish guards referencing archived collections collapse to existence checks (a deleted collection is simply not found).

### 4. Cleanup job

- `CleanSoftDeletedRecordsJob#perform`: `Bullet.expired_done.destroy_all` + existing unattached-blob purge. Collection branch deleted.
- Bullet hard-delete cascades `bullet_collections` (bullets vanishing from collections) and rich-text/file attachments via existing `dependent: :destroy`; orphan blobs covered by the blob purge.

### 5. Migration + backfill (single migration)

1. Backfill bullets: rows with an `archives` entry but `done_at IS NULL` get `done_at = archives.created_at`; rows already done keep `done_at`.
2. Backfill collections: `archives` rows pointing at collections trigger hard `destroy` of the collection (join rows cascade, member bullets survive untagged — matches `clean_soft_deleted_records_job_test.rb:19-30` semantics).
3. `drop_table :archives`.
4. Remove stale `Search::Record` rows for newly-done bullets (or rely on reindex sweep; prefer explicit delete in the migration to avoid ghost search hits).

### 6. Edge cases

- Hide-without-done disappears by design. Workaround is hard-delete via `bullets#destroy` (already immediate, no retention).
- Completed excluded from daylog, upcoming (via `Timeline`), search (via `searchable?`), and export (via `Timeline`) by construction.
- `client_id` idempotency and `RecordNotUnique` rescue in `BulletsController` unchanged.
- Published bullets that get completed: keep current publish behavior (publish is orthogonal); export of Completed list is out of scope.

## Testing

- Delete `bullets/archives_controller_test.rb`; rewrite `archive!`/`archived` call sites to `complete!`/`done` (`timeline_test.rb`, `bullet/filter_test.rb`, `search/selection_test.rb`, `upcoming_controller_test.rb`, `timelines_controller_test.rb`, `exports_controller_test.rb`, `collects_controller_test.rb`, `home/searches` nav asserts).
- `collections_controller_test.rb:176-187`: destroy asserts hard-delete and bullets surviving untagged.
- `clean_soft_deleted_records_job_test.rb`: expired-done destroyed, recent-done kept, collection branch removed.
- New coverage: done excluded from `Timeline.filtered` but present in Completed index; Turbo complete still `replace`s with `data-bullet-done="true"`; uncomplete restores to daylog.
- Manual: complete → check flashes → reload gone → Completed shows → uncomplete restores → 31-day-old done purged by job.

## Out of scope

- Export of the Completed list.
- Permanent done history.
- Collection trash/restore.
