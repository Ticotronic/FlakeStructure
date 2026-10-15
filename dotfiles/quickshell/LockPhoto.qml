import QtQuick
import QtQuick.Effects

// Bild mit abgerundeten Ecken fuer den Sperrbildschirm (Immich-Erinnerungen).
// Ohne Bild (noch am Laden oder fehlgeschlagen) wird ein Platzhalter gezeigt.
Item {
    id: root

    property url source: ""
    property int fillMode: Image.PreserveAspectCrop
    property real radius: 12
    property real u: 1
    property bool failed: false
    property color backdrop: Qt.rgba(1, 1, 1, 0.08)   // Hintergrund / Balken bei PreserveAspectFit
    property bool outline: true

    readonly property bool ready: img.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.backdrop
    }

    Image {
        id: img
        anchors.fill: parent
        visible: false          // nur Quelle fuer die Maske
        asynchronous: true
        source: root.source
        fillMode: root.fillMode
        smooth: true
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: mask
        autoPaddingEnabled: false
        opacity: root.ready ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }

    // Platzhalter
    Text {
        anchors.centerIn: parent
        visible: !root.ready && !root.failed
        text: String.fromCodePoint(0xF02E9)
        font.family: "Symbols Nerd Font"
        font.pixelSize: 34 * root.u
        color: Qt.rgba(1, 1, 1, 0.35)
    }
    Text {
        anchors.centerIn: parent
        visible: !root.ready && root.failed
        text: "Bild nicht ladbar"
        font.pixelSize: 15 * root.u
        color: Qt.rgba(1, 1, 1, 0.35)
    }

    Rectangle {
        anchors.fill: parent
        visible: root.outline
        radius: root.radius
        color: "transparent"
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, 0.35)
    }
}
