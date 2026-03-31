// RUSTIQ Shell — entrypoint
// Launch with: quickshell -p ~/.config/rustiq/quickshell

import Quickshell
import QtQuick

ShellRoot {
    // Bar on every screen
    Variants {
        model: Quickshell.screens

        Bar {
            screen: modelData
        }
    }

    // Overlays (one instance, not per-screen)
    Launcher {}
    NotificationCenter {}
    OsdOverlay {}
}
