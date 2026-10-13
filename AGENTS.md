# Dotted CLI for agents

Use the Rust CLI in `cli/` when a task calls for Dotted data. From the repository
root, discover its current commands with:

```sh
cargo run --manifest-path cli/Cargo.toml -- help
```

The built-in help is the command contract for agents using only the binary.
Only commands listed there are executable.

## Connection and credentials

- A human creates an access code on the web, then runs `dotted-cli auth login URL`
  and pastes the code into the hidden prompt. The CLI saves it in the system
  credential store. Agents can use the saved login without receiving the code.
- For temporary credentials, the caller can supply both `DOTTED_URL` and
  `DOTTED_TOKEN` in the process environment. They override the saved login.
- Never put the token in command arguments, source files, logs, or responses.
  If there is no saved login, ask the human to run `auth login` in their own
  terminal and paste the code at the hidden prompt.
- Access codes grant full account access; Dotted has no code roles or scopes.
  HTTPS is required except for local HTTP.

## Current command contract

```sh
cargo run --manifest-path cli/Cargo.toml -- auth check
cargo run --manifest-path cli/Cargo.toml -- bullet list
```

`auth check` exits successfully when the code is accepted. `bullet list` writes
a JSON array to stdout. It currently returns at most 20 recent, incomplete
bullets due through today. It does not read all pages, completed bullets, or
future bullets. Errors go to stderr with a nonzero exit status. Consult
`cli/README.md` for setup and `docs/json-api.md` for the underlying API.
