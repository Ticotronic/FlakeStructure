import QtQuick

// Statuszeile am unteren Rand des Sperrbildschirms: WLAN, Bluetooth, Akku.
// Die Daten kommen aus LockScreen.qml (ctx), damit nicht jeder Monitor eigene
// Abfragen startet.
Rectangle {
    id: root

    required property var ctx
    property real u: 1.0

    implicitWidth: row.implicitWidth + 64 * u
    implicitHeight: 54 * u
    radius: height / 2
    color: Qt.rgba(1, 1, 1, 0.10)
    border.width: 1.5
    border.color: Qt.rgba(1, 1, 1, 0.35)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 34 * root.u

        // WLAN: Icon + Netzname (fertig formatiert von qs-stats)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.ctx.wlanText !== ""
            text: root.ctx.wlanText
            color: "#cdd6f4"
            font.family: "Symbols Nerd Font"
            font.pixelSize: 22 * root.u
        }

        // Bluetooth: Icon + Name des verbundenen Geraets
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.ctx.btText
            color: root.ctx.btPowered ? "#cdd6f4" : "#6c7086"
            font.family: "Symbols Nerd Font"
            font.pixelSize: 22 * root.u
        }

        // Akku (dasselbe Symbol wie in der Leiste, nur groesser)
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: battery.implicitWidth * battery.scale
            height: battery.implicitHeight * battery.scale

            BatteryIndicator {
                id: battery
                scale: 1.45 * root.u
                transformOrigin: Item.TopLeft
                percent: root.ctx.batPercent
                charging: root.ctx.batCharging
            }
        }
    }
}
