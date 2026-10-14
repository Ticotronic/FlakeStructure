import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Automatische Ausloeser fuer den Sperrbildschirm:
//   - Inaktivitaet (ext-idle-notify; Videoplayer/Browser mit Idle-Inhibit
//     verhindern das Sperren, solange sie aktiv sind)
//   - vor dem Suspend (logind PrepareForSleep + Delay-Inhibitor, damit der
//     Rechner erst schlafen geht, wenn der Bildschirm wirklich gesperrt ist)
// Der Deckel wird ueber Niri behandelt (cfg/switch-events.kdl), weil logind im
// Dock-Betrieb (externer Monitor) den Deckel ignoriert.
Scope {
    id: root

    // ---- Einstellungen ----
    // Nach so vielen Sekunden ohne Eingabe sperren (0 = nie)
    readonly property real idleLockSeconds: 300
    // So viele Sekunden NACH dem Sperren die Monitore ausschalten (0 = nie).
    // Beim naechsten Tastendruck / bei Mausbewegung gehen sie von selbst wieder an.
    readonly property real screenOffAfterLockSeconds: 60

    // ---------------------------------------------------------------
    // Inaktivitaet
    // ---------------------------------------------------------------
    IdleMonitor {
        enabled: root.idleLockSeconds > 0
        timeout: root.idleLockSeconds
        onIsIdleChanged: {
            if (isIdle)
                LockState.lock();
        }
    }

    IdleMonitor {
        enabled: root.idleLockSeconds > 0 && root.screenOffAfterLockSeconds > 0
        timeout: root.idleLockSeconds + root.screenOffAfterLockSeconds
        onIsIdleChanged: {
            // Nur ausschalten, wenn wirklich gesperrt ist
            if (isIdle && LockState.locked)
                Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"]);
        }
    }

    // ---------------------------------------------------------------
    // Vor dem Suspend
    // ---------------------------------------------------------------
    property bool waitingForLock: false

    // Haelt den Suspend an ("delay"-Inhibitor), bis wir ihn freigeben. Der
    // Hilfsprozess endet von selbst, sobald systemd-inhibit beendet wird, damit
    // nichts liegen bleibt.
    Process {
        id: inhibitor
        running: true
        command: [
            "systemd-inhibit", "--what=sleep", "--mode=delay",
            "--who=Quickshell Sperrbildschirm",
            "--why=Bildschirm vor dem Suspend sperren",
            "sh", "-c", "while kill -0 $PPID 2>/dev/null; do sleep 1; done"
        ]
    }

    // Lauscht auf logind: "boolean true" = Rechner geht gleich schlafen,
    // "boolean false" = Rechner ist wieder aufgewacht.
    Process {
        id: sleepWatcher
        running: true
        command: [
            "dbus-monitor", "--system",
            "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"
        ]
        stdout: SplitParser {
            onRead: line => {
                var l = line.trim();
                if (l === "boolean true")
                    root.sleepStarting();
                else if (l === "boolean false")
                    root.resumed();
            }
        }
    }

    function sleepStarting() {
        if (LockState.locked && LockState.secure) {
            releaseInhibitor();
            return;
        }
        waitingForLock = true;
        releaseFailsafe.restart();
        LockState.lock();
    }

    function resumed() {
        waitingForLock = false;
        releaseFailsafe.stop();
        // Fuer den naechsten Suspend wieder eine Sperre halten
        if (!inhibitor.running)
            inhibitor.running = true;
    }

    function releaseInhibitor() {
        waitingForLock = false;
        releaseFailsafe.stop();
        inhibitor.running = false;
    }

    // Sobald der Compositor den Bildschirm als gesperrt bestaetigt, darf der
    // Rechner schlafen gehen.
    Connections {
        target: LockState
        function onSecureChanged() {
            if (root.waitingForLock && LockState.secure)
                root.releaseInhibitor();
        }
    }

    // Sicherheitsnetz: nie laenger als 2,5 s blockieren (logind erzwingt den
    // Suspend ohnehin nach 5 s). Greift auch, wenn der Sperrbildschirm nicht
    // geladen ist und nur swaylock als Rueckfall startet.
    Timer {
        id: releaseFailsafe
        interval: 2500
        repeat: false
        onTriggered: root.releaseInhibitor()
    }
}
