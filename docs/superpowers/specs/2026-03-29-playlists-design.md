# Playlists — Design Spec

## Context

Digibujo has two ways to organize cards: **Streams** (saved filtered views) and **Pinned** (up to 10 quick-access cards). There's a gap between them — no way to manually curate a working set of cards pulled from different categories for a specific task or moment. Playlists fill this gap: manually curated, ordered collections of cards that live in the dock for instant access, like YouTube playlists or Spotify queues.

## Core Concept

A Playlist is an ordered list of card references. Users add cards with a single tap of "+" from any card's menu. Playlists are persistent by default — created instantly with auto-assigned color and icon, no naming required. They live in the bottom dock alongside pinned cards as card stacks, openable via popover for quick interaction.

## Data Model

### `playlists` table

| Column       | Type     | Constraints                  |
|-------------|----------|------------------------------|
| `id`        | integer  | primary key                  |
| `colour`    | integer  | not null, 1-8 (auto-assigned)|
| `icon`      | string   | not null (auto-assigned)     |
| `user_id`   | integer  | not null, foreign key        |
| `created_at`| datetime |                              |
| `updated_at`| datetime |                              |

Indexes: `[user_id]`

### `playlist_cards` table

| Column        | Type    | Constraints                        |
|--------------|---------|-------------------------------------|
| `id`         | integer | primary key                         |
| `playlist_id`| integer | not null, foreign key               |
| `card_id`    | integer | not null, foreign key               |
| `position`   | integer | not null                            |
| `created_at` | datetime|                                     |
| `updated_at` | datetime|                                     |

Indexes: unique `[playlist_id, card_id]`, `[playlist_id, position]`

### Model: `Playlist`

```ruby
class Playlist < ApplicationRecord
  include Colourable, Iconable

  belongs_to :user
  has_many :playlist_cards, -> { order(:position) }, dependent: :destroy
  has_many :cards, through: :playlist_cards

  before_create :auto_assign_identity
end
```

