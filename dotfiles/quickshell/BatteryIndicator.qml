import QtQuick
import Quickshell

// Visualisiert den Akkustand als kleines Batterie-Symbol mit Füllbalken.
// - Füllfarbe hängt vom Prozentwert ab (grün / gelb / rot)
// - Unter 20% wird die Anzeige rot
// - Unter 10% blinkt die Anzeige zusätzlich
// - Beim Laden erscheint ein kleines Blitz-Symbol im Batteriekörper
Item {
    id: root

    property int percent: 100
    property bool charging: false

    // Optional (Bar): "<Zustand>;<Minuten>" aus qs-stats.sh und das Bar-Fenster fuer
    // den Tooltip. Ohne info (z.B. auf dem Sperrbildschirm) gibt es keinen Tooltip.
    property string info: ""
    property var barWindow: null

    // "3 h 12 min" bzw. "23 min"
    function formatMinutes(m) {
        var h = Math.floor(m / 60);
        var r = m % 60;
        return h > 0 ? h + " h " + r + " min" : r + " min";
    }

    readonly property string tooltipText: {
        var p = info.split(";");
        var mins = p.length > 1 ? parseInt(p[1]) : NaN;
        switch (p[0]) {
        case "discharging":
            return isNaN(mins) ? "Restlaufzeit wird berechnet …"
                               : "Noch " + formatMinutes(mins) + " Akkulaufzeit";
        case "charging":
            return isNaN(mins) ? "Lädt …" : "Noch " + formatMinutes(mins) + " bis voll";
        case "full":
            return "Vollgeladen";
        case "plugged":
            return "Netzteil angeschlossen, Akku lädt nicht";
        default:
            return "";
        }
    }

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

                // Blitz-Symbol, solange der Akku lädt (liegt über dem Füllbalken)
                // Unicode-Escape statt Literalzeichen, damit das PUA-Glyph
                // (nf-fa-bolt) beim Kopieren/Speichern nicht verloren geht.
                Text {
                    visible: root.charging
                    anchors.centerIn: parent
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 10
                    // Helles Symbol mit dunkler Kontur: bleibt sowohl auf dem
                    // farbigen Fuellbalken als auch auf dem leeren, dunklen
                    // Teil der Batterie (Stand < 50%) sichtbar.
                    color: "#cdd6f4"
                    style: Text.Outline
                    styleColor: "#1e1e2e"
                    text: ""
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

    // ---- Tooltip (Restlaufzeit / Zeit bis voll / Vollgeladen) ----
    // Position beim Hovern berechnen (ein Binding auf mapToItem() wird bei
    // spaeteren Layout-Aenderungen nicht neu ausgewertet)
    property real tipX: 0
    property bool tipShown: false

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.tooltipText !== "" && root.barWindow !== null
        onEntered: {
            root.tipX = root.mapToItem(null, 0, 0).x;
            root.tipShown = true;
        }
        onExited: root.tipShown = false
    }

    PopupWindow {
        visible: root.tipShown && root.tooltipText !== ""

        anchor.window: root.barWindow
        anchor.rect: Qt.rect(
            root.tipX,
            root.barWindow ? root.barWindow.height : 0,
            root.width,
            0
        )
        // rechtsbuendig unter dem Symbol, damit der Tooltip am rechten Rand nicht abgeschnitten wird
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left

        implicitWidth: tipText.implicitWidth + 16
        implicitHeight: tipText.implicitHeight + 12
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#313244"
            radius: 4
            border.color: "#45475a"
            border.width: 1

            Text {
                id: tipText
                anchors.centerIn: parent
                color: "#cdd6f4"
                font.pixelSize: 12
                text: root.tooltipText
            }
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
