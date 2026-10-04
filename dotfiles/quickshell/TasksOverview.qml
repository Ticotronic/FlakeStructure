import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Grosse Aufgaben-Uebersicht als eigenes, zentriertes Fenster (ein Fenster
// pro Screen via Variants in shell.qml, sichtbar nur auf dem Screen, auf dem
// sie geoeffnet wurde). Geoeffnet ueber "Vergroessern" im kleinen Popup
// (TasksWidget.qml).
//
// Links: Schlagwort-Spalte (Klick filtert, nochmal klicken hebt den Filter
// auf). Rechts: Aufgaben mit Beschreibung, alle Teilaufgaben immer
// eingeblendet. Gruener "+"-Button unten rechts legt eine neue Aufgabe an.
//
// Waehrend der TaskDialog offen ist, blendet sich dieses Fenster aus und
// danach wieder ein - so liegt der Dialog sicher obenauf, ohne sich auf die
// Stapelreihenfolge zweier Overlay-Fenster zu verlassen.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    visible: NextcloudTasksDAV.overviewVisible
             && !NextcloudTasksDAV.dialogVisible
             && NextcloudTasksDAV.overviewScreen === modelData

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusiveZone: -1
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }

    property bool showCompleted: false
    property string selectedTag: "" // "" = alle

    readonly property var rows: NextcloudTasksDAV.buildRows(win.showCompleted, true, ({}), win.selectedTag)
    readonly property var tagEntries: [""].concat(NextcloudTasksDAV.allTags)

    readonly property string todayStr: {
        var d = new Date();
        return d.getFullYear() + "-" + (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1) + "-" + (d.getDate() < 10 ? "0" : "") + d.getDate();
    }

    onVisibleChanged: if (visible) NextcloudTasksDAV.fetchNow()

    // Ein Filter auf ein Schlagwort, das es nicht mehr gibt (z.B. nach dem
    // Entfernen an der letzten Aufgabe), wuerde eine leere Liste ohne
    // erkennbaren Grund zeigen.
    Connections {
        target: NextcloudTasksDAV
        function onTasksChanged() {
            if (win.selectedTag !== "" && NextcloudTasksDAV.allTags.indexOf(win.selectedTag) === -1)
                win.selectedTag = "";
        }
    }

    // Abdunkelnder Hintergrund; Klick daneben schliesst
    Rectangle {
        anchors.fill: parent
        color: "#99000000"
        MouseArea {
            anchors.fill: parent
            onClicked: NextcloudTasksDAV.closeOverview()
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(1200, parent.width - 80)
        height: Math.min(760, parent.height - 80)
        color: "#1e1e2e"
        border.color: "#313244"
        border.width: 1
        radius: 12

        focus: true
        Keys.onEscapePressed: NextcloudTasksDAV.closeOverview()

        MouseArea {
            anchors.fill: parent
            onClicked: {} // schluckt Klicks, damit der Hintergrund nicht schliesst
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // ---- Schlagwort-Spalte ------------------------------------
            Rectangle {
                Layout.preferredWidth: 230
                Layout.fillHeight: true
                color: "#181825"
                radius: 11

                // rechte Ecken eckig lassen (nur linke Panel-Ecken sind rund)
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 12
                    color: parent.color
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "Schlagwörter"
                        color: "#cdd6f4"
                        font.pixelSize: 15
                        font.bold: true
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: win.tagEntries

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 30
                            radius: 6
                            readonly property bool isSelected: win.selectedTag === modelData
                            color: isSelected ? "#313244" : (tagHover.containsMouse ? "#262637" : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData === "" ? "Alle Aufgaben" : "#" + modelData
                                    color: parent.parent.isSelected ? "#89b4fa" : "#cdd6f4"
                                    font.pixelSize: 13
                                    font.bold: parent.parent.isSelected
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: modelData !== ""
                                    text: NextcloudTasksDAV.openCountForTag(modelData)
                                    color: "#6c7086"
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                id: tagHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // nochmal auf das aktive Schlagwort klicken hebt den Filter auf
                                onClicked: win.selectedTag = (win.selectedTag === modelData ? "" : modelData)
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: NextcloudTasksDAV.allTags.length === 0
                        text: "Noch keine Schlagwörter vergeben."
                        color: "#6c7086"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }
            }

            // ---- Aufgabenliste ----------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 18
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "Aufgaben"
                        color: "#cdd6f4"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Text {
                        visible: win.selectedTag !== ""
                        text: "#" + win.selectedTag
                        color: "#89b4fa"
                        font.pixelSize: 15
                    }
                    Item { Layout.fillWidth: true }

                    Text {
                        text: (win.showCompleted ? "☑" : "☐") + " Erledigte anzeigen"
                        color: "#a6adc8"
                        font.pixelSize: 12
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.showCompleted = !win.showCompleted
                        }
                    }
                    Text {
                        visible: NextcloudTasksDAV.lastFetchFailed
                        text: "Sync fehlgeschlagen"
                        color: "#f38ba8"
                        font.pixelSize: 11
                    }
                    Text {
                        text: "Aktualisieren"
                        color: "#89b4fa"
                        font.pixelSize: 12
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NextcloudTasksDAV.fetchNow()
                        }
                    }
                    Text {
                        text: "✕"
                        color: "#a6adc8"
                        font.pixelSize: 16
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NextcloudTasksDAV.closeOverview()
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: win.rows
                    // Platz unter der letzten Zeile, damit der "+"-Button sie nicht verdeckt
                    footer: Item { width: 1; height: 84 }

                    delegate: RowLayout {
                        width: ListView.view.width
                        spacing: 10

                        // Einrueckung fuer Teilaufgaben
                        Item { Layout.preferredWidth: modelData.depth * 30; Layout.preferredHeight: 1 }

                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: modelData.completed ? "☑" : "☐"
                            color: modelData.completed ? "#6c7086" : NextcloudTasksDAV.priorityColor(modelData.priority)
                            font.pixelSize: modelData.depth === 0 ? 18 : 15
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NextcloudTasksDAV.setCompleted(modelData, !modelData.completed)
                            }
                        }

                        Item {
                            // Plain Item als Layout-Kind, damit die MouseArea per
                            // anchors.fill auf ein Nicht-Layout-Item zielt.
                            Layout.fillWidth: true
                            implicitHeight: textColumn.implicitHeight

                            ColumnLayout {
                                id: textColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: modelData.completed ? "#6c7086" : "#cdd6f4"
                                    font.pixelSize: modelData.depth === 0 ? 15 : 13
                                    font.strikeout: modelData.completed
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: modelData.depth === 0 && (modelData.listName !== "" || (modelData.tags && modelData.tags.length > 0))
                                    text: modelData.listName + ((modelData.tags && modelData.tags.length > 0)
                                        ? "  ·  " + modelData.tags.map(function (t) { return "#" + t; }).join(" ")
                                        : "")
                                    color: "#6c7086"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: modelData.description !== ""
                                    text: modelData.description
                                    color: "#a6adc8"
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NextcloudTasksDAV.openForEdit(modelData.uid, win.modelData)
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignTop
                            visible: modelData.dueDate !== ""
                            text: modelData.dueDate + (modelData.dueTime !== "" ? "  " + modelData.dueTime : "")
                            color: (!modelData.completed && modelData.dueDate < win.todayStr) ? "#f38ba8" : "#a6adc8"
                            font.pixelSize: 12
                        }

                        // Neue Teilaufgabe zu dieser Hauptaufgabe
                        Text {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 16
                            text: modelData.depth === 0 ? "+" : ""
                            color: "#a6e3a1"
                            font.pixelSize: 16
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                enabled: modelData.depth === 0
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NextcloudTasksDAV.openForCreate(modelData.listHref, win.modelData, modelData.uid)
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: win.rows.length === 0
                    text: win.selectedTag !== "" ? "Keine Aufgaben mit diesem Schlagwort" : "Keine Aufgaben"
                    color: "#6c7086"
                    font.pixelSize: 13
                }
            }
        }

        // ---- Gruener "+"-Button: neue Aufgabe -------------------------
        Rectangle {
            id: fab
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 26
            width: 58
            height: 58
            radius: 29
            color: fabArea.pressed ? "#8bd18a" : (fabArea.containsMouse ? "#b8efb3" : "#a6e3a1")
            z: 10

            Text {
                anchors.centerIn: parent
                text: "+"
                color: "#1e1e2e"
                font.pixelSize: 34
                font.bold: true
            }

            MouseArea {
                id: fabArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var defaultList = NextcloudTasksDAV.taskLists.length > 0 ? NextcloudTasksDAV.taskLists[0].href : "";
                    NextcloudTasksDAV.openForCreate(defaultList, win.modelData, "");
                }
            }
        }
    }
}
