import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell

Rectangle {
    id: customItem
    property string itemName: ""
    property string itemDescription: ""
    property string itemIcon: ""
    property var itemCommand: []

    implicitHeight: 40
    radius: 6
    color: customMouseArea.containsMouse ? "#313244" : "transparent"
    border.color: customMouseArea.containsMouse ? "#45475a" : "transparent"
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 10

        Rectangle {
            width: 28; height: 28
            radius: 6
            color: "#1e1e2e"

            IconImage {
                source: "image://icon/" + customItem.itemIcon
                width: 18; height: 18
                anchors.centerIn: parent
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: customItem.itemName
                color: "#cdd6f4"
                font.pixelSize: 12
            }

            Text {
                text: customItem.itemDescription
                color: "#6c7086"
                font.pixelSize: 10
            }
        }

        Text {
            text: "→"
            color: "#45475a"
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: customMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            LauncherMenu.hide();
            Quickshell.execDetached(customItem.itemCommand);
        }
    }
}