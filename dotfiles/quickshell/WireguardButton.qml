import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: vpnButton
    width: 32
    height: 28
    radius: 4

    // Hier den WireGuard-Interface-Namen anpassen
    property string vpnName: "wg0"

    property bool connected: false
    property bool loading: false

    color: loading   ? "#f9e2af"  // gelb = verbindet/trennt
         : connected ? "#a6e3a1"  // grün = verbunden
                     : "#313244"  // grau = getrennt

    border.color: connected ? "transparent" : "#45475a"
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: "󰖂"
        font.family: "Symbols Nerd Font"
        font.pixelSize: 16
        color: loading   ? "#1e1e2e"
             : connected ? "#1e1e2e"
                         : "#cdd6f4"
    }

    // ==========================================
    // Status periodisch abfragen
    // ==========================================
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProc.running = true
    }

    Process {
        id: statusProc
        command: ["systemctl", "is-active", "wg-quick-wg0"]
        running: false
        onExited: code => {
            connected = (code === 0);
            loading = false;
        }
    }

    // ==========================================
    // Verbindung aufbauen
    // ==========================================
    Process {
        id: connectProc
        command: ["sudo", "systemctl", "start", "wg-quick-wg0"]
        running: false
        onExited: code => {
            if (code === 0) connected = true;
            loading = false;
        }
    }

    // ==========================================
    // Verbindung trennen
    // ==========================================
    Process {
        id: disconnectProc
        command: ["sudo", "systemctl", "stop", "wg-quick-wg0"]
        running: false
        onExited: code => {
            if (code === 0) connected = false;
            loading = false;
        }
    }

    PopupWindow {
        id: vpnTooltip
        visible: vpnMouseArea.containsMouse

        anchor.window: vpnButton.parent
        anchor.rect: Qt.rect(
            vpnButton.mapToItem(null, 0, 0).x,
            32,
            vpnButton.width,
            0
        )

        implicitWidth: vpnTooltipText.implicitWidth + 16
        implicitHeight: vpnTooltipText.implicitHeight + 12
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#313244"
            radius: 4
            border.color: "#45475a"
            border.width: 1

            Text {
                id: vpnTooltipText
                anchors.centerIn: parent
                color: "#cdd6f4"
                font.pixelSize: 12
                text: loading   ? "Verbinde..."
                     : connected ? "VPN aktiv — klicken zum Trennen"
                                 : "VPN getrennt — klicken zum Verbinden"
            }
        }
    }

    MouseArea {
        id: vpnMouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onClicked: {
            if (loading) return;
            loading = true;
            if (connected) {
                disconnectProc.running = true;
            } else {
                connectProc.running = true;
            }
        }
    }
}