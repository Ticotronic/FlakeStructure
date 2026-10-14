import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// Eigener Sperrbildschirm auf Basis von ext-session-lock-v1 (WlSessionLock).
//
// Ablauf:
//   1. LockState.lock() -> startLock() hier
//   2. per grim ein Screenshot jedes Monitors (der Hintergrund wird verwischt)
//   3. WlSessionLock.locked = true -> Niri zeigt nur noch unsere Oberflaechen
//   4. Passwort -> PAM (Dienst "quickshell-lock", siehe modules/common.nix)
//   5. Erfolg -> locked = false, Screenshots werden geloescht
//
// NOTAUSSTIEG: Stuerzt Quickshell im gesperrten Zustand ab, bleibt der
// Bildschirm gesperrt (so soll es sein). Dann auf eine Konsole wechseln
// (Strg+Alt+F3), anmelden und dort einen neuen Sperrclient starten, der sich
// mit dem Passwort wieder entsperren laesst:
//   WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/$(id -u) swaylock
Scope {
    id: root

    // ---- Zustand, den alle Oberflaechen (pro Monitor) gemeinsam nutzen ----
    readonly property string captureDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string pamService: "quickshell-lock"

    property string currentText: ""     // eingegebenes Passwort
    property bool busy: false           // PAM prueft gerade
    property bool showFailure: false
    property string failureText: ""
    property int failCount: 0
    property bool preparing: false      // Screenshots laufen noch

    // Tippen blendet die Fehlermeldung wieder aus. (Beim Fehlschlag wird erst
    // der Text geleert und danach showFailure gesetzt, die Reihenfolge zaehlt.)
    onCurrentTextChanged: showFailure = false

    // ---- Sperren starten ----
    function startLock() {
        if (sessionLock.locked || preparing)
            return;
        preparing = true;
        currentText = "";
        showFailure = false;
        busy = false;

        var names = [];
        for (var i = 0; i < Quickshell.screens.length; i++)
            names.push(Quickshell.screens[i].name);

        // PPM: unkomprimiert, dadurch am schnellsten geschrieben. Alle Monitore
        // parallel. Schlaegt grim fehl, wird trotzdem gesperrt (nur ohne Bild).
        grimProc.command = ["sh", "-c",
            'dir="${XDG_RUNTIME_DIR:-/tmp}"; ' +
            'for o in "$@"; do grim -t ppm -o "$o" "$dir/qs-lock-$o.ppm" & done; wait',
            "sh"].concat(names);
        grimProc.running = true;
        failsafe.restart();
    }

    function engage() {
        if (!preparing)
            return;
        preparing = false;
        failsafe.stop();
        sessionLock.locked = true;
    }

    function tryUnlock() {
        if (currentText === "" || busy)
            return;
        busy = true;
        if (!pam.start()) {
            busy = false;
            failureText = "Anmeldung nicht möglich (PAM)";
            showFailure = true;
            failCount++;
        }
    }

    function finishUnlock() {
        sessionLock.locked = false;
        currentText = "";
        busy = false;
        showFailure = false;
        // Screenshots wieder entfernen
        Quickshell.execDetached(["sh", "-c", 'rm -f "${XDG_RUNTIME_DIR:-/tmp}"/qs-lock-*.ppm']);
    }

    Process {
        id: grimProc
        onExited: root.engage()
    }

    // Sicherheitsnetz: haengt grim, wird nach 3 s trotzdem gesperrt.
    Timer {
        id: failsafe
        interval: 3000
        repeat: false
        onTriggered: root.engage()
    }

    PamContext {
        id: pam
        config: root.pamService

        // pam_unix fragt genau einmal nach dem Passwort
        onPamMessage: {
            if (responseRequired)
                respond(root.currentText);
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.finishUnlock();
                return;
            }
            root.currentText = "";
            if (result === PamResult.MaxTries)
                root.failureText = "Zu viele Versuche";
            else if (result === PamResult.Error)
                root.failureText = "Fehler bei der Anmeldung";
            else
                root.failureText = "Falsches Passwort";
            root.showFailure = true;
            root.failCount++;
            root.busy = false;
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: surf
            // Deckend: die meisten Compositoren ignorieren transparente Lock-Flaechen
            color: "#1e1e2e"

            LockSurface {
                anchors.fill: parent
                ctx: root
                screenName: surf.screen ? surf.screen.name : ""
            }
        }
    }

    Connections {
        target: LockState
        function onLockRequested() { root.startLock(); }
    }

    // qs ipc call lockscreen activate   (Tastenkuerzel in niri/cfg/keybinds.kdl)
    IpcHandler {
        target: "lockscreen"
        function activate(): void { root.startLock(); }
    }

    Component.onCompleted: LockState.available = true
    Component.onDestruction: LockState.available = false
}