- `Colourable` and `Iconable` are existing concerns — reuse them directly.
- `auto_assign_identity` picks next color in rotation (1-8 cycle based on user's playlist count) and an icon from the existing `ICON_KEYS` set.

### Model: `PlaylistCard`

```ruby
class PlaylistCard < ApplicationRecord
  belongs_to :playlist
  belongs_to :card

  validates :card_id, uniqueness: { scope: :playlist_id }
end
```

### Card association addition

```ruby
# In Card model
has_many :playlist_cards, dependent: :destroy
has_many :playlists, through: :playlist_cards
```

## Routes

```ruby
resources :playlists, only: [:index, :show, :create, :destroy] do
  scope module: :playlists do
    resources :cards, only: [:create, :destroy]
    resource :reorder, only: :update
  end
end
```

| Route                                    | Controller                      | Purpose                          |
|-----------------------------------------|--------------------------------|----------------------------------|
| `GET /playlists`                        | `PlaylistsController#index`    | Columns page (all playlists)     |
| `GET /playlists/:id`                    | `PlaylistsController#show`     | Single playlist view             |
| `POST /playlists`                       | `PlaylistsController#create`   | Create new playlist              |
| `DELETE /playlists/:id`                 | `PlaylistsController#destroy`  | Delete playlist (keeps cards)    |
| `POST /playlists/:playlist_id/cards`    | `Playlists::CardsController#create`  | Add card to playlist       |
| `DELETE /playlists/:playlist_id/cards/:id` | `Playlists::CardsController#destroy` | Remove card from playlist |
| `PATCH /playlists/:playlist_id/reorder` | `Playlists::ReordersController#update` | Reorder cards in playlist |

All mutating actions respond to `turbo_stream` with HTML fallback.

## UI: Dock

### Dock layout

Playlist stacks appear in the bottom dock bar next to the pinned stack. Each playlist renders as a card stack (layered cards with slight offset, reusing the existing `pinned-stack` CSS pattern) with:

- Playlist color as border/accent
- Playlist icon badge
- Top card title visible
- Card count label

Up to **3 playlist stacks** visible in the dock. When there are 4+, an overflow button appears showing "+N more" that links to the playlists index page.

A dashed "+" button at the end of the dock creates a new playlist instantly (POST to `playlists_path`).

### Dock popover

Clicking a playlist stack opens a popover (HTML Popover API, same pattern as pinned dock dropdown) anchored to the stack. Contents:

- **Header:** playlist icon + color accent, card count, "Open" link (to show page), "Delete" action
- **Card list:** scrollable, each card shows:
  - Drag handle (for reordering)
  - Card title + type + relative date
  - Remove button (DELETE to `playlist_cards_path`)
- **Empty state:** "No cards yet" message

### Turbo frame

The dock renders in a `<turbo-frame id="playlists_panel">` in the main layout, loaded lazily alongside `pinned_panel`. Updates via turbo_stream when cards are added/removed.

## UI: "+" Button (Add to Playlist)

Added as a new entry in the existing card dropdown menu (the `card-dropdown-menu` popover), alongside Pop, Pin, Archive, Edit, Delete.

**Default behavior:** single tap adds the card to the **most recently created playlist** (`user.playlists.order(created_at: :desc).first`). The button label shows the target playlist's icon + color for visual confirmation.

**If the card is already in that playlist:** the button shows a different state (e.g., checkmark) indicating it's already added. Tapping removes it (toggle behavior).

**Choosing a different playlist:** the card dropdown includes a submenu or additional entries showing other playlists by icon + color, each as a separate `button_to`.

## UI: Playlists Index Page

`GET /playlists` — accessible from the dock overflow button or navigation.

**Layout:** horizontal columns, one per playlist. Each column has:

- Header: playlist icon + color accent border, card count
- Card list: vertically stacked card summaries (title, type, date)
- Standard card actions available on each card
- "New playlist" button at the end as a dashed column

Horizontally scrollable when playlists exceed viewport width.

## Interactions

### Adding a card to a playlist
1. User taps "+" in card dropdown → POST creates `PlaylistCard` with next position
2. Turbo stream updates the dock (card count, stack preview)
3. Card remains in Timeline — playlist holds a reference only

### Creating a new playlist
1. User taps "+" button in dock → POST creates `Playlist` with auto color/icon
2. New stack appears in dock. Becomes the new default target for card "+".

### Removing a card from a playlist
1. In dock popover or playlist page: tap remove → DELETE destroys `PlaylistCard`
2. Card itself is unaffected
3. Turbo stream updates the popover and dock

### Deleting a playlist
1. DELETE destroys the `Playlist` and all `PlaylistCard` join records
2. Cards themselves are untouched
3. Turbo stream removes the stack from the dock

### Reordering cards
1. Drag-and-drop in the dock popover or playlist page
2. PATCH to reorder endpoint with new position array
3. Requires a Stimulus controller for drag handling

### Card deletion cascade
When a card is deleted, `PlaylistCard` records are cleaned up via `dependent: :destroy` on the Card model's `has_many :playlist_cards`.

### A card can be in multiple playlists
Playlists are reference-only. The same card can appear in any number of playlists.

## Edge Cases

- **No playlists exist:** dock shows only pinned + the "+" new playlist button
- **Empty playlist:** stack shows with no card preview, just icon + "0 cards"
- **Playlist limit:** no hard limit on number of playlists, but dock shows max 3 (overflow for rest)
- **Default target when no playlists:** "+" button in card menu is hidden or disabled until a playlist exists

## Future Enhancements (Not in Scope)

- Playlist naming and description
- Publishing/sharing playlists
- Side-by-side split view for cross-playlist dragging
- Playlist reordering in the dock
- Triage walk-through mode (step through cards one by one)

## Verification

1. Create a playlist from the dock → appears as a new stack with auto color/icon
2. Add cards via "+" from the Timeline → card count updates, card appears in popover
3. Open popover → cards listed, reorderable, removable
4. Same card added to multiple playlists → works, shown in both
5. Delete a card → removed from all playlists automatically
6. Delete a playlist → cards unaffected
7. 4+ playlists → overflow button appears, links to columns page
8. Playlists index page → all playlists as columns with their cards
9. All actions work via turbo_stream without full page reload
