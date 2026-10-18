import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

// Quickshell-Greeter fuer greetd (Anmeldebildschirm), im Look des Sperrbildschirms.
//
// Laeuft als Benutzer "greeter" in einem eigenen Niri (siehe modules/greeter.nix),
// NICHT in deiner normalen Quickshell-Sitzung. Konfiguration kommt ueber
// Umgebungsvariablen, die modules/greeter.nix setzt:
//   GREETER_USERS      JSON: [{"name":"roljon","display":"roljon"}]
//   GREETER_SESSIONS   JSON: [{"name":"niri","exec":["/run/current-system/sw/bin/niri-session"]}]
//   GREETER_WALLPAPER  Pfad zu einem Hintergrundbild (leer = Farbverlauf)
//
// Ablauf: Passwort eintippen -> Enter -> Greetd.createSession(user) -> greetd
// fragt per authMessage nach dem Passwort -> respond() -> readyToLaunch ->
// Greetd.launch(session). launch() beendet Quickshell; das Skript in
// modules/greeter.nix beendet danach auch Niri, und greetd startet die Sitzung.
ShellRoot {
    id: root

    // ---- Konfiguration ----
    function parseList(text, fallback) {
        try {
            var v = JSON.parse(text);
            return (v && v.length > 0) ? v : fallback;
        } catch (e) {
            return fallback;
        }
    }

    readonly property var users: parseList(Quickshell.env("GREETER_USERS"),
                                           [{ name: "", display: "" }])
    readonly property var sessions: parseList(Quickshell.env("GREETER_SESSIONS"), [])
    readonly property string wallpaper: Quickshell.env("GREETER_WALLPAPER") || ""

    // ---- gemeinsamer Zustand (alle Monitore zeigen dasselbe) ----
    property int userIndex: 0
    property int sessionIndex: 0
    property string currentText: ""     // eingegebenes Passwort
    property bool busy: false           // Anmeldung laeuft
    property bool showFailure: false
    property string failureText: ""
    property int failCount: 0
    property bool capsLock: false
    property bool batPresent: false
    property int batPercent: 100
    property bool batCharging: false

    readonly property var currentUser: users[Math.min(userIndex, users.length - 1)]
    readonly property bool greetdAvailable: Greetd.available

    onCurrentTextChanged: showFailure = false

    function nextUser() {
        if (busy || users.length < 2)
            return;
        userIndex = (userIndex + 1) % users.length;
        currentText = "";
    }

    function nextSession() {
        if (sessions.length < 2)
            return;
        sessionIndex = (sessionIndex + 1) % sessions.length;
    }

    function fail(text) {
        failureText = text;
        currentText = "";
        showFailure = true;
        failCount++;
        busy = false;
    }

    function submit() {
        if (busy || currentText === "" || currentUser.name === "")
            return;
        if (sessions.length === 0) {
            fail("Keine Sitzung konfiguriert");
            return;
        }
        busy = true;
        showFailure = false;
        Greetd.createSession(currentUser.name);
    }

    Connections {
        target: Greetd

        // greetd fragt (meist genau einmal) nach dem Passwort
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.currentText);
            } else if (error) {
                // behebbare Fehler, z.B. Fingerabdruck nicht erkannt
                root.failureText = message;
                root.showFailure = true;
            }
        }

        // Passwort falsch (oder Zeitueberschreitung); die Sitzung ist damit beendet
        function onAuthFailure(message) {
            root.fail("Falsches Passwort");
        }

        function onReadyToLaunch() {
            root.currentText = "";
            Greetd.launch(root.sessions[root.sessionIndex].exec);
        }

        function onError(error) {
            Greetd.cancelSession();
            root.fail("Fehler: " + error);
        }
    }

    // ---- Feststelltaste: LED im sysfs (wie im Sperrbildschirm) ----
    Process {
        running: true
        command: ["sh", "-c",
            'while :; do echo "led $(cat /sys/class/leds/*::capslock/brightness 2>/dev/null)"; sleep 0.3; done']
        stdout: SplitParser {
            onRead: line => root.capsLock = line.indexOf("1") >= 0
        }
    }

    // ---- Akku: alle 5 s "bat <Prozent> <Status>" ----
    Process {
        running: true
        command: ["sh", "-c",
            'while :; do echo "bat $(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n 1) ' +
            '$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n 1)"; sleep 5; done']
        stdout: SplitParser {
            onRead: line => {
                var parts = line.trim().split(/\s+/);
                var n = parseInt(parts[1]);
                root.batPresent = !isNaN(n);
                if (root.batPresent) {
                    root.batPercent = n;
                    root.batCharging = parts[2] === "Charging";
                }
            }
        }
    }

    // ---- eine Oberflaeche pro Monitor ----
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "#1e1e2e"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-greeter"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            GreeterSurface {
                anchors.fill: parent
                ctx: root
            }
        }
    }
}
