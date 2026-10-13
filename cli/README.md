# Dotted CLI

From the repository root, run `cargo run --manifest-path cli/Cargo.toml -- help`
to see the commands and their input/output contract.

Create an access code on Dotted's web **Access codes** page. Copy it while it
is shown, then run:

```sh
cargo run --manifest-path cli/Cargo.toml -- auth login https://your-dotted-server.example
```

The CLI prompts for the code without echoing it, verifies it with Dotted, and
saves the server URL and code together in the operating system's credential
store. Run `cargo run --manifest-path cli/Cargo.toml -- auth check` to verify
the saved login. `cargo run --manifest-path cli/Cargo.toml -- auth logout`
removes the local copy; revoke the code on the web to disable it.
Logging in again replaces the saved login. HTTPS is required except for a
local server at `localhost` or `127.0.0.1`.

Run `cargo run --manifest-path cli/Cargo.toml -- bullet list` to read the
current page of bullets as indented JSON.
It returns at most 20 recent, incomplete bullets due through today. The output
goes to stdout; errors go to stderr with a nonzero exit status.

For a temporary login, set both `DOTTED_URL` and `DOTTED_TOKEN` in the process
environment. These override the saved login for that invocation. Do not put
codes in command arguments, shell history, source files, or logs. The CLI never
prints a code.

Access codes have full account access and remain valid until revoked. Dotted
shows the code only when it is created; see [the JSON API guide](../docs/json-api.md)
for the email-code flow used to create one. Remove a code through
`DELETE /access_codes/:id` when it is no longer needed.

Agents working in this repository can start with [AGENTS.md](../AGENTS.md).
