//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick.Controls

ShellRoot {
    // ==========================================
    // Globaler Zustand — geteilt zwischen allen Bars
    // ==========================================
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

    // ==========================================
    // Eine Bar-Instanz pro Monitor
    // ==========================================
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: topBar

            // Screen wird über eine required property injiziert
            required property var modelData

            screen: modelData
            color: "#1e1e2e"
            height: 32
            anchors { top: true; left: true; right: true }

            property var filteredWorkspaces: {
                var _dep = workspaceList;
                var result = [];
                for (var i = 0; i < _dep.length; i++) {
                    if (_dep[i].output === modelData.name) {
                        result.push(_dep[i]);
                    }
                }
                return result;
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 12

                Rectangle {
                    width: 32; Layout.fillHeight: true; color: "#89b4fa"; radius: 4
                    Text { text: "󱓞"; font.family: "Symbols Nerd Font"; anchors.centerIn: parent }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["fuzzel"])
                    }
                }

                Row {
                    spacing: 6
                    Layout.fillHeight: true
                    Repeater {
                        model: filteredWorkspaces
                        Rectangle {
                            width: 28; height: 28
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.is_focused ? "#a6e3a1" : (modelData.is_active ? "#313244" : "#181825")
                            border.color: modelData.is_focused ? "transparent" : "#45475a"
                            border.width: 1
                            radius: 4
                            Text {
                                text: modelData.idx
                                color: modelData.is_focused ? "#11111b" : "#cdd6f4"
                                font.bold: modelData.is_focused
                                anchors.centerIn: parent
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached([
                                        "niri", "msg", "action", "focus-workspace",
                                        String(modelData.idx)
                                    ])
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 16
                    Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: wlanStatus }
                    Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: "󰁹 " + batStatus }
                    Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: "󰍛 " + ramStatus }
                    Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: "󰘚 " + cpuStatus }
                }

                Row {
                    spacing: 4
                    Layout.fillHeight: true

                    Repeater {
                        model: SystemTray.items

                        Item {
                            id: trayItem
                            required property var modelData

                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            // Icon des Tray-Items
                            IconImage {
                                id: trayIcon
                                anchors.fill: parent
                                source: trayItem.modelData.icon
                            }

                            // Linksklick: Aktivieren (z.B. Fenster öffnen)
                            // Rechtsklick: Kontextmenü öffnen
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor

                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        trayMenuAnchor.open()
                                    } else {
                                        trayItem.modelData.activate()
                                    }
                                }

                                // Tooltip bei Hover
                                ToolTip.visible: containsMouse
                                ToolTip.text: trayItem.modelData.tooltipTitle !== ""
                                    ? trayItem.modelData.tooltipTitle
                                    : trayItem.modelData.title
                                ToolTip.delay: 500
                                hoverEnabled: true
                            }

                            // Kontextmenü
                            QsMenuAnchor {
                                id: trayMenuAnchor
                                menu: trayItem.modelData.menu
                                anchor.window: topBar
                                anchor.rect: Qt.rect(
                                    trayItem.mapToItem(null, 0, 0).x,
                                    topBar.height,
                                    trayItem.width,
                                    0
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}