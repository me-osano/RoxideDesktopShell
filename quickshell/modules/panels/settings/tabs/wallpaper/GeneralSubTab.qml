import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common.theme
import qs.services
import qs.widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var screen

  signal openMainFolderPicker
  signal openMonitorFolderPicker(string monitorName)

  RToggle {
    label: "Enable wallpaper management"
    description: "Manage wallpapers with Roxide. Uncheck if you prefer using another application."
    checked: Settings.data.wallpaper.enabled
    onToggled: checked => Settings.data.wallpaper.enabled = checked
    defaultValue: Settings.getDefaultValue("wallpaper.enabled")
  }

  ColumnLayout {
    enabled: Settings.data.wallpaper.enabled
    spacing: Style.marginL
    Layout.fillWidth: true

    RowLayout {

      RLabel {
        label: "Wallpaper selector"
        description: "Choose your wallpaper."
        Layout.alignment: Qt.AlignTop
      }

      RIconButton {
        icon: "wallpaper-selector"
        tooltipText: "Wallpaper selector"
        onClicked: PanelService.getPanel("wallpaperPanel", root.screen)?.toggle()
      }
    }

    RComboBox {
      label: "Position"
      description: "Choose where the wallpaper selector panel appears."
      Layout.fillWidth: true
      model: [
        {
          "key": "follow_bar",
          "name": "Follow bar"
        },
        {
          "key": "center",
          "name": "Center"
        },
        {
          "key": "top_center",
          "name": "Top center"
        },
        {
          "key": "top_left",
          "name": "Top left"
        },
        {
          "key": "top_right",
          "name": "Top right"
        },
        {
          "key": "bottom_left",
          "name": "Bottom left"
        },
        {
          "key": "bottom_right",
          "name": "Bottom right"
        },
        {
          "key": "bottom_center",
          "name": "Bottom center"
        }
      ]
      currentKey: Settings.data.wallpaper.panelPosition
      onSelected: key => Settings.data.wallpaper.panelPosition = key
      defaultValue: Settings.getDefaultValue("wallpaper.panelPosition")
    }

    RComboBox {
      label: "Viewing mode"
      description: "Choose how wallpapers are displayed from your directory."
      Layout.fillWidth: true
      model: [
        {
          "key": "single",
          "name": "Root directory"
        },
        {
          "key": "recursive",
          "name": "Flattened subdirectories"
        },
        {
          "key": "browse",
          "name": "Browse directories"
        }
      ]
      currentKey: Settings.data.wallpaper.viewMode
      onSelected: key => Settings.data.wallpaper.viewMode = key
      defaultValue: Settings.getDefaultValue("wallpaper.viewMode")
    }

    RTextInputButton {
      id: wallpaperPathInput
      label: "Wallpaper folder"
      description: "Path to your main wallpaper folder."
      text: Settings.data.wallpaper.directory
      buttonIcon: "folder-open"
      buttonTooltip: "Wallpaper folder"
      Layout.fillWidth: true
      onInputEditingFinished: Settings.data.wallpaper.directory = text
      onButtonClicked: root.openMainFolderPicker()
    }

    RToggle {
      label: "Monitor-specific directories"
      description: "Set a different wallpaper folder for each monitor."
      checked: Settings.data.wallpaper.enableMultiMonitorDirectories
      onToggled: checked => Settings.data.wallpaper.enableMultiMonitorDirectories = checked
      defaultValue: Settings.getDefaultValue("wallpaper.enableMultiMonitorDirectories")
    }

    RBox {
      visible: Settings.data.wallpaper.enableMultiMonitorDirectories
      Layout.fillWidth: true
      radius: Style.radiusM
      color: Color.mSurface
      border.color: Color.mOutline
      border.width: Style.borderS
      implicitHeight: contentCol.implicitHeight + Style.margin2L
      clip: true

      ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM
        Repeater {
          model: Quickshell.screens || []
          delegate: ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            RText {
              text: (modelData.name || "Unknown")
              color: Color.mPrimary
              font.weight: Style.fontWeightBold
              pointSize: Style.fontSizeM
            }

            RTextInputButton {
              text: WallpaperService.getMonitorDirectory(modelData.name)
              buttonIcon: "folder-open"
              buttonTooltip: "Monitor wallpaper folder"
              Layout.fillWidth: true
              onInputEditingFinished: WallpaperService.setMonitorDirectory(modelData.name, text)
              onButtonClicked: root.openMonitorFolderPicker(modelData.name)
            }
          }
        }
      }
    }
  }

  RDivider {
    Layout.fillWidth: true
    visible: CompositorService.isNiri
  }

  ColumnLayout {
    visible: CompositorService.isNiri
    enabled: Settings.data.wallpaper.enabled
    spacing: Style.marginL
    Layout.fillWidth: true

    RToggle {
      label: "Enable overview wallpaper"
      description: "Applies a blurred and dimmed wallpaper to the overview screen."
      checked: Settings.data.wallpaper.enabled && Settings.data.wallpaper.overviewEnabled
      onToggled: checked => Settings.data.wallpaper.overviewEnabled = checked
      defaultValue: Settings.getDefaultValue("wallpaper.overviewEnabled")
    }

    RValueSlider {
      Layout.fillWidth: true
      enabled: Settings.data.wallpaper.overviewEnabled
      label: "Overview blur strength"
      description: "Applies the blur strength to the overview."
      visible: CompositorService.isNiri
      from: 0.0
      to: 1.0
      stepSize: 0.01
      showReset: true
      value: Settings.data.wallpaper.overviewBlur
      onMoved: value => Settings.data.wallpaper.overviewBlur = value
      text: ((Settings.data.wallpaper.overviewBlur) * 100).toFixed(0) + "%"
      defaultValue: Settings.getDefaultValue("wallpaper.overviewBlur")
    }

    RValueSlider {
      Layout.fillWidth: true
      enabled: Settings.data.wallpaper.overviewEnabled
      label: "Overview tint strength"
      description: "Applies the tint strength to the overview."
      visible: CompositorService.isNiri
      from: 0.0
      to: 1.0
      stepSize: 0.01
      showReset: true
      value: Settings.data.wallpaper.overviewTint
      onMoved: value => Settings.data.wallpaper.overviewTint = value
      text: ((Settings.data.wallpaper.overviewTint) * 100).toFixed(0) + "%"
      defaultValue: Settings.getDefaultValue("wallpaper.overviewTint")
    }
  }
}
