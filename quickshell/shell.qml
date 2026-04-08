import QtQuick
import Quickshell

ShellRoot {
    id: entrypoint

    readonly property bool runGreeter: Quickshell.env("RUSTIQ_RUN_GREETER") === "1" || Quickshell.env("RUSTIQ_RUN_GREETER") === "true"
    readonly property bool disableHotReload: Quickshell.env("RUSTIQ_DISABLE_HOT_RELOAD") === "1" || Quickshell.env("RUSTIQ_DISABLE_HOT_RELOAD") === "true"

    Component.onCompleted: {
        Quickshell.watchFiles = !disableHotReload;
    }

    Loader {
        id: rustiqShellLoader
        asynchronous: false
        sourceComponent: rustiqShell {}
        active: !entrypoint.runGreeter
    }

    Loader {
        id: rustiqGreeterLoader
        asynchronous: false
        sourceComponent: rustiqGreeter {}
        active: entrypoint.runGreeter
    }
}