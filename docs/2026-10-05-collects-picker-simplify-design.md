# Collects picker: simplify list (design)

## Goal

Simplify the bulk-menu “Save to collection” picker: show name-focused rows, fix live-search turbo replace, drop pagination, keep search with a hard cap of 10 results.

## Decisions

- **Row content:** coloured collection icon + name. Drop bullet count and created date.
- **Limit:** server-side `.limit(10)` after `matching_name` / `order(:name)`. No GearedPagination in this picker.
- **Search:** keep existing combobox → turbo-stream flow and `matching_name`.
- **Turbo replace target:** one stable wrapper id (`collects-collections-list`) that includes “New collection” and the collections `<ul>`, so search replace does not duplicate or orphan nodes.

## Approach

Controller returns at most 10 collections; remove `@collections_page` / `collectables_page`.

Views:

- `_collection.html.erb` — icon + name only.
- `_collections_list.html.erb` — no `pagination/paginated_list`; wrap list in `#collects-collections-list`.
- `_picker.html.erb` / `new.html.erb` — stop passing `collections_page`.
- `new.turbo_stream.erb` — replace `collects-collections-list`.

## Out of scope

- Changing how collect create works.
- Changing “New collection” navigation.
- Client-side filtering of a full collection list.

## Tests

Update `test/controllers/bullets/collects_controller_test.rb`:

- No pagination container / `collections_page` behavior.
- Turbo stream replaces `collects-collections-list`.
- Search still filters; response shows at most 10 collections when more exist.
- Collection row no longer renders bullet-count / date metadata.
