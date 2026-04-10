use sysd_proto::{ClipboardCmd, Payload, Response};
use tokio::process::Command;

pub async fn handle(cmd: ClipboardCmd) -> Response {
    match cmd {
        ClipboardCmd::Get => {
            // wl-paste reads from the Wayland clipboard
            // --no-newline strips trailing newline
            match Command::new("wl-paste").arg("--no-newline").output().await {
                Ok(out) if out.status.success() => {
                    let content = String::from_utf8_lossy(&out.stdout).into_owned();
                    Response::ok(Payload::Clipboard { content: Some(content) })
                }
                Ok(out) => {
                    // Exit code 1 from wl-paste usually means clipboard is empty
                    let stderr = String::from_utf8_lossy(&out.stderr).into_owned();
                    if stderr.contains("nothing is copied") || out.stdout.is_empty() {
                        Response::ok(Payload::Clipboard { content: None })
                    } else {
                        Response::err(stderr)
                    }
                }
                Err(e) => Response::err(format!("wl-paste not found — install wl-clipboard: {e}")),
            }
        }

        ClipboardCmd::Set { content } => {
            // wl-copy reads from stdin
            let mut child = match Command::new("wl-copy")
                .stdin(std::process::Stdio::piped())
                .spawn()
            {
                Ok(c) => c,
                Err(e) => return Response::err(format!("wl-copy failed: {e}")),
            };

            if let Some(mut stdin) = child.stdin.take() {
                use tokio::io::AsyncWriteExt;
                if let Err(e) = stdin.write_all(content.as_bytes()).await {
                    return Response::err(e.to_string());
                }
            }

            match child.wait().await {
                Ok(status) if status.success() => Response::ok(Payload::Unit),
                Ok(status) => Response::err(format!("wl-copy exited with {status}")),
                Err(e) => Response::err(e.to_string()),
            }
        }

        ClipboardCmd::Clear => {
            // wl-copy --clear clears the clipboard
            match Command::new("wl-copy").arg("--clear").status().await {
                Ok(s) if s.success() => Response::ok(Payload::Unit),
                Ok(s) => Response::err(format!("wl-copy --clear exited with {s}")),
                Err(e) => Response::err(format!("wl-copy not found: {e}")),
            }
        }
    }
}
