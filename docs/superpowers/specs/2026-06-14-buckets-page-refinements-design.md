# Buckets Page Layout Refinements

Date: 2026-06-14

## Summary

Polish the existing three-column `/buckets` page — remove inline +New buttons from section headings (they're already in the left sidebar), add visible border and distinct background to the middle content panel, and widen it slightly.

## Changes

### Remove inline +New buttons

Strip the `+ New` links from Projects, Collections, and Time Spreads section headers in the center column. The left sidebar already provides `+ Add collection`, `+ Add monthly log`, and `+ New project`. No creation path is lost.

### Middle section styling

Add a card container treatment to `.buckets--content`:
- `border: 1px solid var(--color-stroke-base)`
- `background: var(--color-bg-subtle)`
- `border-radius: var(--radius-strong)`
- Internal padding for breathing room

### Wider center column

The CSS grid definition already uses `1fr` for the center column. The sidebars are constrained by `minmax()` bounds. No explicit width change needed — the center column naturally takes available space. The visible border/bg makes the panel feel wider.

## Scope

2 files:
- `app/assets/stylesheets/buckets.css` — add `.buckets--content` card styles
- `app/views/buckets/index.html.erb` — remove three `link_to "+ New"` buttons

No migrations, models, routes, or controllers touched.

## Design decisions

- **Option 1 chosen** (remove all +New buttons): Cleaner center column, single source of creation actions in the left sidebar.
- **Option B chosen** (visible border + distinct bg): Card container that separates the content panel from the sidebars without being too heavy.

## Risks

None. Changes are cosmetic and forward-only.
