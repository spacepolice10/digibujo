# Card-Level Triage — Remove `Draft` as a Delegated Type

**Date:** 2026-04-22

## Summary

Remove `Draft` from `Card`'s delegated types and move triage into the `Card` lifecycle itself.

The core change is conceptual:

- **Cardable type** answers what a card is: `Task`, `Note`, `Event`, `Daylog`, etc.
- **Triage state** answers whether the card has been consciously reviewed after capture.

Today those concerns are mixed together. `Draft` is acting as a workflow state, not a durable domain type. That makes migration feel like promotion out of a temporary object instead of a review decision applied to the same bullet over time.

The redesigned flow keeps the bullet journal mechanic intact:

- capture quickly
- review later
- migrate, collect, schedule, archive, or delete
- preserve the same card identity and history throughout

---

## Problem

### Current model

`Draft` currently serves three jobs at once:

1. A neutral capture type for fast logging
2. A hidden inbox state that is excluded from the timeline
3. The boundary for triage actions such as schedule, collect, postpone, and remove

That produces several mismatches:

- A workflow state is encoded as a delegated type
- Triage is limited to disposable entries instead of applying to the whole card system
- "Migration" means replacing the underlying cardable, not revisiting the same bullet
- Cards cannot be both real domain objects and still require review

### Why this is a problem

The app is aiming at a bullet-journal-like workflow. In that model, migration is not "convert a draft into a real thing." It is "revisit an existing bullet and decide what to do with it next."

The card should stay the same object while its meaning, metadata, and placement evolve.

---

## Goals

- Make triage a mechanic on cards, not on `Draft`
- Keep rapid logging fast and low-friction
- Preserve bullet identity through review and migration
- Allow migration to happen across all card types
- Support explicit cleanup and recycling of neglected cards
- Avoid introducing a fake neutral type if the user already knows what they are logging

## Non-Goals

- Rebuild the entire card taxonomy
- Add a full audit log or event sourcing system in the first pass
- Infer card type from content automatically
- Force tags on every card as a validity requirement

---

## Proposed Model

### Durable cardables

`Card` should keep only durable delegated types:

- `Task`
- `Note`
- `Event`
- `Daylog`
- any other real long-lived types

`Draft` should be removed from `delegated_type`.

### Triage state lives on `Card`

Add a review-state field directly to `cards`.

Recommended shape:

- `triaged_at: datetime`

Interpretation:

- `triaged_at: nil` means the card still needs review
- `triaged_at: present` means the card has already received a conscious disposition

Optional future additions:

- `last_triaged_action: string`
- `captured_on: date`
- `archived_reason: string`

These are not required for the first pass.

---

## Product Behaviour

### Capture

New cards are created as their real type from the start.

Examples:

- a task is captured as a `Task`
- a note is captured as a `Note`
- an event is captured as an `Event`

Every new card starts with:

- `triaged_at = nil`

This preserves the "rapid log first, clean up later" flow without introducing a temporary cardable.

### Triage

The triage screen should show cards that still require review.

Primary query:

- cards with `triaged_at: nil`

Optional presentation filter:

- emphasize cards created today first
- allow viewing older untriaged cards separately

Important: "created today" should be a UI filter, not the source of truth for whether a card needs triage.

### Triage actions

Triage should require a conscious disposition. The important change is that these actions operate on the same card.

Recommended first-pass actions:

- `Commit` — confirm the card as valid in its current type and mark it triaged
- `Migrate` — change its date or move it into the future log
- `Collect` — add or refine tags and mark it as reference material
- `Archive` — remove it from active surfaces
- `Delete` — remove noise entirely

Notes:

- `Commit` replaces the vague "keep as is" label
- not every triage action needs a type conversion
- type conversion should still be possible when the user misclassified the card on capture

### Migration as a card mechanic

Migration should become a card-level mechanic rather than a `Draft`-only promotion path.

Examples:

- `Task` today → rescheduled task next week
- `Task` → archived because it no longer matters
- `Task` → `Note` if the user decides it is reference material
- `Note` → tagged and collected into a stronger knowledge structure

The card remains the same user-facing entry through those decisions.

---

## Local Type Memory

To preserve speed after removing `Draft`, the app should remember the user's last selected capture type in `LocalStorage`.

### Behaviour

- the capture form defaults to the most recently used type for that browser
- if no local preference exists yet, default to `Task`
- switching the type picker updates the saved value immediately
- the saved value only affects the default selection, not the actual available types

