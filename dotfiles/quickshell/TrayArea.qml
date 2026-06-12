import QtQuick
import Quickshell.Services.SystemTray

Row {
    spacing: 4
    property var barWindow: null

    Repeater {
        model: SystemTray.items

        TrayItem {
            required property var modelData
            trayData: modelData
            barWindow: parent.barWindow
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}