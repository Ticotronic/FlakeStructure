import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

// Ein Fenster pro Screen (via Variants in shell.qml), sichtbar nur auf dem
// Screen, auf den NextcloudTasksDAV.activeScreen gerade zeigt - analog zu
// EventDialog.qml fuer Termine.
//
// Deckt Stufe 2 ab: Anlegen, Bearbeiten, Erledigen und Loeschen einer
// Aufgabe. Anders als bei Terminen gibt es hier keine rein lokalen Aufgaben -
// jede Aufgabe lebt in genau einer Nextcloud-Taskliste.
PanelWindow {
    id: dialogWindow
    required property var modelData
    screen: modelData

    visible: NextcloudTasksDAV.dialogVisible && NextcloudTasksDAV.activeScreen === modelData

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusiveZone: -1
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }

    readonly property var priorityOptions: [
        { label: "Keine", value: 0 },
        { label: "Hoch", value: 1 },
        { label: "Mittel", value: 5 },
        { label: "Niedrig", value: 9 }
    ]

    property string fTitle: ""
    property string fDescription: ""
    property bool fHasDueDate: false
    property string fDueDate: ""
    property bool fHasDueTime: false
    property string fDueTime: "09:00"
    property int fPriority: 0
    property bool fCompleted: false
    property string fListHref: ""

    readonly property bool isEditing: NextcloudTasksDAV.editingTaskUid !== ""
    readonly property var editingTask: dialogWindow.isEditing ? NextcloudTasksDAV.findTask(NextcloudTasksDAV.editingTaskUid) : null

    function todayStr() {
        var d = new Date();
        return d.getFullYear() + "-" + (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1) + "-" + (d.getDate() < 10 ? "0" : "") + d.getDate();
    }

    function resetForm() {
        var t = dialogWindow.editingTask;
        if (t) {
            fTitle = t.title;
            fDescription = t.description || "";
            fHasDueDate = !!t.dueDate;
            fDueDate = t.dueDate || dialogWindow.todayStr();
            fHasDueTime = !!t.dueTime;
            fDueTime = t.dueTime || "09:00";
            fPriority = t.priority || 0;
            fCompleted = !!t.completed;
            fListHref = t.listHref;
            return;
        }

        fTitle = "";
        fDescription = "";
        fHasDueDate = false;
        fDueDate = dialogWindow.todayStr();
        fHasDueTime = false;
        fDueTime = "09:00";
        fPriority = 0;
        fCompleted = false;
        fListHref = NextcloudTasksDAV.selectedListHref;
    }

    onVisibleChanged: if (visible) resetForm()

    // Wechsel von "neue Aufgabe" zu "diese hier bearbeiten" (Klick auf einen
    // Eintrag im TasksWidget) kann passieren, WAEHREND der Dialog schon
    // sichtbar ist - onVisibleChanged feuert dann nicht erneut.
    Connections {
        target: NextcloudTasksDAV
        function onEditingTaskUidChanged() {
            if (dialogWindow.visible) dialogWindow.resetForm();
        }
    }

    function save() {
        var fields = {
            title: fTitle.length > 0 ? fTitle : "(ohne Titel)",
            description: fDescription,
            completed: fCompleted,
            dueDate: fHasDueDate ? fDueDate : "",
            dueTime: (fHasDueDate && fHasDueTime) ? fDueTime : "",
            priority: fPriority
        };

        if (dialogWindow.isEditing) {
            var t = dialogWindow.editingTask;
            if (t) NextcloudTasksDAV.updateTask(t.uid, t.href, t.listHref, t.listName, fields);
        } else {
            NextcloudTasksDAV.createTask(fListHref, fields);
        }
        NextcloudTasksDAV.closeDialog();
    }

    function remove() {
        if (!dialogWindow.isEditing) { NextcloudTasksDAV.closeDialog(); return; }
        var t = dialogWindow.editingTask;
        if (t) NextcloudTasksDAV.deleteTask(t.uid, t.href);
        NextcloudTasksDAV.closeDialog();
    }

    // Klick-daneben-schliesst-Scrim
    MouseArea {
        anchors.fill: parent
        onClicked: NextcloudTasksDAV.closeDialog()
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 420
        height: 520
        color: "#1e1e2e"
        border.color: "#313244"
        border.width: 1
        radius: 10

        focus: true
        Keys.onEscapePressed: NextcloudTasksDAV.closeDialog()

        MouseArea {
            anchors.fill: parent
            onClicked: {} // schluckt Klicks, damit der Scrim nicht schliesst
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: dialogWindow.isEditing ? "Aufgabe bearbeiten" : "Neue Aufgabe"
                    color: "#cdd6f4"
                    font.pixelSize: 18
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    text: "✕"
                    color: "#a6adc8"
                    font.pixelSize: 16
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: NextcloudTasksDAV.closeDialog() }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: NextcloudTasksDAV.taskLists.length > 1
                Text { text: "Liste"; color: "#a6adc8"; font.pixelSize: 11 }
                ComboBox {
                    Layout.fillWidth: true
                    // Eine Aufgabe wird hier nicht zwischen Listen verschoben,
                    // nur bearbeitet oder geloescht - analog zu EventDialog.
                    enabled: !dialogWindow.isEditing
                    model: NextcloudTasksDAV.taskLists.map(function (l) { return l.name; })
                    currentIndex: {
                        for (var i = 0; i < NextcloudTasksDAV.taskLists.length; i++)
                            if (NextcloudTasksDAV.taskLists[i].href === dialogWindow.fListHref) return i;
                        return 0;
                    }
                    onActivated: index => dialogWindow.fListHref = NextcloudTasksDAV.taskLists[index].href
                }
            }

            TextField {
                Layout.fillWidth: true
                placeholderText: "Titel"
                text: dialogWindow.fTitle
                onTextChanged: dialogWindow.fTitle = text
            }

            TextArea {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                placeholderText: "Beschreibung"
                text: dialogWindow.fDescription
                onTextChanged: dialogWindow.fDescription = text
                wrapMode: TextArea.Wrap
            }

            RowLayout {
                Text { text: "Fälligkeit"; color: "#cdd6f4" }
                Switch { checked: dialogWindow.fHasDueDate; onCheckedChanged: dialogWindow.fHasDueDate = checked }
                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: dialogWindow.fHasDueDate
                spacing: 8
                TextField {
                    Layout.fillWidth: true
                    text: dialogWindow.fDueDate
                    onTextChanged: dialogWindow.fDueDate = text
                    placeholderText: "YYYY-MM-DD"
                }
                Switch { checked: dialogWindow.fHasDueTime; onCheckedChanged: dialogWindow.fHasDueTime = checked }
                TextField {
                    Layout.preferredWidth: 80
                    visible: dialogWindow.fHasDueTime
                    text: dialogWindow.fDueTime
                    onTextChanged: dialogWindow.fDueTime = text
                    placeholderText: "HH:MM"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Priorität"; color: "#a6adc8"; font.pixelSize: 11 }
                ComboBox {
                    Layout.fillWidth: true
                    model: dialogWindow.priorityOptions.map(function (o) { return o.label; })
                    currentIndex: {
                        for (var i = 0; i < dialogWindow.priorityOptions.length; i++)
                            if (dialogWindow.priorityOptions[i].value === dialogWindow.fPriority) return i;
                        return 0;
                    }
                    onActivated: index => dialogWindow.fPriority = dialogWindow.priorityOptions[index].value
                }
            }

            RowLayout {
                visible: dialogWindow.isEditing
                Text { text: "Erledigt"; color: "#cdd6f4" }
                Switch { checked: dialogWindow.fCompleted; onCheckedChanged: dialogWindow.fCompleted = checked }
                Item { Layout.fillWidth: true }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: "Löschen"
                    visible: dialogWindow.isEditing
                    onClicked: dialogWindow.remove()
                }
                Item { Layout.fillWidth: true }
                Button { text: "Abbrechen"; onClicked: NextcloudTasksDAV.closeDialog() }
                Button { text: "Speichern"; highlighted: true; onClicked: dialogWindow.save() }
            }
        }
    }
}
