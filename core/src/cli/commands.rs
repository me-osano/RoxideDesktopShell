<file_path>
Projects/rustiqshell/core/src/cli/commands.rs
</file_path>

<edit_description>
Add CLI command structure for RustiqShell
</edit_description>
```

```Projects/rustiqshell/core/src/cli/commands.rs
use clap::{Parser, Subcommand};

/// RustiqShell CLI
#[derive(Parser)]
#[command(name = "rustiqshell")]
#[command(about = "Command-line interface for RustiqShell", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

/// Available commands for RustiqShell
#[derive(Subcommand)]
pub enum Commands {
    /// Start the RustiqShell daemon
    Start {
        /// Run in the foreground
        #[arg(short, long)]
        foreground: bool,
    },

    /// Stop the RustiqShell daemon
    Stop,

    /// Restart the RustiqShell daemon
    Restart,

    /// Check the status of the RustiqShell daemon
    Status,

    /// Manage brightness settings
    Brightness {
        #[command(subcommand)]
        action: BrightnessAction,
    },

    /// Manage plugins
    Plugins {
        #[command(subcommand)]
        action: PluginAction,
    },

    /// Pick a color using the Wayland color picker
    ColorPick {
        /// Output format (hex, rgb, hsv, json)
        #[arg(short, long, default_value = "hex")]
        format: String,

        /// Automatically copy the color to the clipboard
        #[arg(short, long)]
        auto_copy: bool,
    },
}

/// Actions for brightness management
#[derive(Subcommand)]
pub enum BrightnessAction {
    /// List available displays
    List,

    /// Set brightness for a specific display
    Set {
        /// Display identifier
        display: String,

        /// Brightness level (0-100)
        level: u8,
    },
}

/// Actions for plugin management
#[derive(Subcommand)]
pub enum PluginAction {
    /// Search for plugins
    Search {
        /// Plugin name or keyword
        query: String,
    },

    /// Install a plugin
    Install {
        /// Plugin name
        name: String,
    },

    /// Remove a plugin
    Remove {
        /// Plugin name
        name: String,
    },
}
