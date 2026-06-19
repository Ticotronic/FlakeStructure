import QtQuick
import Quickshell

Rectangle {
    id: launcherButton
    implicitWidth: 32
    implicitHeight: 28
    color: "#89b4fa"
    radius: 4

    property var barScreen: null

    Text {
        text: "󱓞"
        font.family: "Symbols Nerd Font"
        anchors.centerIn: parent
        color: "#1e1e2e"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: LauncherMenu.show(launcherButton.barScreen)
    }
}