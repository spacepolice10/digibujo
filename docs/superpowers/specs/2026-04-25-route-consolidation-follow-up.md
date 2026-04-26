# Follow-up PR: Consolidate Type Routes Into `/cards`

## Goal
Remove type-specific timeline routes (`/tasks`, `/notes`, `/events`, `/daylogs`) and keep one canonical bullet-journal timeline at `/cards`, with filter-driven links.

## Scope
- Remove index-style route entries for `tasks`, `notes`, `events`, and `daylogs`.
- Keep the underlying models and delegated cardable types unchanged.
- Add redirects from removed entry points to `/cards` with equivalent filter parameters.
- Update sidebar and navigation links to target filtered `/cards` URLs.

## Routing Strategy
1. In `config/routes.rb`, replace removed resources with redirects:
   - `/tasks` -> `/cards?type=task`
   - `/notes` -> `/cards?type=note`
   - `/events` -> `/cards?type=event`
   - `/daylogs` -> `/cards?type=daylog`
2. Keep nested mutating actions that still rely on existing controllers only if they are not timeline-index endpoints.
3. Preserve Turbo-frame navigation semantics on links by continuing to target `cards_panel`.

## Controller and Query Strategy
1. Extend `CardsController#index` to accept filter params:
   - `type`
   - optional task-specific sort (`done_last`) if still needed.
2. Build filtered scopes in `Card` or controller-private query methods.
3. Keep journal ordering (`created_at ASC`) as the default for the unified timeline.

## UI Migration
1. Replace references to removed routes in stream/sidebar partials with filtered `/cards` links.
2. Keep current icons/labels so users retain the same mental model while using a single feed.
3. Ensure active-state logic reads URL params instead of route name.

## Compatibility and Rollout
- First release with redirects enabled and updated nav links.
- Monitor for stale bookmarks and confirm they land on expected filtered timeline.
- In a later cleanup PR, remove unused controllers/views once no direct references remain.

## Verification Checklist
- Visiting `/tasks`, `/notes`, `/events`, `/daylogs` lands on `/cards` with matching filter.
- Filtered `/cards` renders the same card subset as previous specialized pages.
- Turbo navigation in `cards_panel` continues to work.
- Pinned/pop interactions still mutate `#cards` list correctly.
