import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: overlay
    required property var modelData
    screen: modelData

    visible: PowerMenu.visible
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: -1

    // ==========================================
    // Live-Screenshot des Bildschirms hinter dem Overlay
    // ==========================================
    ScreencopyView {
        id: screenCapture
        anchors.fill: parent
        captureSource: modelData
        live: false  // einmaliges Standbild reicht, kein Live-Feed nötig
    }

    // ==========================================
    // Blur-Effekt auf den Screenshot anwenden
    // ==========================================
    MultiEffect {
        id: blurEffect
        anchors.fill: parent
        source: screenCapture
        blurEnabled: true
        blur: 0.0           // wird animiert
        blurMax: 64
        autoPaddingEnabled: false
    }

    // Animiert blurEffect.blur hoch wenn das Overlay erscheint
    NumberAnimation {
        id: blurAnim
        target: blurEffect
        property: "blur"
        to: 1.0
        duration: 250
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: blurAnimOut
        target: blurEffect
        property: "blur"
        to: 0.0
        duration: 200
        easing.type: Easing.InCubic
    }

    onVisibleChanged: {
        if (visible) {
            blurEffect.blur = 0.0;
            blurAnim.start();
        }
    }

    // Dunkles Tint zusätzlich zum Blur für Glass-Optik
    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e55"

        MouseArea {
            anchors.fill: parent
            onClicked: PowerMenu.hide()
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 24

            PowerOption {
                icon: "󰐥"
                label: "Ausschalten"
                onClicked: PowerMenu.shutdown()
            }
            PowerOption {
                icon: "󰜉"
                label: "Neustarten"
                onClicked: PowerMenu.reboot()
            }
            PowerOption {
                icon: "󰌾"
                label: "Sperren"
                onClicked: PowerMenu.lock()
            }
            PowerOption {
                icon: "󰒲"
                label: "Suspend"
                onClicked: PowerMenu.suspend()
            }
        }
    }
}