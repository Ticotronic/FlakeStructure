import QtQuick

// Visualisiert den Akkustand als kleines Batterie-Symbol mit Füllbalken.
// - Füllfarbe hängt vom Prozentwert ab (grün / gelb / rot)
// - Unter 20% wird die Anzeige rot
// - Unter 10% blinkt die Anzeige zusätzlich
Item {
    id: root

    property int percent: 100

    readonly property int clampedPercent: Math.min(100, Math.max(0, percent))

    readonly property color colorGood: "#a6e3a1"
    readonly property color colorMedium: "#f9e2af"
    readonly property color colorLow: "#f38ba8"

    readonly property color fillColor: clampedPercent < 20 ? colorLow
        : clampedPercent < 50 ? colorMedium
        : colorGood

    readonly property bool isCritical: clampedPercent < 10

    implicitWidth: row.implicitWidth
    implicitHeight: 16

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        // Batteriekörper (Umriss + Nippel + Füllbalken)
        Item {
            id: shape
            width: 24
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: outline
                x: 0
                y: 3
                width: 20
                height: 10
                radius: 2
                color: "transparent"
                border.width: 1
                border.color: "#6c7086"

                Rectangle {
                    x: 1.5
                    y: 1.5
                    width: Math.max(0, (outline.width - 3) * root.clampedPercent / 100)
                    height: outline.height - 3
                    radius: 1
                    color: root.fillColor

                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }

            Rectangle {
                x: outline.x + outline.width
                y: outline.y + (outline.height - 5) / 2
                width: 2
                height: 5
                radius: 1
                color: "#6c7086"
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.fillColor
            font.pixelSize: 13
            font.family: "Symbols Nerd Font"
            text: root.clampedPercent + "%"

            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    // Blinken, sobald der Akkustand kritisch (<10%) ist
    SequentialAnimation {
        running: root.isCritical
        loops: Animation.Infinite
        alwaysRunToEnd: false

        onRunningChanged: if (!running) root.opacity = 1.0

        NumberAnimation { target: root; property: "opacity"; from: 1.0; to: 0.25; duration: 500; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "opacity"; from: 0.25; to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
    }
}
