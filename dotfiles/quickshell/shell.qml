import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
    
// Zukünftige Importe für SystemTray und Prozesse:
// import Quickshell.Services.SystemTray

PanelWindow {
    id: topBar
    color: "#1e1e2e" // Ein dunkles Catppuccin-Grau
    height: 32
    
    // Verankert das Fenster oben am Bildschirm
    anchors {
        top: true
        left: true
        right: true
    }

    // Variablen für die Statusanzeigen, initial mit "Lade..." gefüllt
    property string wlanStatus: "Lade..."
    property string batStatus: "Lade..."
    property string ramStatus: "Lade..."
    property string cpuStatus: "Lade..."

    // Ein dynamisches Array für die Workspaces
    property var workspaceList: []

    // which process is priorized for initial loading of workspaces, niri event stream or initial workspaces command
    property bool initialLoaded: false

    // ==========================================
    // Hintergrundprozess: qs-stats ausführen und Status aktualisieren
    // ==========================================
    Process {
        id: statsProc
        command: ["qs-stats"]
        running: true
        onExited: running = true  // Neustart bei Crash
        
        // Wenn das Skript eine neue Zeile (echo) ausgibt, splitten wir sie
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split("|");
                if (parts.length === 4) {
                    wlanStatus = parts[0];
                    batStatus = parts[1];
                    ramStatus = parts[2];
                    cpuStatus = parts[3];
                }
            }
        }
    }

    // ==========================================
    // Der Niri IPC Event-Stream-Prozess
    // ==========================================
    // Event-Stream: beide Events behandeln
    Process {
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let event = JSON.parse(data);

                    if (event.WorkspacesChanged) {
                        // Vollständiges Update (z.B. beim Start oder wenn Workspaces erstellt/gelöscht werden)
                        workspaceList = event.WorkspacesChanged.workspaces;

                    } else if (event.WorkspaceActivated) {
                        let activatedId = event.WorkspaceActivated.id;
                        let isFocused   = event.WorkspaceActivated.focused;

                        var updated = [];
                        for (var i = 0; i < workspaceList.length; i++) {
                            var ws = workspaceList[i];
                            updated.push({
                                id:               ws.id,
                                idx:              ws.idx,
                                name:             ws.name,
                                output:           ws.output,
                                is_urgent:        ws.is_urgent,
                                is_active:        ws.id === activatedId ? true : ws.is_active,
                                is_focused:       isFocused ? (ws.id === activatedId) : ws.is_focused,
                                active_window_id: ws.active_window_id
                            });
                        }
                        workspaceList = updated;
                    }
                } catch (e) {}
            }
        }
    }

    // ==========================================
    // Holt den initialen Zustand beim Start
    // ==========================================
    Process {
        command: ["niri", "msg", "-j", "workspaces"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let initialWorkspaces = JSON.parse(data);
                    // Der einfache "workspaces" Befehl gibt direkt ein Array zurück
                    if (Array.isArray(initialWorkspaces)) {
                        workspaceList = initialWorkspaces;
                        initialLoaded = true; // Markiere, dass die initialen Daten geladen wurden
                    }
                } catch (e) {
                    // Ignoriere unvollständige Daten
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 12

        // ==========================================
        // LINKS: App Launcher (Fuzzel)
        // ==========================================
        Rectangle {
            width: 32; Layout.fillHeight: true; color: "#89b4fa"; radius: 4
            Text { text: "󱓞"; font.family: "Symbols Nerd Font"; anchors.centerIn: parent }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // Aktiviert deinen Launcher direkt aus Quickshell heraus
                onClicked: Quickshell.execDetached(["fuzzel"])
            }
        }
        

        // ==========================================
        // LINKS-MITTE: Workspaces (Niri)
        // ==========================================
        Row {
            spacing: 6
            Layout.fillHeight: true
            // Dies ist ein statischer Platzhalter. 
            // Für Niri müssen wir später JSON via Kommandozeile parsen.
            Repeater {
                model: workspaceList

                Rectangle {
                    width: 28; height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    color: modelData.is_focused ? "#a6e3a1" : (modelData.is_active ? "#313244" : "#181825")
                    border.color: modelData.is_focused ? "transparent" : "#45475a"
                    border.width: 1
                    radius: 4
                    Text {
                        text: modelData.name
                        color: modelData.is_focused ? "#11111b" : "#cdd6f4"
                        font.bold: modelData.is_focused
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        // Erlaubt das Klicken auf die Bar, um den Workspace zu wechseln!
                        onClicked: {
                            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(modelData.id)])
                        }
                    }
                }
            }
        }

        // ==========================================
        // MITTE: Leerer Raum (Spacer)
        // ==========================================
        Item { 
            Layout.fillWidth: true 
        }

        // ==========================================
        // RECHTS: System Status
        // ==========================================
        RowLayout {
            spacing: 16
            Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: wlanStatus }
            Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: "󰁹 " + batStatus }
            Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: "󰍛 " + ramStatus }
            Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: "󰘚 " + cpuStatus }
        }

        // ==========================================
        // GANZ RECHTS: System Tray
        // ==========================================
        Rectangle {
            color: "#313244"
            Layout.fillHeight: true
            width: 80
            radius: 4
            Text { 
                color: "#cdd6f4"
                text: "[Tray]" 
                anchors.centerIn: parent 
            }
        }
    }
}