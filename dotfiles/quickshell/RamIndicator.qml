import QtQuick

// Visualisiert die RAM-Auslastung als Balken + "belegt/gesamtGB".
// Farbe je nach Auslastung: gruen (wenig), gelb (moderat), rot (hoch).
Item {
    id: root

    // Erwartet "belegtGB/gesamtGB", z.B. "12.3/31.9"
    property string ramText: "0.0/0.0"

    readonly property var _parts: ramText.split("/")
    readonly property real usedGB: parseFloat(_parts[0]) || 0
    readonly property real totalGB: _parts.length > 1 ? (parseFloat(_parts[1]) || 0) : 0
    readonly property real usedPercent: totalGB > 0 ? Math.min(100, (usedGB / totalGB) * 100) : 0

    readonly property color colorGood: "#a6e3a1"
    readonly property color colorMedium: "#f9e2af"
    readonly property color colorHigh: "#f38ba8"

    // Schwellenwerte: <60% gruen, 60-85% gelb, >85% rot
    readonly property color fillColor: usedPercent > 85 ? colorHigh
        : usedPercent > 60 ? colorMedium
        : colorGood

    implicitWidth: row.implicitWidth
    implicitHeight: 16

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: "#cdd6f4"
            font.pixelSize: 14
            font.family: "Symbols Nerd Font"
            text: "󰍛"
        }

        // Auslastungsbalken
        Rectangle {
            id: barOutline
            width: 30
            height: 8
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.width: 1
            border.color: "#6c7086"

            Rectangle {
                x: 1.5
                y: 1.5
                width: Math.max(0, (barOutline.width - 3) * root.usedPercent / 100)
                height: barOutline.height - 3
                radius: 1
                color: root.fillColor

                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.fillColor
            font.pixelSize: 13
            font.family: "Symbols Nerd Font"
            text: root.usedGB.toFixed(1) + "/" + root.totalGB.toFixed(1) + "GB"

            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }
}
