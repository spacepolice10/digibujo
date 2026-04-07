# Playlist Picker Modal — Design Spec

## Context

The card dropdown already has an "Add to Playlist" action that quick-adds to the most recently created playlist. There is no way to choose a different playlist. This spec adds a "Choose Playlist…" item that opens a modal picker.

## Decisions

- **Trigger:** "Add to Playlist" (quick-add to latest) stays unchanged. A new "Choose Playlist…" item below it opens the picker modal.
- **Modal interaction:** Tapping a playlist row instantly adds or removes the card and closes the modal (single-select, no "Done" step).
- **Implementation:** Dedicated GET route + controller serving a turbo-frame modal. Reuses the existing `<dialog>` + `dialog_controller` infrastructure.

## Routes

Add inside `resources :cards` in `config/routes.rb`:

```ruby
resource :playlist_picker, only: :show, module: :cards
```

Gives: `GET /cards/:card_id/playlist_picker` → `Cards::PlaylistPickersController#show`

## Controller

New file `app/controllers/cards/playlist_pickers_controller.rb`:

```ruby
class Cards::PlaylistPickersController < ApplicationController
  def show
    @card = Current.user.cards.find(params[:card_id])
    @playlists = Current.user.playlists.order(created_at: :desc)
    @membership = PlaylistCard.where(playlist: @playlists, card: @card).index_by(&:playlist_id)
  end
end
```

## View

New file `app/views/cards/playlist_pickers/show.html.erb`. Wrapped in `<turbo-frame id="modal">` so it loads into the existing dialog. Contains:

- **Header:** "Add to playlist" title + close button (`data-action="dialog#close"`)
- **Playlist rows:** One per playlist, ordered newest first. Each row shows the playlist's colored icon + card count. Rows where the card is already a member show a filled checkmark and submit `DELETE` to `playlist_card_path(playlist, @membership[playlist.id])`. Rows where it is not a member submit `POST` to `playlist_cards_path(playlist)` with `card_id: @card.id`.
- **New playlist row:** Dashed-border "+" at the bottom. Submits `POST` to `playlists_path` with `card_id: @card.id`.

The `dialog_controller` already listens for `turbo:submit-end` on the `<dialog>` element and calls `close()` on success — no extra JS needed.

## Card Dropdown Change

In `app/views/cards/_card.html.erb`, add a new `link_to` after the existing "Add to Playlist" `button_to`:

```erb
<% if @latest_playlist %>
  <%= link_to card_playlist_picker_path(card),
        data: { turbo_frame: "modal", action: "dialog#open" },
        class: "card-dropdown-item" do %>
    <span class="card-dropdown-icon card-dropdown-icon--chooser">
      <span class="icon" style="--icon-mask: var(--icon-list)"></span>
    </span>
    <span class="card-dropdown-text">
      <span class="card-dropdown-label">Choose Playlist…</span>
      <span class="card-dropdown-desc">Pick from all playlists</span>
    </span>
  <% end %>
<% end %>
```

Guarded by `@latest_playlist` (same as the quick-add button) — both items are hidden when the user has no playlists.

## PlaylistsController#create change

`PlaylistsController#create` is extended to optionally create a `PlaylistCard` when `params[:card_id]` is present. After `@playlist.save`, if `card_id` is provided, find the card scoped to `Current.user` and create a `PlaylistCard` at position 1. The existing `turbo_stream` response template handles the dock update; the dialog closes via `submitEnd`.

## Styling

New `.playlist-picker` CSS block added to `app/assets/stylesheets/playlists.css`:

- `playlist-picker` — the dialog content container
- `playlist-picker__header` — flex row with title + close button
- `playlist-picker__row` — each playlist row (similar structure to `.card-dropdown-item`)
- `playlist-picker__row--added` — state when card is already in playlist (subtle highlight background, filled check)
- `playlist-picker__icon` — colored dot using `colour_bg_variable` / `colour_variable` inline styles
- `playlist-picker__check` — circle toggle indicator
- `playlist-picker__new-row` — "New playlist" row with dashed border icon

All values use existing CSS variables — no new variables added.

## Turbo Stream Responses

No new turbo_stream templates needed for the picker itself. The existing `playlists/cards/create.turbo_stream.erb` and `destroy.turbo_stream.erb` update the dock. The dialog closes automatically via `dialog_controller#submitEnd`.

## Edge Cases

- **No playlists:** "Choose Playlist…" is hidden (guarded by `@latest_playlist` check, same as quick-add).
- **Card already in all playlists:** All rows show checkmark state; tapping any removes it.
- **Single playlist:** Modal shows one row + "New playlist" — works the same.

## Out of Scope

- Naming playlists in the modal
- Reordering playlists in the picker
- Updating the quick-add button state in the card dropdown after a modal action (minor staleness; corrects on next page load)
