# SYSMON - System Monitor

> Real-time system monitoring via IPC.

## Overview

The sysmon module provides real-time system metrics including CPU, memory, network, disk, and process information. It runs as two background workers:

1. **Main worker** - Updates every 2 seconds: CPU, memory, network, disks, load average
2. **Processes worker** - Updates every 5 seconds: detailed process list

## Data Structures

### SystemMonitor

Main snapshot containing all system metrics.

```rust
pub struct SystemMonitor {
    pub cpu: CpuInfo,           // CPU usage and frequency
    pub memory: MemInfo,        // Memory and swap usage
    pub network: Vec<NetIface>, // Network interfaces
    pub disks: Vec<DiskInfo>,   // Disk mount points
    pub processes: Vec<ProcessInfo>, // Top 20 processes by CPU
    pub uptime_secs: u64,       // System uptime in seconds
    pub load_avg: [f64; 3],     // 1min, 5min, 15min load average
}
```

### CpuInfo

```rust
pub struct CpuInfo {
    pub usage_percent: f32,     // Average CPU usage (0-100)
    pub per_core: Vec<f32>,     // Per-core usage percentages
    pub freq_mhz: u64,          // CPU frequency in MHz
    pub brand: String,          // CPU model name
    pub core_count: usize,      // Number of CPU cores
}
```

### MemInfo

```rust
pub struct MemInfo {
    pub total_kb: u64,         // Total memory in KB
    pub used_kb: u64,           // Used memory in KB
    pub available_kb: u64,     // Available memory in KB
    pub swap_total_kb: u64,    // Total swap in KB
    pub swap_used_kb: u64,     // Used swap in KB
    pub used_percent: f32,     // Memory usage percentage (0-100)
}
```

### NetIface

```rust
pub struct NetIface {
    pub name: String,          // Interface name (e.g., "wlan0")
    pub rx_bytes: u64,          // Total bytes received
    pub tx_bytes: u64,          // Total bytes transmitted
    pub rx_rate_bps: u64,       // Current receive rate (bytes/sec)
    pub tx_rate_bps: u64,       // Current transmit rate (bytes/sec)
}
```

### DiskInfo

```rust
pub struct DiskInfo {
    pub name: String,           // Device name (e.g., "/dev/sda1")
    pub mount: String,         // Mount point (e.g., "/")
    pub total_kb: u64,          // Total space in KB
    pub used_kb: u64,          // Used space in KB
    pub used_percent: f32,     // Usage percentage (0-100)
    pub fs_type: String,       // Filesystem type (e.g., "ext4")
}
```

### ProcessInfo

```rust
pub struct ProcessInfo {
    pub pid: u32,              // Process ID
    pub name: String,         // Process name
    pub cpu_percent: f32,     // CPU usage percentage
    pub mem_kb: u64,          // Memory usage in KB
    pub status: String,       // Process status (Run, Sleep, Stop, Zombie)
}
```

### SystemProcesses

Extended process data with counts and details.

```rust
pub struct SystemProcesses {
    pub total: usize,               // Total process count
    pub running: usize,             // Running processes
    pub sleeping: usize,            // Sleeping processes
    pub stopped: usize,             // Stopped processes
    pub zombie: usize,             // Zombie processes
    pub processes: Vec<ProcessDetail>, // All processes sorted by CPU
}
```

### ProcessDetail

Detailed process information.

```rust
pub struct ProcessDetail {
    pub pid: u32,           // Process ID
    pub name: String,       // Process name
    pub cmd: Vec<String>,   // Command line arguments
    pub exe: String,        // Executable path
    pub cpu_percent: f32,   // CPU usage percentage
    pub mem_percent: f32,   // Memory usage percentage
    pub mem_kb: u64,        // Memory in KB
    pub virtual_mem_kb: u64, // Virtual memory in KB
    pub status: String,     // Status (running, sleeping, stopped, zombie)
    pub user: String,       // User name
    pub start_time: u64,    // Start time (epoch)
    pub cpu_usage: f32,     // CPU usage (same as cpu_percent)
    pub num_threads: usize, // Number of threads
    pub root: String,       // Process root directory
}
```

## IPC Endpoints

### GET /sysmon

Returns the current `SystemMonitor` snapshot.

**Response:**

```json
{
  "cpu": {
    "usage_percent": 12.5,
    "per_core": [10.0, 15.0, 8.0, ...],
    "freq_mhz": 2400,
    "brand": "Intel(R) Core(TM) i7-9700K",
    "core_count": 8
  },
  "memory": {
    "total_kb": 16777216,
    "used_kb": 8388608,
    "available_kb": 6291456,
    "swap_total_kb": 2097152,
    "swap_used_kb": 0,
    "used_percent": 50.0
  },
  "network": [
    {
      "name": "wlan0",
      "rx_bytes": 1234567890,
      "tx_bytes": 987654321,
      "rx_rate_bps": 150000,
      "tx_rate_bps": 50000
    }
  ],
  "disks": [
    {
      "name": "/dev/sda1",
      "mount": "/",
      "total_kb": 250000000,
      "used_kb": 112500000,
      "used_percent": 45.0,
      "fs_type": "ext4"
    }
  ],
  "processes": [
    {
      "pid": 1234,
      "name": "chrome",
      "cpu_percent": 8.5,
      "mem_kb": 524288,
      "status": "Run"
    }
  ],
  "uptime_secs": 3600,
  "load_avg": [0.15, 0.20, 0.25]
}
```

### GET /sysmon/processes

Returns detailed process information (`SystemProcesses`).

**Response:**

```json
{
  "total": 256,
  "running": 4,
  "sleeping": 250,
  "stopped": 0,
  "zombie": 0,
  "processes": [
    {
      "pid": 1234,
      "name": "chrome",
      "cmd": ["chrome", "--type=renderer", ...],
      "exe": "/usr/bin/chromium",
      "cpu_percent": 8.5,
      "mem_percent": 3.2,
      "mem_kb": 524288,
      "virtual_mem_kb": 2097152,
      "status": "running",
      "user": "enosh",
      "start_time": 1234567890,
      "cpu_usage": 8.5,
      "num_threads": 12,
      "root": "/",
      "cpu_cumulative": 850.0
    }
  ]
}
```

## SSE Events

### sysmon_updated

Emitted every 2 seconds when system metrics are updated.

```json
{
  "type": "sysmon_updated",
  "data": { /* SystemMonitor */ }
}
```

## Usage

### CLI

```bash
# Get system monitor snapshot
roxide sysmon

# Verbose output
roxide sysmon --verbose

# JSON output
roxide sysmon --json
```

### IPC Socket

```bash
# Get sysmon snapshot
curl --unix-socket /run/user/1000/roxide.sock http://localhost/sysmon

# Get processes
curl --unix-socket /run/user/1000/roxide.sock http://localhost/sysmon/processes
```

### SSE Subscription

```bash
# Subscribe to sysmon updates
curl -N --unix-socket /run/user/1000/roxide.sock "http://localhost/events?filters=sysmon_updated"
```
