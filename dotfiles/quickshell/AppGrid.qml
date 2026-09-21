import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: appGrid
    clip: true

    Column {
        width: appGrid.width
        spacing: 0
        topPadding: 10
        leftPadding: 10
        rightPadding: 10
        bottomPadding: 10

        // ==========================================
        // Section-Titel: Apps
        // ==========================================
        Item {
            width: parent.width - 20
            height: 24
            visible: LauncherMenu.filteredApps.length > 0
                     && LauncherMenu.activeCategory !== "SSH-Hosts"
                     && LauncherMenu.activeCategory !== "Favoriten"
                     && LauncherMenu.activeCategory !== "Skripte"
            Text {
                text: "APPS"
                color: "#45475a"
                font.pixelSize: 10
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ==========================================
        // App-Grid (Flow)
        // ==========================================
        Grid {
            width: parent.width - 20
            columns: LauncherMenu.gridColumns
            spacing: 6
            visible: LauncherMenu.activeCategory !== "SSH-Hosts"
                     && LauncherMenu.activeCategory !== "Favoriten"
                     && LauncherMenu.activeCategory !== "Skripte"

            Repeater {
                model: LauncherMenu.filteredApps
                LauncherItem {
                    app: modelData
                }
            }
        }

        // ==========================================
        // Section-Titel: SSH-Hosts
        // ==========================================
        Item {
            width: parent.width - 20
            height: 32
            visible: LauncherMenu.activeCategory === "Alle Apps"
                     || LauncherMenu.activeCategory === "SSH-Hosts"
            Text {
                text: "SSH-HOSTS"
                color: "#45475a"
                font.pixelSize: 10
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ==========================================
        // SSH-Host-Liste
        // ==========================================
        Column {
            width: parent.width - 20
            spacing: 3
            visible: LauncherMenu.activeCategory === "Alle Apps"
                     || LauncherMenu.activeCategory === "SSH-Hosts"

            Repeater {
                model: LauncherMenu.sshHosts
                CustomItem {
                    width: parent.width
                    itemName: modelData.name
                    itemDescription: (modelData.user || "root") + "@" + modelData.host + " · Port " + (modelData.port || 22)
                    itemIcon: "network-server"
                    itemCommand: [
                        "kitty", "ssh",
                        "-p", String(modelData.port || 22),
                        (modelData.user || "root") + "@" + modelData.host
                    ]
                }
            }
        }

        // ==========================================
        // Section-Titel: Eigene Einträge
        // ==========================================
        Item {
            width: parent.width - 20
            height: 32
            visible: LauncherMenu.activeCategory === "Alle Apps"
                     || LauncherMenu.activeCategory === "Skripte"
            Text {
                text: "EIGENE EINTRÄGE"
                color: "#45475a"
                font.pixelSize: 10
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ==========================================
        // Eigene Einträge Liste
        // ==========================================
        Column {
            width: parent.width - 20
            spacing: 3
            visible: LauncherMenu.activeCategory === "Alle Apps"
                     || LauncherMenu.activeCategory === "Skripte"

            Repeater {
                model: LauncherMenu.customEntries
                CustomItem {
                    width: parent.width
                    itemName: modelData.name
                    itemDescription: modelData.description || ""
                    itemIcon: modelData.icon || "application-x-executable"
                    itemCommand: modelData.command || []
                }
            }
        }
    }
}