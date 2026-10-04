import QtQuick
import QtQuick.Layouts
import Quickshell

// Popup mit der Aufgabenliste.
// Checkbox-Klick erledigt/eroeffnet eine Aufgabe direkt; Klick auf den Titel
// oeffnet TaskDialog.qml zum Bearbeiten; "+ Neu" legt eine neue Aufgabe an.
//
// Teilaufgaben (CalDAV: RELATED-TO auf die UID der Hauptaufgabe, siehe
// NextcloudTasksDAV.qml) werden unter ihrer Hauptaufgabe eingerueckt und nur
// angezeigt, wenn die Hauptaufgabe ausgeklappt ist (expandedUids). Der
// Aufklapp-Zustand lebt nur hier in der UI, nicht in NextcloudTasksDAV -
// er ist reine Anzeigesache und muss nicht mit dem Server abgeglichen werden.
PopupWindow {
    id: tasksPopup

    property var anchorWindow: null
    property var anchorItem: null
    property bool open: false
    property bool showCompleted: false
    signal closeRequested()

    visible: open

    anchor.window: anchorWindow
    anchor.rect: Qt.rect(
        anchorItem ? anchorItem.mapToItem(null, 0, 0).x + anchorItem.width / 2 - tasksPopup.implicitWidth / 2 : 0,
        anchorWindow ? anchorWindow.height : 0,
        0, 0
    )
    anchor.edges: Edges.Top

    implicitWidth: 380
    implicitHeight: 420

    readonly property string todayStr: {
        var d = new Date();
        return d.getFullYear() + "-" + (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1) + "-" + (d.getDate() < 10 ? "0" : "") + d.getDate();
    }

    // uid -> true fuer jede Hauptaufgabe, deren Teilaufgaben gerade
    // eingeblendet sind.
    property var expandedUids: ({})

    function expandUid(uid) {
        var copy = Object.assign({}, tasksPopup.expandedUids);
        copy[uid] = true;
        tasksPopup.expandedUids = copy;
    }

    function toggleExpanded(uid) {
        var copy = Object.assign({}, tasksPopup.expandedUids);
        copy[uid] = !copy[uid];
        tasksPopup.expandedUids = copy;
    }

    // Zeilenliste (Sortierung/Baum-Logik: NextcloudTasksDAV.buildRows)
    readonly property var displayRows: NextcloudTasksDAV.buildRows(tasksPopup.showCompleted, false, tasksPopup.expandedUids, "")

    onVisibleChanged: if (visible) NextcloudTasksDAV.fetchNow()

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
        border.color: "#313244"
        border.width: 1
        radius: 8

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Aufgaben"
                    color: "#cdd6f4"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: "+ Neu"
                    color: "#a6e3a1"
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var defaultList = NextcloudTasksDAV.taskLists.length > 0 ? NextcloudTasksDAV.taskLists[0].href : "";
                            NextcloudTasksDAV.openForCreate(defaultList, tasksPopup.anchorWindow.screen);
                            tasksPopup.closeRequested();
                        }
                    }
                }

                Text {
                    text: "Vergrößern"
                    color: "#89b4fa"
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Eigenes, zentriertes Fenster (TasksOverview.qml)
                            var screen = tasksPopup.anchorWindow.screen;
                            NextcloudTasksDAV.openOverview(screen);
                            tasksPopup.closeRequested();
                        }
                    }
                }

                Text {
                    text: "Aktualisieren"
                    color: "#89b4fa"
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NextcloudTasksDAV.fetchNow()
                    }
                }

                Text {
                    text: "  x"
                    color: "#6c7086"
                    font.pixelSize: 13
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tasksPopup.closeRequested()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: (tasksPopup.showCompleted ? "☑" : "☐") + " Erledigte anzeigen"
                    color: "#a6adc8"
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tasksPopup.showCompleted = !tasksPopup.showCompleted
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: NextcloudTasksDAV.lastFetchFailed
                    text: "Sync fehlgeschlagen"
                    color: "#f38ba8"
                    font.pixelSize: 11
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: tasksPopup.displayRows

                delegate: RowLayout {
                    width: ListView.view.width
                    spacing: 8

                    // Einrueckung fuer Teilaufgaben (depth 1)
                    Item { Layout.preferredWidth: modelData.depth * 18; Layout.preferredHeight: 1 }

                    Text {
                        Layout.preferredWidth: 14
                        text: modelData.hasChildren ? (modelData.expanded ? "▾" : "▸") : ""
                        color: "#89b4fa"
                        font.pixelSize: 12
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            enabled: modelData.hasChildren
                            cursorShape: modelData.hasChildren ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: tasksPopup.toggleExpanded(modelData.uid)
                        }
                    }

                    Text {
                        text: modelData.completed ? "☑" : "☐"
                        color: modelData.completed ? "#6c7086" : NextcloudTasksDAV.priorityColor(modelData.priority)
                        font.pixelSize: 14
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NextcloudTasksDAV.setCompleted(modelData, !modelData.completed)
                        }
                    }

                    Item {
                        // Plain Item statt direkt ColumnLayout als Layout-Kind,
                        // damit die MouseArea unten per anchors.fill auf ein
                        // Nicht-Layout-Item zielt (sonst "undefined behavior"-
                        // Warnung, weil ein von ColumnLayout verwaltetes Kind
                        // gleichzeitig Anchors benutzt).
                        Layout.fillWidth: true
                        implicitHeight: titleColumn.implicitHeight

                        ColumnLayout {
                            id: titleColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: modelData.completed ? "#6c7086" : "#cdd6f4"
                                font.pixelSize: 13
                                font.strikeout: modelData.completed
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: modelData.listName !== ""
                                text: modelData.listName + ((modelData.tags && modelData.tags.length > 0)
                                    ? "  ·  " + modelData.tags.map(function (t) { return "#" + t; }).join(" ")
                                    : "")
                                color: "#6c7086"
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                NextcloudTasksDAV.openForEdit(modelData.uid, tasksPopup.anchorWindow.screen);
                                tasksPopup.closeRequested();
                            }
                        }
                    }

                    Text {
                        visible: modelData.depth === 0
                        text: "+"
                        color: "#a6e3a1"
                        font.pixelSize: 14
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Elternaufgabe aufklappen, damit die neue Teilaufgabe sichtbar ist
                                // Werte VOR dem Aendern von expandedUids sichern: das
                                // erzeugt eine neue displayRows-Liste, das ListView
                                // baut seine Delegates neu auf, und modelData ist in
                                // diesem (dann zerstoerten) Delegate danach undefined.
                                var parentUid = modelData.uid;
                                var parentListHref = modelData.listHref;
                                var screen = tasksPopup.anchorWindow.screen;

                                NextcloudTasksDAV.openForCreate(parentListHref, screen, parentUid);
                                tasksPopup.closeRequested();

                                // Als Allerletztes und verzoegert: das Aufklappen
                                // baut die Delegates neu auf; danach darf in diesem
                                // Delegate nichts mehr laufen (sonst z.B.
                                // "tasksPopup is not defined").
                                Qt.callLater(tasksPopup.expandUid, parentUid);
                            }
                        }
                    }

                    Text {
                        visible: modelData.dueDate !== ""
                        text: modelData.dueDate
                        color: (!modelData.completed && modelData.dueDate < tasksPopup.todayStr) ? "#f38ba8" : "#a6adc8"
                        font.pixelSize: 11
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: tasksPopup.displayRows.length === 0
                text: "Keine Aufgaben"
                color: "#6c7086"
                font.pixelSize: 12
            }
        }
    }
}
