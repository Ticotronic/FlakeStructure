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
    exclusiveZone: -1

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
        to: 0.85
        duration: 250
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
            tintFadeIn.start();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: PowerMenu.hide()
        }

        RowLayout {
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