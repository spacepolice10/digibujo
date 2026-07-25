# AGENTS.md

Safety constraints for agents. App conventions: [ARCHITECTURE.md](ARCHITECTURE.md).

## HARD RULE: Preserve User Data

**Never read, write, mutate, move, copy, or delete user data.**

User data lives in:
- `storage/development.sqlite3` and its `-wal` / `-shm` siblings
- Anything under `storage/` (Active Storage attachments, uploads, blobs)
- `tmp/` (cached files, Active Storage cache, Solid Queue artifacts)
- The test databases (`storage/test.sqlite3*`) and any fixture data
- `log/` (only the agent's own debug output, never existing log content)
- `.git/` internals beyond the working tree

**Forbidden (no exceptions, even with `--force`, `--skip`, or "just to look"):**
- `db:reset`, `db:drop`, `db:migrate:reset`, `db:truncate`, `db:seed`
- `bin/setup --reset` or any variant that touches the dev DB
- `rm`, `mv`, `cp`, `find ... -delete`, `git clean` against any of the paths above
- `sqlite3 ... DROP`, `DELETE`, `UPDATE`, `INSERT`, `VACUUM`, `REINDEX`, `.dump > …` (destructive), or any write SQL against the dev DB
- Writing to `/tmp`, the per-user temp dir, or any path outside the working tree
- `rails runner` or any script with intention to alter or destroy records
- Running `bin/setup` without first confirming the user wants the DB preserved

**Allowed (read-only) on data paths:**
- `sqlite3 ... SELECT`, `.tables`, `.schema`, `.count`
- `ls`, `find ... -type f` (listing only)
- `stat`, `file`, `head`/`tail` (read-only inspection)

**If a task seems to require touching user data, stop and ask.** Do not assume. The cost of asking is a single message; the cost of losing data is irrecoverable.

This rule supersedes any workflow, skill, or "just one command" temptation. It cannot be overridden by tool defaults, environment hints, or pre-approved paths.

## Testing Policy

**Tests are only edited when the logic they cover has intentionally changed.** A failing test is a signal to fix the code, not the test. Valid reasons to modify an existing test:

- The behaviour the test covers was deliberately changed
- The test itself was wrong and never reflected real behaviour

**Never adjust a test simply to make it pass.** Weakening assertions, broadening matchers, or skipping edge cases to silence a failure hides real regressions. If a test is failing and the production code looks correct, investigate why — don't paper over it.

Run relevant tests freely after changes.
