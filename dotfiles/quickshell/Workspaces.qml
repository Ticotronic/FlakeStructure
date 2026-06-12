import QtQuick
import Quickshell

Row {
    spacing: 6
    property var workspaces: []

    Repeater {
        model: workspaces
        Rectangle {
            width: 28; height: 28
            anchors.verticalCenter: parent.verticalCenter
            color: modelData.is_focused ? "#a6e3a1" : (modelData.is_active ? "#313244" : "#181825")
            border.color: modelData.is_focused ? "transparent" : "#45475a"
            border.width: 1
            radius: 4
            Text {
                text: modelData.idx
                color: modelData.is_focused ? "#11111b" : "#cdd6f4"
                font.bold: modelData.is_focused
                anchors.centerIn: parent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached([
                        "niri", "msg", "action", "focus-workspace",
                        String(modelData.idx)
                    ])
                }
            }
        }
    }
}