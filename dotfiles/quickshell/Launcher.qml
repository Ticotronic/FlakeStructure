import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: launcherWindow
    required property var modelData
    screen: modelData

    visible: LauncherMenu.visible && LauncherMenu.activeScreen === modelData
    color: "transparent"

    anchors { top: true; left: true; right: true; bottom: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusiveZone: -1

    // Klick außerhalb schließt den Launcher
    MouseArea {
        anchors.fill: parent
        onClicked: LauncherMenu.hide()
    }

    // Zentriertes Launcher-Panel
    Rectangle {
        id: panel
        width: 700
        height: 500
        anchors.centerIn: parent
        radius: 12
        color: "#1e1e2e"
        border.color: "#313244"
        border.width: 1
        focus: true

        Keys.onEscapePressed: LauncherMenu.hide()

        // Klick ins Panel nicht durchleiten
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ==========================================
            // Suchfeld
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                height: 48
                color: "transparent"
                border.color: "#313244"
                border.width: 0
                radius: 12

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "󰍉"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 18
                        color: "#6c7086"
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: "#cdd6f4"
                        font.pixelSize: 14
                        text: LauncherMenu.searchText
                        onTextChanged: LauncherMenu.searchText = text
                        focus: launcherWindow.visible

                        Text {
                            anchors.fill: parent
                            text: "App suchen..."
                            color: "#45475a"
                            font.pixelSize: 14
                            visible: parent.text === ""
                        }

                        Keys.onEscapePressed: LauncherMenu.hide()
                    }

                    Text {
                        text: LauncherMenu.filteredApps.length + " Treffer"
                        color: "#45475a"
                        font.pixelSize: 11
                        visible: LauncherMenu.searchText !== ""
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#313244"
            }

            // ==========================================
            // Body: Kategorien + App-Grid
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Linke Spalte: Kategorien
                Rectangle {
                    Layout.preferredWidth: 160
                    Layout.fillHeight: true
                    color: "transparent"
                    border.color: "#313244"
                    border.width: 0

                    CategoryList {
                        anchors.fill: parent
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    width: 1
                    color: "#313244"
                }

                // Rechte Spalte: Apps
                AppGrid {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#313244"
            }

            // ==========================================
            // Statusleiste
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                height: 28
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 14

                    Repeater {
                        model: [
                            { key: "↑↓", desc: "navigieren" },
                            { key: "Enter", desc: "öffnen" },
                            { key: "Esc", desc: "schließen" },
                            { key: "Tab", desc: "Kategorie" }
                        ]
                        RowLayout {
                            spacing: 4
                            Rectangle {
                                width: hintText.implicitWidth + 8
                                height: 16
                                radius: 3
                                color: "#313244"
                                border.color: "#45475a"
                                border.width: 1
                                Text {
                                    id: hintText
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: "#6c7086"
                                    font.pixelSize: 10
                                }
                            }
                            Text {
                                text: modelData.desc
                                color: "#45475a"
                                font.pixelSize: 10
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}