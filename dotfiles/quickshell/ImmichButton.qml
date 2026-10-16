import QtQuick
import Quickshell

// Bar-Button: oeffnet Immich als eigenes App-Fenster (Brave --app), ist es schon
// offen, wird es nur nach vorne geholt. Die Logik steckt im Skript "immich-open"
// (modules/home.nix), die Adresse steht dort an einer Stelle. Immich ist nur im
// Heimnetz oder ueber das VPN erreichbar - sonst zeigt das Fenster einen Fehler.
Rectangle {
    id: immichButton
    width: 32
    height: 28
    radius: 4

    property var barWindow: null

    color: mouse.pressed ? "#45475a" : (mouse.containsMouse ? "#3b3d52" : "#313244")
    border.color: "#45475a"
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: String.fromCodePoint(0xF0100)   // Kamera (Nerd Font, Material Design)
        font.family: "Symbols Nerd Font"
        font.pixelSize: 16
        color: "#cdd6f4"
    }

    PopupWindow {
        visible: mouse.containsMouse && immichButton.barWindow !== null

        anchor.window: immichButton.barWindow
        anchor.rect: Qt.rect(
            immichButton.mapToItem(null, 0, 0).x,
            immichButton.barWindow ? immichButton.barWindow.height : 0,
            immichButton.width,
            0
        )

        implicitWidth: tipText.implicitWidth + 16
        implicitHeight: tipText.implicitHeight + 12
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#313244"
            radius: 4
            border.color: "#45475a"
            border.width: 1

            Text {
                id: tipText
                anchors.centerIn: parent
                color: "#cdd6f4"
                font.pixelSize: 12
                text: "Immich öffnen"
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: Quickshell.execDetached(["immich-open"])
    }
}
