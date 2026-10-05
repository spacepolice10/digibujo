# Mild dark-mode contrast lift — design

**Date:** 2026-10-05  
**Status:** Approved

## Goal

Keep a clearly dark UI, but make surfaces and text easier to separate at a glance. Fix both weak surface-vs-surface contrast and muddy text/icons.

## Approach

Lift the whole dark surface scale and nudge muted invert (text) tokens slightly brighter. Light-mode values stay unchanged. No button structure or border redesign.

## Token targets

Dark side of `light-dark()` only. Keep chroma and hue as-is; change lightness (L).

| Token | Today | Mild lift |
| --- | --- | --- |
| `--color-1` | `0.20` | `0.25` |
| `--color-2` | `0.24` | `0.30` |
| `--color-3` | `0.28` | `0.35` |
| `--color-4` | `0.32` | `0.40` |
| `--color-invert-1` | `0.98` | unchanged |
| `--color-invert-2` | `0.82` | `0.86` |
| `--color-invert-3` | `0.66` | `0.72` |
| `--color-invert-4` | `0.50` | `0.58` |
| `--background-canvas-colour` | `0.19` | `0.24` |

Wider steps between surfaces so panels and buttons don’t blend.

## Files

| File | Change |
| --- | --- |
| `app/assets/stylesheets/variables.css` | Update dark sides of `--color-1…4` and `--color-invert-2…4` |
| `app/assets/stylesheets/base.css` | Raise `--background-canvas-colour` dark L; match appearance tint dark `--color-1` / `--color-2` L values to the new scale |
| `app/views/layouts/application.html.erb` | Dark `theme-color` meta from `#141414` to ~`#2a2a2a` (match new canvas) |

## Out of scope

- Light mode
- Button/intent CSS structure
- Border or shadow redesign
- Status colors (`--color-positive` / `--color-negative`)
- Static `public/*.html` error pages (optional follow-up)

## Success

In OS dark mode: page still reads as dark; surfaces (cards, secondary buttons, chrome) are clearly separable; muted labels/icons read more clearly without looking washed out.
