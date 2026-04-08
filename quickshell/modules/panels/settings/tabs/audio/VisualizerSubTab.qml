import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common.theme
import qs.widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  RComboBox {
    label: "Visualization type"
    description: "Choose a visualization type for media playback."
    model: [
      {
        "key": "none",
        "name": "None"
      },
      {
        "key": "linear",
        "name": "Linear"
      },
      {
        "key": "mirrored",
        "name": "Mirrored"
      },
      {
        "key": "wave",
        "name": "Wave"
      }
    ]
    currentKey: Settings.data.audio.visualizerType
    defaultValue: Settings.getDefaultValue("audio.visualizerType")
    onSelected: key => Settings.data.audio.visualizerType = key
  }

  RComboBox {
    label: "Frame rate"
    description: "Higher rates are smoother but use more resources."
    model: [
      {
        "key": "30",
        "name": "{fps} FPS"
      },
      {
        "key": "60",
        "name": "{fps} FPS"
      },
      {
        "key": "100",
        "name": "{fps} FPS"
      },
      {
        "key": "120",
        "name": "{fps} FPS"
      },
      {
        "key": "144",
        "name": "{fps} FPS"
      },
      {
        "key": "165",
        "name": "{fps} FPS"
      },
      {
        "key": "240",
        "name": "{fps} FPS"
      }
    ]
    currentKey: Settings.data.audio.cavaFrameRate
    defaultValue: Settings.getDefaultValue("audio.cavaFrameRate")
    onSelected: key => Settings.data.audio.cavaFrameRate = key
  }
}
