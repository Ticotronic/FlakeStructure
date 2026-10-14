pragma Singleton
import QtQuick
import Quickshell

// Einstiegspunkt zum Sperren des Bildschirms (Power-Menue, Tastenkuerzel).
// Der eigentliche Sperrbildschirm steckt in LockScreen.qml.
Singleton {
    id: lockState

    // Wird von LockScreen.qml gesetzt, sobald es geladen ist. Falls es nicht
    // geladen werden konnte (z.B. weil das PAM-Modul in diesem Quickshell-Build
    // fehlt), faellt lock() auf swaylock zurueck, statt wirkungslos zu bleiben.
    property bool available: false

    signal lockRequested()

    function lock() {
        if (available)
            lockRequested();
        else
            Quickshell.execDetached(["swaylock"]);
    }
}
