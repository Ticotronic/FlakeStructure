//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "."

ShellRoot {       
    property var sessionSlots: [null, null, null] // 3 SessionSlots, initial leer
    property var windowList: []
    property var workspaceList: []
    property string wlanStatus: "Lade..."
    property string batStatus: "Lade..."
    property string ramStatus: "Lade..."
    property string cpuStatus: "Lade..."

    // ########################################
    // Funktionen zum Verwalten der Session Slots
    // ########################################
    // Snapshot des aktuellen Zustands erstellen
    function captureSnapshot() {
        var snapshot = [];
        for (var i = 0; i < workspaceList.length; i++) {
            var ws = workspaceList[i];
            if (ws.is_active) {
                snapshot.push({
                    output:    ws.output,
                    wsIdx:     ws.idx,
                    windowId:  ws.active_window_id
                });
            }
        }
        return snapshot;
    }

    // Snapshot wiederherstellen
    function restoreSnapshot(snapshot) {
        for (var i = 0; i < snapshot.length; i++) {
            var entry = snapshot[i];
            Quickshell.execDetached([
                "niri", "msg", "action", "focus-workspace", String(entry.wsIdx)
            ]);
            if (entry.windowId !== null) {
                Quickshell.execDetached([
                    "niri", "msg", "action", "focus-window",
                    "--id", String(entry.windowId)
                ]);
            }
        }
    }

    // Damit Niri die Slots auch von anderen Komponenten aus ansprechen kann (z.B. Shortcuts), müssen capture/restore als IPC-Handler-Funktionen verfügbar gemacht werden
    IpcHandler {
        target: "sessionSlots"

        function restore(index: int): void {
            restoreSnapshot(sessionSlots[index]);
        }

        function capture(index: int): void {
            var updated = [sessionSlots[0], sessionSlots[1], sessionSlots[2]];
            updated[index] = captureSnapshot();
            sessionSlots = updated;
        }
    }
    // ########################################

    Process {
        command: ["qs-stats"]
        running: true
        onExited: running = true
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split("|");
                if (parts.length === 4) {
                    wlanStatus = parts[0];
                    batStatus  = parts[1];
                    ramStatus  = parts[2];
                    cpuStatus  = parts[3];
                }
            }
        }
    }

    Process {
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let event = JSON.parse(data);
                    if (event.WorkspacesChanged) {
                        var sorted = event.WorkspacesChanged.workspaces.slice();
                        sorted.sort(function(a, b) { return a.idx - b.idx; });
                        workspaceList = sorted;
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
                    if (event.WorkspaceActiveWindowChanged) {
                        let wsId  = event.WorkspaceActiveWindowChanged.workspace_id;
                        let winId = event.WorkspaceActiveWindowChanged.active_window_id;
                        var updated = [];
                        for (var i = 0; i < workspaceList.length; i++) {
                            var ws = workspaceList[i];
                            updated.push({
                                id:               ws.id,
                                idx:              ws.idx,
                                name:             ws.name,
                                output:           ws.output,
                                is_urgent:        ws.is_urgent,
                                is_active:        ws.is_active,
                                is_focused:       ws.is_focused,
                                active_window_id: ws.id === wsId ? winId : ws.active_window_id
                            });
                        }
                        workspaceList = updated;
                    } else if (event.WindowsChanged) {
                        windowList = event.WindowsChanged.windows;

                    } else if (event.WindowFocusChanged) {
                        let focusedId = event.WindowFocusChanged.id;
                        var updatedWindows = [];
                        for (var j = 0; j < windowList.length; j++) {
                            var win = windowList[j];
                            updatedWindows.push({
                                id:          win.id,
                                title:       win.title,
                                app_id:      win.app_id,
                                workspace_id: win.workspace_id,
                                is_focused:  win.id === focusedId
                            });
                        }
                        windowList = updatedWindows;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        command: ["niri", "msg", "-j", "workspaces"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let initial = JSON.parse(data);
                    if (Array.isArray(initial)) {
                        var sorted = initial.slice();
                        sorted.sort(function(a, b) { return a.idx - b.idx; });
                        workspaceList = sorted;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        command: ["niri", "msg", "-j", "windows"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let initial = JSON.parse(data);
                    if (Array.isArray(initial)) {
                        windowList = initial;
                    }
                } catch (e) {}
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PowerOverlay {}
    }
}