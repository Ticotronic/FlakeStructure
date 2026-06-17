import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: powerButton
    implicitWidth: 32
    implicitHeight: 28
    radius: 4
    color: "#f38ba8"  // Catppuccin Rot

    Text {
        anchors.centerIn: parent
        text: "󰐥"
        font.family: "Symbols Nerd Font"
        font.pixelSize: 16
        color: "#1e1e2e"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: PowerMenu.show()
    }
}