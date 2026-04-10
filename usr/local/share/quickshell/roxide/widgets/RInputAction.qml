import QtQuick
import QtQuick.Layouts
import qs.common.theme
import qs.widgets

// Input and button row
RowLayout {
  id: root

  // Public properties
  property string label: ""
  property string description: ""
  property string placeholderText: ""
  property string text: ""
  property string actionButtonText: "Test"
  property string actionButtonIcon: "media-play"
  property bool actionButtonEnabled: text !== ""

  // Signals
  signal editingFinished
  signal actionClicked

  // Internal properties
  spacing: Style.marginM

  RTextInput {
    id: textInput
    label: root.label
    description: root.description
    placeholderText: root.placeholderText
    text: root.text
    onEditingFinished: {
      root.text = text;
      root.editingFinished();
    }
    Layout.fillWidth: true
  }

  RButton {
    Layout.fillWidth: false
    Layout.alignment: Qt.AlignBottom

    text: root.actionButtonText
    icon: root.actionButtonIcon
    backgroundColor: Color.mSecondary
    textColor: Color.mOnSecondary
    hoverColor: Color.mHover
    enabled: root.actionButtonEnabled

    onClicked: {
      root.actionClicked();
    }
  }
}
