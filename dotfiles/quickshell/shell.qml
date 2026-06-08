import QtQuick
    import QtQuick.Layouts
    import Quickshell
    
    // Zukünftige Importe für SystemTray und Prozesse:
    // import Quickshell.Services.SystemTray
    // import Quickshell.Io

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

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 12

            // ==========================================
            // LINKS: App Launcher
            // ==========================================
            Rectangle {
                width: 32
                Layout.fillHeight: true
                color: "#89b4fa"
                radius: 4
                
                Text { 
                    text: "🚀"
                    anchors.centerIn: parent 
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // Später nutzen wir Quickshell.Io / Process um fuzzel zu starten
                    onClicked: console.log("Launcher geklickt!")
                }
            }

            // ==========================================
            // LINKS-MITTE: Workspaces (Niri)
            // ==========================================
            Row {
                spacing: 4
                // Dies ist ein statischer Platzhalter. 
                // Für Niri müssen wir später JSON via Kommandozeile parsen.
                Repeater {
                    model: 4
                    Rectangle {
                        width: 24; height: 24
                        color: index === 0 ? "#a6e3a1" : "#313244" // Workspace 1 aktiv
                        radius: 4
                        Text {
                            text: index + 1
                            color: "#11111b"
                            anchors.centerIn: parent
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

                Text { color: "#cdd6f4"; font.pixelSize: 14; text: "📡 WLAN" }
                Text { color: "#cdd6f4"; font.pixelSize: 14; text: "🔋 85%" }
                Text { color: "#cdd6f4"; font.pixelSize: 14; text: "🧠 RAM: --" }
                Text { color: "#cdd6f4"; font.pixelSize: 14; text: "⚙️ CPU: --" }
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