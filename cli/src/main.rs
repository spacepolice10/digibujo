mod auth;
mod credentials;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();

    match args.as_slice() {
        [] => print_help(),
        [help] if matches!(help.as_str(), "help" | "--help" | "-h") => print_help(),
        [auth, login, url] if auth == "auth" && login == "login" => {
            if let Err(message) = credentials::login(url) {
                eprintln!("{message}");
                std::process::exit(1);
            }
            println!("Dotted login saved in the system credential store.");
        }
        [auth, logout] if auth == "auth" && logout == "logout" => {
            if let Err(message) = credentials::logout() {
                eprintln!("{message}");
                std::process::exit(1);
            }
            println!(
                "Dotted login removed from this device. Revoke the access code on the web if needed."
            );
        }
        [auth, check] if auth == "auth" && check == "check" => {
            if let Err(message) = auth::check_current() {
                eprintln!("{message}");
                std::process::exit(1);
            }
            println!("Authenticated with Dotted.");
        }
        [bullet, list] if bullet == "bullet" && list == "list" => {
            match auth::get_json_with_current_login("/bullets.json")
                .and_then(|json| format_bullet_list(&json))
            {
                Ok(bullets) => println!("{bullets}"),
                Err(message) => {
                    eprintln!("{message}");
                    std::process::exit(1);
                }
            }
        }
        [command, ..] => {
            eprintln!("Unknown command: {command}. Run 'dotted-cli help' for available commands.");
            std::process::exit(2);
        }
    }
}

fn format_bullet_list(json: &str) -> Result<String, String> {
    let bullets: Vec<serde_json::Value> = serde_json::from_str(json)
        .map_err(|_| "Dotted returned an invalid bullet list.".to_string())?;
    serde_json::to_string_pretty(&bullets)
        .map_err(|_| "Could not format Dotted's bullet list.".to_string())
}

fn print_help() {
    println!(
        "Dotted CLI\n\nUsage: dotted-cli <command>\n\nCommands:\n  help            Show this command contract; no credentials needed\n  auth login URL  Verify and save a web-created access code; prompts without echo\n  auth check      Verify the saved login with Dotted\n  auth logout     Remove the saved login from this device (does not revoke code)\n  bullet list     Print a formatted JSON array of bullets to stdout\n\nAuthentication:\n  Create an access code in Dotted's web Access codes page, then run auth login\n  with the server origin, such as https://dotted.example.com. Paste the code\n  when prompted. The code is stored in the system credential store.\n  DOTTED_URL and DOTTED_TOKEN may both be set to use temporary environment\n  credentials instead. Never put access codes in command arguments or logs.\n  Access codes grant full account access. HTTPS is required except on localhost.\n\nOutput contract:\n  bullet list returns at most 20 recent, incomplete bullets due through today.\n  It does not include completed or future bullets or fetch additional pages.\n  Errors go to stderr with a nonzero exit status; stdout is for results.\n  Unknown commands exit 2. Only the commands above are implemented."
    );
}

#[cfg(test)]
mod tests {
    use super::format_bullet_list;

    #[test]
    fn bullet_list_is_readable_json_with_original_field_order() {
        let input = r#"[{"id":1,"body":"First\nsecond","done":false}]"#;
        let formatted = format_bullet_list(input).unwrap();
        assert_eq!(
            formatted,
            "[\n  {\n    \"id\": 1,\n    \"body\": \"First\\nsecond\",\n    \"done\": false\n  }\n]"
        );
        assert!(format_bullet_list("not json").is_err());
        assert!(format_bullet_list("{}").is_err());
    }
}
