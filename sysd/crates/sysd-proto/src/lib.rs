use serde::{Deserialize, Serialize};

// ── Requests ──────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "cmd", rename_all = "snake_case")]
pub enum Request {
    Brightness(BrightnessCmd),
    Bluetooth(BluetoothCmd),
    Network(NetworkCmd),
    Clipboard(ClipboardCmd),
    Notify(NotifyCmd),
    Ping,
}

// Brightness
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum BrightnessCmd {
    Get,
    Set { value: u8 },   // 0–100 percent
    Inc { step: u8 },
    Dec { step: u8 },
}

// Bluetooth
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum BluetoothCmd {
    Status,
    Toggle,
    Enable,
    Disable,
    Scan,
    Connect { address: String },
    Disconnect { address: String },
    ListDevices,
}

// Network
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum NetworkCmd {
    Status,
    List,
    Connect { ssid: String, password: Option<String> },
    Disconnect,
    Toggle,
}

// Clipboard
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum ClipboardCmd {
    Get,
    Set { content: String },
    Clear,
}

// Notify
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum NotifyCmd {
    Send {
        summary: String,
        body: Option<String>,
        icon: Option<String>,
        urgency: Option<Urgency>,
        timeout: Option<i32>, // ms, -1 = never
    },
    Close { id: u32 },
    CloseAll,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum Urgency {
    Low,
    #[default]
    Normal,
    Critical,
}

// ── Responses ─────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum Response {
    Ok(Payload),
    Err { message: String },
}

impl Response {
    pub fn ok(payload: Payload) -> Self {
        Response::Ok(payload)
    }
    pub fn err(msg: impl Into<String>) -> Self {
        Response::Err { message: msg.into() }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum Payload {
    Pong,
    Brightness { percent: u8, raw: u64, max: u64 },
    Bluetooth { enabled: bool, devices: Vec<BtDevice> },
    Network { connected: bool, ssid: Option<String>, interfaces: Vec<NetInterface> },
    Clipboard { content: Option<String> },
    Notification { id: u32 },
    Unit,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BtDevice {
    pub address: String,
    pub name: String,
    pub connected: bool,
    pub paired: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetInterface {
    pub name: String,
    pub kind: String, // "wifi", "ethernet", "loopback"
    pub state: String,
    pub ssid: Option<String>,
}

// ── Socket path helper ────────────────────────────────────────────────────────

pub fn socket_path() -> String {
    let runtime = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    format!("{runtime}/sysd.sock")
}
