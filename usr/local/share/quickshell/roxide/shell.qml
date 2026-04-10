/*
* RoxideDesktopShell – made by https://github.com/me-osano
* Licensed under the MIT License.
* Forks and modifications are allowed under the MIT License,
* but proper credit must be given to the original author.
*/

//@ pragma Env QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi,vdpau
//@ pragma Env QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=vaapi,vdpau

// Qt & Quickshell Core
import QtQuick
import Quickshell

// Common
import qs.common.theme
import qs.common.components

// Modules
import qs.modules.background
import qs.modules.bar
import qs.modules.desktopWidgets
import qs.modules.dock
import qs.modules.lockScreen
import qs.modules.mainScreen
import qs.modules.notification
import qs.modules.osd
import qs.modules.panels.launcher
import qs.modules.panels.settings
import qs.modules.toast

// Services
import qs.services

ShellRoot {
  id: root

  property bool settingsLoaded: false
  property bool shellStateLoaded: false

  Component.onCompleted: {
    Logger.i("Shell", "---------------------------");
    Logger.i("Shell", "Roxide Hello!");
  }

  Connections {
    target: Quickshell
    function onReloadCompleted() {
      Quickshell.inhibitReloadPopup();
    }
    function onReloadFailed() {
      if (!Settings?.isDebug) {
        Quickshell.inhibitReloadPopup();
      }
    }
  }

  Connections {
    target: Settings ? Settings : null
    function onSettingsLoaded() {
      settingsLoaded = true;
    }
  }

  Connections {
    target: ShellState ? ShellState : null
    function onIsLoadedChanged() {
      if (ShellState.isLoaded) {
        shellStateLoaded = true;
      }
    }
  }

  Loader {
    active: settingsLoaded && shellStateLoaded

    sourceComponent: Item {
      Component.onCompleted: {
        Logger.i("Shell", "---------------------------");

        // Critical services needed for initial UI rendering
        WallpaperService.init();
        ImageCacheService.init();
        AppThemeService.init();
        ColorSchemeService.init();
        DarkModeService.init();

        // Defer non-critical services to unblock first frame
        Qt.callLater(function () {
          LocationService.init();
          NightLightService.apply();
          BluetoothService.init();
          PowerProfileService.init();
          HostService.init();
          CustomButtonIPCService.init();
          IPCService.init(screenDetector);

          // Force ClipboardService initialization so clipboard watchers
          // start immediately instead of waiting for first launcher open
          if (Settings.data.appLauncher.enableClipboardHistory) {
            ClipboardService.checkCliphistAvailability();
          }
        });

        delayedInitTimer.running = true;
      }

      Overview {}
      Background {}
      DesktopWidgets {}
      AllScreens {}
      Dock {}
      Notification {}
      ToastOverlay {}
      OSD {}

      // Launcher overlay window (for overlay layer mode)
      Loader {
        active: Settings.data.appLauncher.overviewLayer
        sourceComponent: Component {
          LauncherOverlayWindow {}
        }
      }

      LockScreen {}
      FadeOverlay {}
      
      // Settings window mode (single window across all monitors)
      SettingsPanelWindow {}

      // Shared screen detector for IPC
      CurrentScreenDetector {
        id: screenDetector
      }

      // IPCService is a singleton, initialized via init() in deferred services block
    }
  }

  // ---------------------------------------------
  // Delayed initialization
  // ----------------------
  Timer {
    id: delayedInitTimer
    running: false
    interval: 1500
    onTriggered: {
      FontService.init();
    }
  }
}
