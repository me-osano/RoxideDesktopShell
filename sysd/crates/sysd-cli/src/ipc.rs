use anyhow::{Context, Result};
use sysd_proto::{socket_path, Request, Response};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;

pub async fn send(req: Request) -> Result<Response> {
    let path = socket_path();

    let stream = UnixStream::connect(&path)
        .await
        .with_context(|| format!("cannot connect to sysd at {path} — is `sysdd` running?"))?;

    let (reader, mut writer) = stream.into_split();

    let mut line = serde_json::to_string(&req)?;
    line.push('\n');
    writer.write_all(line.as_bytes()).await?;

    let mut buf = String::new();
    BufReader::new(reader).read_line(&mut buf).await?;

    let response: Response = serde_json::from_str(buf.trim())
        .with_context(|| format!("invalid response from daemon: {buf}"))?;

    Ok(response)
}
