import QtQuick
import QtQuick.Layouts
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
    // Dieser Namespace wird in dotfiles/niri/cfg/rules.kdl (layer-rule) angesprochen
    WlrLayershell.namespace: "qs-power-overlay"
    exclusiveZone: -1

    // ==========================================
    // Hintergrund-Blur durch den Compositor (niri >= 26.04)
    // ==========================================
    // Kein Screenshot, keine Capture-Puffer: Niri verwischt live alles, was
    // hinter diesem Fenster liegt (ext-background-effect-v1). Staerke und
    // Qualitaet kommen aus dem blur-Block in der niri-Konfiguration.
    // Voraussetzung: das Fenster ist teiltransparent (siehe tintBg).
    BackgroundEffect.blurRegion: Region { item: overlay.contentItem }

    // Toenung, deren Deckkraft ein-/ausgeblendet wird. Der Blur selbst steht
    // sofort, solange das Fenster sichtbar ist (er laesst sich nicht animieren).
    Rectangle {
        id: tintBg
        anchors.fill: parent
        color: "#1e1e2e"
        opacity: 0.0
    }

    NumberAnimation {
        id: tintFadeIn
        target: tintBg
        property: "opacity"
        to: 0.4
        duration: 4500
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: tintFadeOut
        target: tintBg
        property: "opacity"
        to: 0.0
        duration: 200
        easing.type: Easing.InCubic
    }

    Timer {
        id: closeTimer
        interval: tintFadeOut.duration
        running: false
        repeat: false
        onTriggered: PowerMenu.hideImmediately()
    }

    Connections {
        target: PowerMenu
        function onCloseRequested() {
            tintFadeOut.start();
            closeTimer.restart();
        }
    }

    onVisibleChanged: {
        if (visible) {
            tintBg.opacity = 0.0;
            tintFadeIn.start();
        }
    }

    // Inhalt (Buttons) ueber der Toenung
    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: PowerMenu.hide()
        }

        RowLayout {
            // Die Rechnung dahinter: Bei 4 Buttons mit insgesamt 80% Bildschirmbreite und 4% Spacing zwischen ihnen:
            // verfügbare_breite = overlay.width * 0.8
            // spacing_gesamt    = spacing * 3  (3 Lücken zwischen 4 Buttons)
            // optionSize        = (verfügbare_breite - spacing_gesamt) / 4
            anchors.centerIn: parent
            spacing: overlay.width * 0.04

            property real optionSize: (overlay.width * 0.8 - spacing * 3) / 4

            PowerOption {
                icon: "󰐥"
                label: "Ausschalten"
                size: parent.optionSize
                onClicked: PowerMenu.shutdown()
            }
            PowerOption {
                icon: "󰜉"
                label: "Neustarten"
                size: parent.optionSize
                onClicked: PowerMenu.reboot()
            }
            PowerOption {
                icon: "󰌾"
                label: "Sperren"
                size: parent.optionSize
                onClicked: PowerMenu.lock()
            }
            PowerOption {
                icon: "󰒲"
                label: "Suspend"
                size: parent.optionSize
                onClicked: PowerMenu.suspend()
            }
        }
    }
}