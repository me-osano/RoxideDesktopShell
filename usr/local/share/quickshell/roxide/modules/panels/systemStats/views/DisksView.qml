import QtQuick
import QtQuick.Layouts
import qs.common.theme
import qs.services
import qs.widgets

ColumnLayout {
  anchors.fill: parent
  spacing: Style.marginM

  // Disk I/O summary
  RBox {
    Layout.fillWidth: true
    implicitHeight: diskIoRow.implicitHeight + Style.margin2M

    RowLayout {
      id: diskIoRow
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginXL

      Column {
        Layout.fillWidth: true
        spacing: Style.marginXS

        Row {
          spacing: Style.marginXS

          RIcon {
            icon: "download-speed"
            pointSize: Style.fontSizeS
            color: Color.mPrimary
          }

          RText {
            text: "Read"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
          }
        }

        RText {
          text: "N/A"
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mPrimary
        }
      }

      Column {
        Layout.fillWidth: true
        spacing: Style.marginXS

        Row {
          spacing: Style.marginXS

          RIcon {
            icon: "upload-speed"
            pointSize: Style.fontSizeS
            color: Color.mSecondary
          }

          RText {
            text: "Write"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
          }
        }

        RText {
          text: "N/A"
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mSecondary
        }
      }
    }
  }

  // Mount points list
  RBox {
    Layout.fillWidth: true
    Layout.fillHeight: true

    ListView {
      anchors.fill: parent
      anchors.margins: Style.marginS
      clip: true

      model: {
        const mounts = [];
        for (const path in SystemStatService.diskPercents) {
          mounts.push({
            mount: path,
            percent: SystemStatService.diskPercents[path],
            used: SystemStatService.diskUsedGb[path],
            total: SystemStatService.diskSizeGb[path]
          });
        }
        return mounts;
      }

      delegate: Item {
        width: parent.width
        height: 56

        ColumnLayout {
          anchors.fill: parent
          spacing: Style.marginXS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            RIcon {
              icon: modelData.mount === "/" ? "home" : (modelData.mount === "/home" ? "person" : "folder")
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
            }

            RText {
              text: modelData.mount
              pointSize: Style.fontSizeS
              font.family: Settings.data.ui.fontFixed
              color: Color.mOnSurface
              Layout.fillWidth: true
              elide: Text.ElideMiddle
            }

            RText {
              text: modelData.percent + "%"
              pointSize: Style.fontSizeS
              font.weight: Style.fontWeightBold
              color: modelData.percent > 90 ? Color.mError : (modelData.percent > 80 ? Color.mTertiary : Color.mOnSurface)
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Color.mSurfaceVariant

            Rectangle {
              width: parent.width * Math.min(1, modelData.percent / 100)
              height: parent.height
              radius: 3
              color: modelData.percent > 90 ? Color.mError : (modelData.percent > 80 ? Color.mTertiary : Color.mPrimary)
            }
          }

          RText {
            text: (modelData.used || 0).toFixed(1) + " / " + (modelData.total || 0).toFixed(1) + " GB"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            font.family: Settings.data.ui.fontFixed
          }
        }
      }

      Rectangle {
        anchors.centerIn: parent
        visible: !SystemStatService.diskPercents || Object.keys(SystemStatService.diskPercents).length === 0

        RText {
          text: "No disks"
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
        }
      }
    }
  }
}
