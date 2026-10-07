import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 16

    // Wird von Bar.qml gesetzt (Ankerfenster fuer das WLAN-Menue)
    property var barWindow: null

    // Klick auf den WLAN-Namen oeffnet WlanMenu.qml
    Text {
        id: wlanLabel
        color: wlanMouse.containsMouse ? "#89b4fa" : "#cdd6f4"
        font.pixelSize: 14
        font.family: "Symbols Nerd Font"
        text: wlanStatus

        MouseArea {
            id: wlanMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wlanMenu.toggle()
        }
    }

    WlanMenu {
        id: wlanMenu
        barWindow: root.barWindow
        anchorItem: wlanLabel
    }

    // Bluetooth: Icon + Name des verbundenen Geraets; Klick oeffnet
    // BluetoothMenu.qml
    Text {
        id: btLabel
        color: btMouse.containsMouse ? "#89b4fa" : (btMenu.powered ? "#cdd6f4" : "#6c7086")
        font.pixelSize: 14
        font.family: "Symbols Nerd Font"
        text: btMenu.labelText

        MouseArea {
            id: btMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btMenu.toggle()
        }
    }

    BluetoothMenu {
        id: btMenu
        barWindow: root.barWindow
        anchorItem: btLabel
    }

    // Fallback 100%, damit die Anzeige beim Start (bevor der erste
    // Messwert eintrifft) nicht fälschlich rot blinkt.
    BatteryIndicator {
        percent: isNaN(parseInt(batStatus)) ? 100 : parseInt(batStatus)
        charging: batCharging
    }
    RamIndicator { ramText: ramStatus }

    // CPU-Last: Icon + Prozentzahl. Die Zahl steht rechtsbuendig in einem Feld
    // fester Breite (Breite von "100%"), damit die Leiste nicht springt, wenn
    // die Last z.B. von "5%" auf "12%" wechselt.
    Row {
        spacing: 4

        Text {
            color: "#cdd6f4"
            font.pixelSize: 14
            font.family: "Symbols Nerd Font"
            text: "󰘚"
        }

        Text {
            width: cpuMetrics.width
            horizontalAlignment: Text.AlignRight
            color: "#cdd6f4"
            font.pixelSize: 14
            font.family: "Symbols Nerd Font"
            text: cpuStatus

            TextMetrics {
                id: cpuMetrics
                font.pixelSize: 14
                font.family: "Symbols Nerd Font"
                text: "100%"
            }
        }
    }
}