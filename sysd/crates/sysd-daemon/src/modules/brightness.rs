use sysd_proto::{BrightnessCmd, Payload, Response};
use tokio::fs;
use tracing::error;

const BACKLIGHT_BASE: &str = "/sys/class/backlight";

async fn find_backlight() -> Option<String> {
    let mut entries = fs::read_dir(BACKLIGHT_BASE).await.ok()?;
    // Prefer non-"acpi_video" entries (usually more accurate)
    let mut fallback = None;
    while let Ok(Some(entry)) = entries.next_entry().await {
        let name = entry.file_name().to_string_lossy().into_owned();
        if !name.starts_with("acpi_video") {
            return Some(name);
        }
        fallback = Some(name);
    }
    fallback
}

async fn read_u64(path: &str) -> anyhow::Result<u64> {
    let s = fs::read_to_string(path).await?;
    Ok(s.trim().parse()?)
}

async fn write_brightness(device: &str, raw: u64) -> anyhow::Result<()> {
    let path = format!("{BACKLIGHT_BASE}/{device}/brightness");
    fs::write(path, raw.to_string()).await?;
    Ok(())
}

pub async fn handle(cmd: BrightnessCmd) -> Response {
    let Some(device) = find_backlight().await else {
        return Response::err("no backlight device found in /sys/class/backlight");
    };

    let max_path = format!("{BACKLIGHT_BASE}/{device}/max_brightness");
    let cur_path = format!("{BACKLIGHT_BASE}/{device}/brightness");

    let (max, cur) = match tokio::try_join!(read_u64(&max_path), read_u64(&cur_path)) {
        Ok(v) => v,
        Err(e) => {
            error!("brightness read error: {e}");
            return Response::err(e.to_string());
        }
    };

    let percent = ((cur as f64 / max as f64) * 100.0).round() as u8;

    match cmd {
        BrightnessCmd::Get => Response::ok(Payload::Brightness { percent, raw: cur, max }),

        BrightnessCmd::Set { value } => {
            let value = value.clamp(1, 100);
            let new_raw = ((value as f64 / 100.0) * max as f64).round() as u64;
            match write_brightness(&device, new_raw).await {
                Ok(_) => Response::ok(Payload::Brightness { percent: value, raw: new_raw, max }),
                Err(e) => Response::err(format!("write failed (run as root or configure udev): {e}")),
            }
        }

        BrightnessCmd::Inc { step } => {
            let new_pct = (percent + step).min(100);
            let new_raw = ((new_pct as f64 / 100.0) * max as f64).round() as u64;
            match write_brightness(&device, new_raw).await {
                Ok(_) => Response::ok(Payload::Brightness { percent: new_pct, raw: new_raw, max }),
                Err(e) => Response::err(e.to_string()),
            }
        }

        BrightnessCmd::Dec { step } => {
            let new_pct = percent.saturating_sub(step).max(1);
            let new_raw = ((new_pct as f64 / 100.0) * max as f64).round() as u64;
            match write_brightness(&device, new_raw).await {
                Ok(_) => Response::ok(Payload::Brightness { percent: new_pct, raw: new_raw, max }),
                Err(e) => Response::err(e.to_string()),
            }
        }
    }
}
