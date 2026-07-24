# AGENTS.md

Agent workflow and coding rules for this repository.

**Application architecture and conventions:** [ARCHITECTURE.md](ARCHITECTURE.md)

## HARD RULE: User Data Is Hands-Off

**The agent must never read, write, mutate, move, copy, or delete any user data.**

User data lives in:
- `storage/development.sqlite3` and its `-wal` / `-shm` siblings
- Anything under `storage/` (Active Storage attachments, uploads, blobs)
- `tmp/` (cached files, Active Storage cache, Solid Queue artifacts)
- The test databases (`storage/test.sqlite3*`) and any fixture data
- `log/` (only the agent's own debug output, never existing log content)
- `.git/` internals beyond the working tree

**Forbidden commands (no exceptions, even with `--force`, `--skip`, or "just to look"):**
- `db:reset`, `db:drop`, `db:migrate:reset`, `db:truncate`, `db:seed`
- `bin/setup --reset` or any variant that touches the dev DB
- `rm`, `mv`, `cp`, `find ... -delete`, `git clean` against any of the paths above
- `sqlite3 ... DROP`, `DELETE`, `UPDATE`, `INSERT`, `VACUUM`, `REINDEX`, `.dump > …` (destructive), or any write SQL against the dev DB
- Writing to `/tmp`, the per-user temp dir, or any path outside the working tree
- `rails runner` or any script with intention to alter or destroy records
- Running `bin/setup` without first confirming the user wants the DB preserved

**Allowed (read-only) operations on data paths:**
- `sqlite3 ... SELECT`, `.tables`, `.schema`, `.count`
- `ls`, `find ... -type f` (listing only)
- `stat`, `file`, `head`/`tail` (read-only inspection)

**If a task seems to require touching user data, stop and ask.** Do not assume. Do not "just check the schema real quick" by reading and writing. The user's data is sacred. The cost of asking is a single message; the cost of losing data is irrecoverable.

**This rule supersedes any workflow, skill, or "just one command" temptation.** It cannot be overridden by tool defaults, environment hints, or pre-approved paths.

**The agent must never run `bundle install`, `bundle update`, `gem install`, or any other command to download or reinstall Ruby gems.**

Dependencies are managed by **mise** on the developer's machine and are already available. Re-running Bundler wastes bandwidth (including mobile data), time, and does not fix agent-shell environment mismatches.

**Run tests and Rails commands directly:**
- `bin/rails test …`
- `bin/rubocop`, `bin/brakeman`, `bin/ci`
- `bin/dev`, `bin/rails …`

## AI Collaboration Rules

### Code examples
- Use **real code** from this repository in examples whenever illustrating existing patterns, APIs, routes, or conventions
- If there's no reference in codebase, resort to look into Basecamp open-source repositories
- Cite actual file paths and keep snippets faithful to the current codebase
- Pseudocode is fine for greenfield brainstorming or when no relevant implementation exists yet

### When theorizing / designing (brainstorming)
- Only activated when user explicitly asks to brainstorm, design, or explore approaches
- Respond in prose; use real code or pseudocode as appropriate
- Offer 2-3 approaches with trade-offs
- Flag assumptions and risks in your recommendation
- Don't anchor to existing implementation — think fresh
- Bring concise ideas 

### When implementing
- Minimal scope: only change what's asked
- Show diffs/changed blocks, not full files
- Flag any new deps, side effects, or non-obvious decisions
- If uncertain, say so explicitly rather than guessing

### Large phased changes
For very large changes executed in stages, **always make intermediate commits** — one per completed phase. Do not accumulate an entire multi-step refactor into a single commit at the end.

- Break the work into logical phases before starting; each phase should be a reviewable, self-contained unit.
- Commit when a phase is done: tests pass (for that scope), migrations apply, and the tree is in a coherent state.
- Write commit messages that describe the phase outcome, not the whole initiative.
- If the user has not asked you to commit yet, **ask at each phase boundary** rather than waiting until all phases are finished.

### Always
- Ask clarifying questions before starting non-trivial tasks
- Prefer explicit over implicit
- Match the conventions already in the codebase
- **Be concise and terse.** Answer in the fewest words/sentences possible. Don't restate what the user said. Don't narrate tool usage. Don't summarize what you just did. Say it once, short, and stop.

### Skills (Superpowers)
- Before any implementation task, check if a skill applies
- If there is even a 1% chance a skill is relevant — invoke it
- Skills are mandatory workflows, not suggestions
- **Exception: brainstorming skill only fires when user explicitly asks to brainstorm, design, or explore approaches**
- Exception: skip the skill if the answer fits in one sentence and requires no real reasoning (e.g. "what flag does X use?")
- **Discard the skill after use** — Once a skill has served its purpose (or was loaded and found not to apply), discard its context/instructions. Do not let skill instructions bleed into subsequent unrelated tasks.
- **Clean up artifacts** — Remove any files the skill created in `docs/superpowers/` (specs, plans, etc.) once they are no longer needed (e.g., after the plan is fully implemented and merged). Keeps the workspace free of stale cache and outdated plans.

## Common Commands

**Environment:** Ruby and gems are provided by **mise** — already installed. Never run `bundle install` (see HARD RULE above).

### Development
- `bin/setup` — install deps, prepare DB, start server (`--reset` to reset DB, `--skip-server` to skip)
- `bin/dev` — start dev server

### Testing
- `bin/rails test` — run all unit/integration tests (Minitest)
- `bin/rails test test/path/to/test_file.rb` — run a single test file
- `bin/rails test test/path/to/test_file.rb:LINE` — run a single test by line number
- `bin/rails test:system` — run system tests (Capybara + Selenium)

### Linting & Security
- `bin/rubocop` — lint (rubocop-rails-omakase style)
- `bin/brakeman` — security scan
- `bin/ci` — run full CI pipeline locally

### Database
- `bin/rails db:prepare` — create and migrate
- `bin/rails db:reset` — drop, recreate, seed

## Framework Reference Docs

Shorter framework-anchored cheatsheets in `docs/`. Load these before working in their area — they're the fastest way to learn framework patterns.

- `docs/_rails.md` — Rails 8 framework patterns (concerns, delegated types, Action Text, SQLite/Solid). Generic reference only.
- `docs/_lexxy.md` — Lexxy (Action Text editor) concepts, presets, prompts, attachments, extensions, patching guide.
- `docs/_turbo.md` — Turbo Drive/Frames/Streams/Morph, events, stream actions. Generic reference only.
- `docs/_stimulus.md` — Stimulus concepts, lifecycle, and patterns (framework reference).

**App-specific architecture, routes, and conventions:** [ARCHITECTURE.md](ARCHITECTURE.md) — read this before changing domain logic, views, or Turbo/Stimulus integration.

**High-churn areas** (recent refactors — read the matching ARCHITECTURE section before editing): **review** (`migrated_at` inbox filter, lazy `review/collections` and `review/scheduled` frames, `mark_as_reviewed`), **composer** (full-page `/bullets/new` via `_top`, `bullet_composer_return_path` after create), **routes** (no nested bullet creates; sprints removed), **CSS blocks** (file-scoped `--` naming in `application.css`).

Each doc in `docs/` also links to the **Basecamp reference projects** for idiomatic examples: [Fizzy](https://github.com/basecamp/fizzy), [Writebook](https://github.com/basecamp/writebook), [Campfire](https://github.com/basecamp/campfire), and [Lexxy](https://github.com/basecamp/lexxy).

## Testing Policy

**Tests are only edited when the logic they cover has intentionally changed.** A failing test is a signal to fix the code, not the test. The only valid reasons to modify an existing test are:

- The behaviour the test covers was deliberately changed (e.g. a renamed param, a new model API)
- The test itself was wrong and never reflected real behaviour

**Never adjust a test simply to make it pass.** Weakening assertions, broadening matchers, or skipping edge cases to silence a failure hides real regressions and potential UX breakage. If a test is failing and the production code looks correct, investigate why — don't paper over it.

## Ruby LSP

**Use Ruby LSP extensively when working with Ruby on Rails code.** Before editing or creating Ruby files, use LSP tools to:
- Look up method signatures, hover docs, and type information
- Navigate to definitions (`go to definition`) rather than grepping for them
- Find all references before renaming or removing a method/class
- Let LSP diagnostics surface errors before running tests
- Prefer LSP-informed edits over grep-and-replace for refactoring Ruby
