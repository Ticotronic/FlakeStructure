import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
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
    // Screenshot des Bildschirms (per grim, vor dem Einblenden des Overlays)
    // ==========================================
    // Bewusst kein ScreencopyView: dessen Capture-Puffer haben bei zwei
    // Monitoren zu einem Absturz in Qt gefuehrt (Quickshell 0.3.0).
    readonly property string capturePath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-power-" + overlay.screen.name + ".ppm"

    Image {
        id: screenCapture
        anchors.fill: parent
        visible: false          // wird nur als Quelle fuer den Blur genutzt
        cache: false
        asynchronous: false
        fillMode: Image.Stretch
    }

    Process {
        id: grimProc
        onExited: code => {
            if (code === 0) {
                // Die Datei bleibt liegen, bis das Overlay wieder verschwindet
                // (siehe onVisibleChanged). Sie sofort zu loeschen war ein Fehler:
                // der Image-Loader hat sie dann beim grossen 4K-Bild teils
                // noch nicht fertig gelesen ("Cannot open: ...").
                screenCapture.source = "file://" + overlay.capturePath;
            }
            PowerMenu.captureFinished();
        }
    }

    Process { id: cleanupProc }

    Connections {
        target: PowerMenu
        function onCaptureRequested() {
            screenCapture.source = "";
            // PPM: unkomprimiert, dadurch am schnellsten zu schreiben
            grimProc.command = ["grim", "-t", "ppm", "-o", overlay.screen.name, overlay.capturePath];
            grimProc.running = true;
        }
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
        duration: 4500
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

    Timer {
        id: closeTimer
        interval: blurAnimOut.duration
        running: false
        repeat: false
        onTriggered: PowerMenu.hideImmediately()
    }

    Connections {
        target: PowerMenu
        function onCloseRequested() {
            blurAnimOut.start();
            closeTimer.restart();
        }
    }

    onVisibleChanged: {
        if (visible) {
            blurEffect.blur = 0.0;
            blurAnim.start();
        } else {
            // Overlay ist weg: Screenshot-Datei und Bild im Speicher freigeben
            screenCapture.source = "";
            cleanupProc.command = ["rm", "-f", overlay.capturePath];
            cleanupProc.running = true;
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