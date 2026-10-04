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

    // Wie in der Tasks-Android-App (Reihenfolge hier umgekehrt: Keine/Niedrig/Mittel/Hoch).
    // Farben: Material 500 aus tasks/tasks (kmp ColorProvider.priorityColor:
    // RED_500 / AMBER_500 / BLUE_500 / GREY_500). Die App tont diese Basisfarben
    // noch fuer Hell/Dunkel nach; hier die unveraenderten Basiswerte.
    // value = iCalendar-PRIORITY (1 hoch, 5 mittel, 9 niedrig, 0 keine) - so
    // bildet Tasks.org sie per CalDAV ab.
    readonly property var priorityOptions: [
        { label: "Keine",   value: 0, color: "#9e9e9e" },
        { label: "Niedrig", value: 9, color: "#2196f3" },
        { label: "Mittel",  value: 5, color: "#ffc107" },
        { label: "Hoch",    value: 1, color: "#f44336" }
    ]

    // Fremde Clients duerfen 1-4 (hoch), 5 (mittel), 6-9 (niedrig) schreiben:
    // auf die vier Stufen der Auswahl abbilden.
    function normalizePriority(p) {
        if (p >= 1 && p <= 4) return 1;
        if (p === 5) return 5;
        if (p >= 6 && p <= 9) return 9;
        return 0;
    }

    property string fTitle: ""
    property string fDescription: ""
    property bool fHasDueDate: false
    property string fDueDate: ""
    property bool fHasDueTime: false
    property string fDueTime: "09:00"
    property int fPriority: 0
    property bool fCompleted: false
    property string fListHref: ""
    property var fTags: []

    // Vorschlaege fuer den Dropdown: alle bekannten Schlagwoerter, die an
    // dieser Aufgabe noch nicht gesetzt sind.
    readonly property var availableTags: NextcloudTasksDAV.allTags.filter(function (t) {
        return dialogWindow.fTags.indexOf(t) === -1;
    })

    function addTag(raw) {
        var t = String(raw || "").trim();
        if (t.length === 0 || dialogWindow.fTags.indexOf(t) !== -1) return;
        dialogWindow.fTags = dialogWindow.fTags.concat([t]);
    }

    function removeTag(t) {
        dialogWindow.fTags = dialogWindow.fTags.filter(function (x) { return x !== t; });
    }

    readonly property bool isEditing: NextcloudTasksDAV.editingTaskUid !== ""
    // Neue Teilaufgabe: Elternaufgabe (nur beim Anlegen relevant)
    readonly property bool isSubtaskCreate: !dialogWindow.isEditing && NextcloudTasksDAV.creatingParentUid !== ""
    readonly property var creatingParent: dialogWindow.isSubtaskCreate ? NextcloudTasksDAV.findTask(NextcloudTasksDAV.creatingParentUid) : null
    readonly property var editingTask: dialogWindow.isEditing ? NextcloudTasksDAV.findTask(NextcloudTasksDAV.editingTaskUid) : null

    // ---- Faelligkeitsdatum-Auswahl (wie in der Tasks-App: Schnellwahl +
    // Monatskalender) ----

    property bool showCalendar: false
    property int shownYear: new Date().getFullYear()
    property int shownMonth: new Date().getMonth() // 0-11

    readonly property var monthNames: ["Januar", "Februar", "März", "April", "Mai", "Juni",
                                       "Juli", "August", "September", "Oktober", "November", "Dezember"]
    readonly property var weekdayNames: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    function pad2(n) { return (n < 10 ? "0" : "") + n; }

    function dateToStr(d) {
        return d.getFullYear() + "-" + dialogWindow.pad2(d.getMonth() + 1) + "-" + dialogWindow.pad2(d.getDate());
    }

    function offsetDateStr(days) {
        var d = new Date();
        d.setDate(d.getDate() + days);
        return dialogWindow.dateToStr(d);
    }

    function syncShownMonth() {
        var d = dialogWindow.fHasDueDate && dialogWindow.fDueDate.length === 10
            ? new Date(dialogWindow.fDueDate + "T00:00:00")
            : new Date();
        if (isNaN(d.getTime())) d = new Date();
        dialogWindow.shownYear = d.getFullYear();
        dialogWindow.shownMonth = d.getMonth();
    }

    function setDue(str) {
        dialogWindow.fDueDate = str;
        dialogWindow.fHasDueDate = true;
        dialogWindow.syncShownMonth();
    }

    function clearDue() {
        dialogWindow.fHasDueDate = false;
        dialogWindow.fHasDueTime = false;
        dialogWindow.showCalendar = false;
    }

    function shiftMonth(delta) {
        var d = new Date(dialogWindow.shownYear, dialogWindow.shownMonth + delta, 1);
        dialogWindow.shownYear = d.getFullYear();
        dialogWindow.shownMonth = d.getMonth();
    }

    // Datum der Kalenderzelle i (0-41), Woche beginnt am Montag
    function cellDate(i) {
        var startOffset = (new Date(dialogWindow.shownYear, dialogWindow.shownMonth, 1).getDay() + 6) % 7;
        return new Date(dialogWindow.shownYear, dialogWindow.shownMonth, 1 - startOffset + i);
    }

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
            fPriority = dialogWindow.normalizePriority(t.priority || 0);
            fCompleted = !!t.completed;
            fListHref = t.listHref;
            fTags = (t.tags || []).slice();
            dialogWindow.showCalendar = false;
            dialogWindow.syncShownMonth();
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
        fTags = [];
        dialogWindow.showCalendar = false;
        dialogWindow.syncShownMonth();
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
            priority: fPriority,
            tags: dialogWindow.fTags,
            // Eine bestehende Teilaufgabe bleibt beim Bearbeiten eine
            // Teilaufgabe - ihre Eltern-Verknuepfung wird hier nicht
            // veraendert (dafuer gibt es im Dialog noch kein eigenes Feld).
            parentUid: dialogWindow.isEditing
                ? (dialogWindow.editingTask ? (dialogWindow.editingTask.parentUid || "") : "")
                : NextcloudTasksDAV.creatingParentUid
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

    // Hoehe des Beschreibungsfelds: Inhaltshoehe, mindestens 80, hoechstens
    // so viel, dass das Panel (530 + Beschreibung [+ 220 Kalender]) mit
    // 40px Rand noch auf den Bildschirm passt (und nie ueber 320).
    readonly property int descMinHeight: 80
    readonly property int descMaxHeight: Math.max(descMinHeight, Math.min(320,
        dialogWindow.height - 40 - 530 - (dialogWindow.fHasDueDate && dialogWindow.showCalendar ? 220 : 0)))
    readonly property int descHeight: Math.max(descMinHeight, Math.min(descMaxHeight, Math.ceil(descArea.implicitHeight)))

    // Klick-daneben-schliesst-Scrim
    MouseArea {
        anchors.fill: parent
        onClicked: NextcloudTasksDAV.closeDialog()
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 420
        height: 530 + dialogWindow.descHeight + (dialogWindow.fHasDueDate && dialogWindow.showCalendar ? 220 : 0)
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
                    text: dialogWindow.isEditing ? "Aufgabe bearbeiten" : (dialogWindow.isSubtaskCreate ? "Neue Teilaufgabe" : "Neue Aufgabe")
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

            Text {
                Layout.fillWidth: true
                visible: dialogWindow.isSubtaskCreate && dialogWindow.creatingParent !== null
                text: "Teilaufgabe von: " + (dialogWindow.creatingParent ? dialogWindow.creatingParent.title : "")
                color: "#a6adc8"
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                visible: NextcloudTasksDAV.taskLists.length > 1
                Text { text: "Liste"; color: "#a6adc8"; font.pixelSize: 11 }
                ComboBox {
                    Layout.fillWidth: true
                    // Eine Aufgabe wird hier nicht zwischen Listen verschoben,
                    // nur bearbeitet oder geloescht - analog zu EventDialog.
                    enabled: !dialogWindow.isEditing && !dialogWindow.isSubtaskCreate
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

            // Beschreibung: waechst mit dem Inhalt (Minimum descMinHeight);
            // ab descMaxHeight (begrenzt durch die Bildschirmhoehe) scrollt
            // das Feld stattdessen.
            ScrollView {
                id: descScroll
                Layout.fillWidth: true
                Layout.preferredHeight: dialogWindow.descHeight
                clip: true

                TextArea {
                    id: descArea
                    placeholderText: "Beschreibung"
                    text: dialogWindow.fDescription
                    onTextChanged: dialogWindow.fDescription = text
                    wrapMode: TextArea.Wrap
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Fälligkeit"; color: "#a6adc8"; font.pixelSize: 11 }
                    Text {
                        visible: dialogWindow.fHasDueDate && dialogWindow.fDueDate.length === 10
                        text: dialogWindow.fHasDueDate && dialogWindow.fDueDate.length === 10
                            ? Qt.formatDate(new Date(dialogWindow.fDueDate + "T00:00:00"), "ddd, dd.MM.yyyy")
                            : ""
                        color: "#cdd6f4"
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                }

                // Schnellwahl wie in der App
                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "Kein Datum",   kind: "none" },
                            { label: "Heute",        kind: "day", days: 0 },
                            { label: "Morgen",       kind: "day", days: 1 },
                            { label: "Übermorgen",   kind: "day", days: 2 },
                            { label: "Nächste Woche", kind: "day", days: 7 },
                            { label: "Datum wählen…", kind: "pick" }
                        ]

                        Rectangle {
                            readonly property bool active: modelData.kind === "none"
                                ? !dialogWindow.fHasDueDate
                                : (modelData.kind === "day"
                                    ? (dialogWindow.fHasDueDate && dialogWindow.fDueDate === dialogWindow.offsetDateStr(modelData.days))
                                    : dialogWindow.showCalendar)
                            height: 24
                            width: chipLabel.implicitWidth + 18
                            radius: 12
                            color: active ? "#89b4fa" : "#313244"

                            Text {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                color: parent.active ? "#1e1e2e" : "#cdd6f4"
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.kind === "none") dialogWindow.clearDue();
                                    else if (modelData.kind === "day") dialogWindow.setDue(dialogWindow.offsetDateStr(modelData.days));
                                    else {
                                        if (!dialogWindow.fHasDueDate) dialogWindow.setDue(dialogWindow.todayStr());
                                        dialogWindow.showCalendar = !dialogWindow.showCalendar;
                                    }
                                }
                            }
                        }
                    }
                }

                // Monatskalender
                Rectangle {
                    Layout.fillWidth: true
                    visible: dialogWindow.fHasDueDate && dialogWindow.showCalendar
                    implicitHeight: calColumn.implicitHeight + 16
                    radius: 8
                    color: "#181825"
                    border.color: "#313244"
                    border.width: 1

                    ColumnLayout {
                        id: calColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "‹"
                                color: "#89b4fa"
                                font.pixelSize: 18
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: dialogWindow.shiftMonth(-1) }
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: dialogWindow.monthNames[dialogWindow.shownMonth] + " " + dialogWindow.shownYear
                                color: "#cdd6f4"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                text: "›"
                                color: "#89b4fa"
                                font.pixelSize: 18
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: dialogWindow.shiftMonth(1) }
                            }
                        }

                        Grid {
                            Layout.alignment: Qt.AlignHCenter
                            columns: 7
                            rowSpacing: 2
                            columnSpacing: 2

                            Repeater {
                                model: dialogWindow.weekdayNames
                                Item {
                                    width: 34; height: 18
                                    Text { anchors.centerIn: parent; text: modelData; color: "#6c7086"; font.pixelSize: 10 }
                                }
                            }

                            Repeater {
                                model: 42
                                Rectangle {
                                    readonly property var cellD: dialogWindow.cellDate(index)
                                    readonly property string cellStr: dialogWindow.dateToStr(cellD)
                                    readonly property bool inMonth: cellD.getMonth() === dialogWindow.shownMonth
                                    readonly property bool selected: dialogWindow.fHasDueDate && dialogWindow.fDueDate === cellStr
                                    readonly property bool isToday: cellStr === dialogWindow.todayStr()
                                    width: 34; height: 24
                                    radius: 12
                                    color: selected ? "#89b4fa" : "transparent"
                                    border.width: (isToday && !selected) ? 1 : 0
                                    border.color: "#89b4fa"

                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.cellD.getDate()
                                        color: parent.selected ? "#1e1e2e" : (parent.inMonth ? "#cdd6f4" : "#45475a")
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dialogWindow.setDue(parent.cellStr)
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: dialogWindow.fHasDueDate
                    spacing: 8
                    Text { text: "Uhrzeit"; color: "#a6adc8"; font.pixelSize: 11 }
                    Switch { checked: dialogWindow.fHasDueTime; onCheckedChanged: dialogWindow.fHasDueTime = checked }
                    TextField {
                        Layout.preferredWidth: 80
                        visible: dialogWindow.fHasDueTime
                        text: dialogWindow.fDueTime
                        onTextChanged: dialogWindow.fDueTime = text
                        placeholderText: "HH:MM"
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Priorität"; color: "#a6adc8"; font.pixelSize: 11 }
                Row {
                    spacing: 14

                    Repeater {
                        model: dialogWindow.priorityOptions

                        RadioButton {
                            id: prioRadio
                            checked: dialogWindow.fPriority === modelData.value
                            onClicked: dialogWindow.fPriority = modelData.value
                            padding: 0
                            spacing: 6

                            indicator: Rectangle {
                                implicitWidth: 18
                                implicitHeight: 18
                                x: 0
                                y: (prioRadio.height - height) / 2
                                radius: 9
                                color: "transparent"
                                border.width: 2
                                border.color: modelData.color

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: modelData.color
                                    visible: prioRadio.checked
                                }
                            }

                            contentItem: Text {
                                leftPadding: 24
                                text: modelData.label
                                color: prioRadio.checked ? "#cdd6f4" : "#a6adc8"
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text { text: "Schlagwörter"; color: "#a6adc8"; font.pixelSize: 11 }

                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: dialogWindow.fTags.length > 0

                    Repeater {
                        model: dialogWindow.fTags
                        Rectangle {
                            height: 22
                            width: chipRow.implicitWidth + 14
                            radius: 11
                            color: "#313244"

                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: modelData; color: "#cdd6f4"; font.pixelSize: 11 }
                                Text {
                                    text: "✕"
                                    color: "#a6adc8"
                                    font.pixelSize: 10
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dialogWindow.removeTag(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Editierbarer Dropdown: bekanntes Schlagwort auswaehlen
                    // ODER einfach ein neues eintippen (Enter / "Hinzufuegen").
                    ComboBox {
                        id: tagBox
                        Layout.fillWidth: true
                        editable: true
                        model: dialogWindow.availableTags
                        currentIndex: -1
                        editText: ""
                        onAccepted: {
                            dialogWindow.addTag(tagBox.editText);
                            tagBox.editText = "";
                            tagBox.currentIndex = -1;
                        }
                        onActivated: index => {
                            dialogWindow.addTag(tagBox.textAt(index));
                            tagBox.editText = "";
                            tagBox.currentIndex = -1;
                        }
                    }

                    Button {
                        text: "Hinzufügen"
                        enabled: tagBox.editText.trim().length > 0
                        onClicked: {
                            dialogWindow.addTag(tagBox.editText);
                            tagBox.editText = "";
                            tagBox.currentIndex = -1;
                        }
                    }
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
