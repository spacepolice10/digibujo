# Digibujo

A digital Bullet Journal — keyboard-driven rapid logging, daily/monthly logs, collections, review workspace, and migration-aware bullets. Built with **Rails 8**, **Hotwire** (Turbo + Stimulus), **Lexxy** (Action Text), and **SQLite** (Solid Queue/Cache/Cable). No React, no Node build step.

## License

Source-available under the **[O'Saasy License](LICENSE)** ([osaasy.dev](https://osaasy.dev)).

You may use, modify, and distribute the code freely. The one restriction: you **cannot offer Digibujo (or a derivative) as a hosted SaaS** where the primary value is this app's functionality. Self-hosting for personal or team use is fine.

## Setup

Prerequisites: Ruby (see `.ruby-version`), SQLite, [mise](https://mise.jdx.dev) recommended.

```bash
bin/setup
bin/dev
```

## Tests and CI

```bash
bin/rails test
bin/ci
```

CI runs Minitest, RuboCop, Brakeman, and dependency audits.

## Security

Report vulnerabilities: [SECURITY.md](SECURITY.md)

## Documentation

- **Architecture and conventions:** [ARCHITECTURE.md](ARCHITECTURE.md)
- **Framework reference (Rails, Turbo, Stimulus, Lexxy):** [docs/](docs/)
- **Agent/coding workflow (for AI assistants):** [AGENTS.md](AGENTS.md)

## Stack

| Layer | Choice |
|-------|--------|
| Backend | Rails 8.1, Ruby 3.4 |
| Frontend | Hotwire, Importmap, custom CSS (Propshaft) |
| Database | SQLite (+ FTS5 search) |
| Jobs | Solid Queue (in-process with Puma) |
| Deploy | Kamal, Thruster |
