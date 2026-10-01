import QtQuick
import QtQuick.Layouts
import Quickshell

// Popup mit der Aufgabenliste.
// Checkbox-Klick erledigt/eroeffnet eine Aufgabe direkt; Klick auf den Titel
// oeffnet TaskDialog.qml zum Bearbeiten; "+ Neu" legt eine neue Aufgabe an.
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

    readonly property var sortedTasks: {
        function cmp(a, b) {
            if (a.dueDate && b.dueDate) return a.dueDate < b.dueDate ? -1 : (a.dueDate > b.dueDate ? 1 : 0);
            if (a.dueDate && !b.dueDate) return -1;
            if (!a.dueDate && b.dueDate) return 1;
            return 0;
        }

        var all = NextcloudTasksDAV.tasks;
        var openTasks = [];
        var doneTasks = [];
        for (var i = 0; i < all.length; i++) {
            if (all[i].completed) doneTasks.push(all[i]);
            else openTasks.push(all[i]);
        }
        openTasks.sort(cmp);
        doneTasks.sort(cmp);

        return tasksPopup.showCompleted ? openTasks.concat(doneTasks) : openTasks;
    }

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
                model: tasksPopup.sortedTasks

                delegate: RowLayout {
                    width: ListView.view.width
                    spacing: 8

                    Text {
                        text: modelData.completed ? "☑" : "☐"
                        color: modelData.completed ? "#6c7086" : "#cdd6f4"
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
                                text: modelData.listName
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
                        visible: modelData.dueDate !== ""
                        text: modelData.dueDate
                        color: (!modelData.completed && modelData.dueDate < tasksPopup.todayStr) ? "#f38ba8" : "#a6adc8"
                        font.pixelSize: 11
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: tasksPopup.sortedTasks.length === 0
                text: "Keine Aufgaben"
                color: "#6c7086"
                font.pixelSize: 12
            }
        }
    }
}
