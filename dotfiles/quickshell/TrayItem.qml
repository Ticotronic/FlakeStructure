import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: trayItem
    width: 24
    height: 24

    required property var trayData
    property var barWindow: null

    IconImage {
        anchors.fill: parent
        source: trayItem.trayData.icon
    }

    MouseArea {
        id: trayMouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton || trayItem.trayData.onlyMenu) {
                trayMenuAnchor.open()
            } else {
                trayItem.trayData.activate()
            }
        }
    }

    ToolTip {
        visible: trayMouseArea.containsMouse
        text: trayItem.trayData.tooltipTitle !== ""
            ? trayItem.trayData.tooltipTitle
            : trayItem.trayData.title
        delay: 500
    }

    QsMenuAnchor {
        id: trayMenuAnchor
        menu: trayItem.trayData.menu
        anchor.window: barWindow
        anchor.rect: Qt.rect(
            trayItem.mapToItem(null, 0, 0).x,
            barWindow ? barWindow.height : 0,
            trayItem.width,
            0
        )
    }
}