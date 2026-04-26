# Task Context Link Rollout

## Capture Heuristic

- Keep the main action in the card body.
- Add a context link only when extra detail would slow rapid logging.

## MVP Behavior

- `context_card_id` is optional and nullable.
- Context can be selected from existing cards using the picker chip.
- Context can be created inline by typing and choosing "Create note".

## Validation Window (3-7 days)

Track daily:

- Number of cards created with context links
- Percentage of context links opened from timeline cards
- Median time from card creation to completion for task cards
- Number of untriaged cards at end of day

## Phase 2 Gate (Multi-Link)

Move to `card_context_links` only when both are true for at least 5 consecutive days:

- At least 20% of newly created cards need more than one context reference
- At least 30% of context-linked cards are manually re-linked within 24 hours

If either signal is below threshold, keep the single-link model.
