//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "."

ShellRoot {
    property var workspaceList: []
    property string wlanStatus: "Lade..."
    property string batStatus: "Lade..."
    property string ramStatus: "Lade..."
    property string cpuStatus: "Lade..."

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

    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }
}