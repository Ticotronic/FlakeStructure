pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: powerMenu

    property bool visible: false
    property bool isClosing: false

    // Ablauf beim Oeffnen: show() loest in jedem PowerOverlay (ein Fenster pro
    // Monitor) einen Screenshot per grim aus (captureRequested). Erst wenn alle
    // fertig sind (captureFinished) oder nach dem Timeout, werden die Overlays
    // sichtbar. So gibt es keine ScreencopyView mehr.
    property bool capturing: false
    property int pendingCaptures: 0

    signal closeRequested()
    signal captureRequested()

    function show() {
        if (capturing || visible) return;
        isClosing = false;
        pendingCaptures = Quickshell.screens.length;
        capturing = true;
        captureTimeout.restart();
        captureRequested();
    }

    // Wird von jedem Overlay aufgerufen, sobald sein Screenshot fertig ist
    // (auch wenn grim fehlgeschlagen ist: dann gibt es nur die Toenung).
    function captureFinished() {
        if (!capturing) return;
        pendingCaptures--;
        if (pendingCaptures <= 0) finishCapture();
    }

    function finishCapture() {
        captureTimeout.stop();
        capturing = false;
        visible = true;
    }

    // Sicherheitsnetz, falls ein Screenshot haengt
    Timer {
        id: captureTimeout
        interval: 2500
        repeat: false
        onTriggered: powerMenu.finishCapture()
    }

    function hide() {
        isClosing = true;
        closeRequested();
        // Tatsächliches Verstecken erfolgt nach der Ausblend-Animation
        // via hideImmediately(), aufgerufen vom Overlay-Timer
    }

    function hideImmediately() {
        visible = false;
        isClosing = false;
    }

    // ==========================================
    // Aktionen — hier später den Lockscreen ersetzen
    // ==========================================
    function shutdown() {
        hide();
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    function reboot() {
        hide();
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function suspend() {
        hide();
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function lock() {
        hide();
        // TODO: durch eigenen Quickshell-Lockscreen ersetzen
        // Platzhalter aktuell: swaylock
        Quickshell.execDetached(["swaylock"]);
    }
}