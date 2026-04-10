#!/usr/bin/env bash

QT_QML_PATH="/usr/lib/qt6/qml:/usr/lib/qt6/qml/QtQuick:/usr/lib/qt6/qml/QtQuick/Layouts:/usr/lib/qt6/qml/QtQuick/Controls:/usr/lib/qt6/qml/QtQml"
QT_PLUGIN_PATH="/usr/lib/qt6/plugins:/usr/lib/qt6/plugins/platforms:/usr/lib/qt6/plugins/wayland-shell"

check_quickshell() {
    if command -v quickshell &> /dev/null; then
        echo "Found quickshell: $(which quickshell)"
        return 0
    else
        echo "Warning: quickshell not found in PATH"
        echo "You may need to build or install quickshell separately"
        return 1
    fi
}

check_dependencies() {
    local missing=()
    
    for pkg in niri quickshell; do
        if ! command -v "$pkg" &> /dev/null; then
            missing+=("$pkg")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Warning: Missing dependencies: ${missing[*]}"
        echo "Install them via your package manager"
    else
        echo "All required dependencies found"
    fi
}

setup_environment() {
    if [ -n "${QT_QML_IMPORT_PATH:-}" ]; then
        export QT_QML_IMPORT_PATH="$QT_QML_IMPORT_PATH:$QT_QML_PATH"
    else
        export QT_QML_IMPORT_PATH="$QT_QML_PATH"
    fi
    
    if [ -n "${QT_PLUGIN_PATH:-}" ]; then
        export QT_PLUGIN_PATH="$QT_PLUGIN_PATH:$QT_PLUGIN_PATH"
    else
        export QT_PLUGIN_PATH="$QT_PLUGIN_PATH"
    fi
    
    export RUSTIQ_LOG=info
}

run_rustiq() {
    setup_environment
    
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/rustiq"
    
    rustiq daemon &
    local rustiq_pid=$!
    sleep 2
    
    quickshell -c "$config_dir"
    
    wait $rustiq_pid
}

check_dependencies
check_quickshell
setup_environment

echo ""
echo "Environment configured. Run 'rustiq daemon' and then 'quickshell -c ~/.config/rustiq'"