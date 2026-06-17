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

    // Dunkler, halbtransparenter Hintergrund mit Blur-Optik
    Rectangle {
        anchors.fill: parent
        color: "#1e1e2ecc"

        MouseArea {
            // Klick außerhalb der Buttons schließt das Menü
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