### Why local storage fits

- this is a UI preference, not durable domain data
- it should not affect other devices or other users
- it keeps rapid logging fast without adding server-side preference complexity

### Suggested storage key

- `digibujo.cards.defaultType`

### Fallback

If the saved type no longer exists or is invalid:

- ignore it
- fall back to `Task`

---

## Data Model Changes

### Add to `cards`

- `triaged_at: datetime, null: true`

### Remove from `Card`

- `Draft` from `delegated_type`

### Remove or repurpose

- `Draft` model
- draft-only promotion concerns if they no longer make sense as type-specific behaviour
- draft-specific routes, controllers, views, and styles

---

## Controller and Routing Direction

### Replace draft-specific triage endpoints

Current triage endpoints are nested under `/drafts/...`.

Those should become generic card-level endpoints, for example:

- `/cards/:card_id/triage/commit`
- `/cards/:card_id/triage/migrate`
- `/cards/:card_id/triage/collect`
- `/cards/:card_id/triage/archive`
- `/cards/:card_id/triage/delete`

Exact naming can be adjusted, but the important change is ownership:

- triage belongs to `Card`
- triage is not scoped to a special delegated type

### Generalize conversion logic

The current `Promotable` path is centered on replacing `Draft` with another cardable.

That should be replaced with card-level conversion/update logic that can:

- change cardable type when needed
- update date and tags
- mark the card as triaged

This may still internally reuse transactional swap logic, but it should no longer be framed as "promote draft."

---

## Cleanup and Recycling

The app should enforce review, but the recycling rule should be based on neglect rather than on missing tags alone.

### Recommended rule shape

Prefer age + inactivity heuristics such as:

- auto-archive untriaged cards older than `N` days
- auto-archive notes older than `N` days with no tags and no pin
- auto-archive tasks with no date, no tags, and no updates after `N` days

### Why not "archive if missing tags"

That rule is too blunt:

- some tasks do not need tags
- some notes may intentionally remain untagged for a while
- missing metadata is not always the same as irrelevance

The system should recycle stale cards, not punish temporarily incomplete cards.

### Product posture

The app should encourage one of two outcomes for neglected entries:

- the user reviews and keeps them alive
- the system quietly clears dead weight

That supports the bullet journal discipline of pruning without forcing unnecessary ceremony on every capture.

---

## Migration Plan

### Phase 1: Introduce card-level triage

- add `triaged_at` to `cards`
- mark all new cards as untriaged by default
- create a card-level triage screen and actions
- add LocalStorage-backed capture type memory

### Phase 2: De-emphasize `Draft`

- stop defaulting new cards to `Draft`
- default the capture form to the remembered type or `Task`
- keep existing draft records readable while the new flow is stabilized

### Phase 3: Remove `Draft`

- migrate existing draft cards into a durable type
- delete draft-specific routes, controllers, views, and styles
- remove `Draft` from `Card.cardable_types`
- delete `Draft` model and obsolete concerns

### Existing draft migration

Recommended migration target:

- convert existing drafts to `Task` by default
- preserve `content`, `tags`, `pops_on`, `date`, and timestamps
- leave `triaged_at` as `nil` so they appear in the new triage flow

Rationale:

- defaulting to `Task` is safer than inventing a new neutral type
- any misclassified entry can be converted during triage

---

## UI Notes

### Capture form

- keep the type picker
- initialize it from `LocalStorage`
- update the remembered type whenever the user switches types
- continue to load type-specific form fields dynamically

### Timeline

- stop treating draft cards as a hidden class
- use triage state, archive state, and cardable type independently

### Triage screen

- rename from "Drafts" to a card-level concept such as `Triage`, `Review`, or `Inbox`
- show untriaged cards grouped by freshness
- make the disposition buttons explicit and irreversible enough to feel meaningful

---

## Risks

- Defaulting everything to `Task` may cause some misclassification during fast capture
- Generalizing conversion beyond `Draft` increases model and controller complexity in the short term
- Removing `Draft` all at once may touch many views, tests, scopes, and Turbo Stream responses

These are acceptable tradeoffs because the resulting model is much clearer:

- type is type
- review is review
- migration is applied to the same card

---

## Out of Scope

- a full historical event log for every triage action
- sync of default capture type across devices
- smart suggestions for tags or card type
- rules engine UI for recycling policies
