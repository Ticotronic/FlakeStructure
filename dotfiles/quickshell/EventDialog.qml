import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: dialogWindow
    required property var modelData
    screen: modelData

    visible: CalendarEvents.dialogVisible && CalendarEvents.activeScreen === modelData
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusiveZone: -1

    // ==========================================
    // Formularfelder
    // ==========================================
    property string fTitle: ""
    property bool fAllDay: false
    property string fStartDate: ""
    property string fStartTime: "09:00"
    property string fEndDate: ""
    property string fEndTime: "10:00"
    property string fLocation: ""
    property string fDescription: ""
    property int fReminder: 15        // Minuten vorher, -1 = keine
    property string fRepeat: "none"   // none/daily/weekly/monthly/yearly
    property string fColor: "#89b4fa"

    readonly property var colorChoices: ["#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#94e2d5", "#89b4fa", "#cba6f7", "#f5c2e7"]
    readonly property var reminderOptions: [
        { label: "Keine", value: -1 },
        { label: "5 Min", value: 5 },
        { label: "10 Min", value: 10 },
        { label: "15 Min", value: 15 },
        { label: "30 Min", value: 30 },
        { label: "1 Std", value: 60 },
        { label: "1 Tag", value: 1440 }
    ]
    readonly property var repeatOptions: [
        { label: "Nie", value: "none" },
        { label: "Täglich", value: "daily" },
        { label: "Wöchentlich", value: "weekly" },
        { label: "Monatlich", value: "monthly" },
        { label: "Jährlich", value: "yearly" }
    ]

    readonly property var existingEventsForDate: CalendarEvents.eventsForDate(fStartDate)

    function resetForm() {
        var isEditing = CalendarEvents.editingEventId !== "";
        if (isEditing) {
            var list = CalendarEvents.events;
            for (var i = 0; i < list.length; i++) {
                if (list[i].id === CalendarEvents.editingEventId) {
                    var e = list[i];
                    fTitle = e.title;
                    fAllDay = e.allDay;
                    fStartDate = e.startDate;
                    fStartTime = e.startTime || "09:00";
                    fEndDate = e.endDate;
                    fEndTime = e.endTime || "10:00";
                    fLocation = e.location;
                    fDescription = e.description;
                    fReminder = e.reminder;
                    fRepeat = e.repeat;
                    fColor = e.color;
                    return;
                }
            }
        }
        // Neuer Termin
        fTitle = "";
        fAllDay = false;
        fStartDate = CalendarEvents.selectedDate;
        fStartTime = "09:00";
        fEndDate = CalendarEvents.selectedDate;
        fEndTime = "10:00";
        fLocation = "";
        fDescription = "";
        fReminder = 15;
        fRepeat = "none";
        fColor = "#89b4fa";
    }

    Connections {
        target: CalendarEvents
        function onDialogVisibleChanged() {
            if (CalendarEvents.dialogVisible) dialogWindow.resetForm();
        }
        function onEditingEventIdChanged() {
            if (CalendarEvents.dialogVisible) dialogWindow.resetForm();
        }
    }

    function save() {
        if (fTitle.trim() === "") return;
        var evt = {
            id: CalendarEvents.editingEventId !== "" ? CalendarEvents.editingEventId : CalendarEvents.newEventId(),
            title: fTitle,
            allDay: fAllDay,
            startDate: fStartDate,
            startTime: fAllDay ? "" : fStartTime,
            endDate: fEndDate,
            endTime: fAllDay ? "" : fEndTime,
            location: fLocation,
            description: fDescription,
            reminder: fReminder,
            repeat: fRepeat,
            color: fColor
        };
        if (CalendarEvents.editingEventId !== "") {
            CalendarEvents.updateEvent(evt.id, evt);
        } else {
            CalendarEvents.addEvent(evt);
        }
        CalendarEvents.closeDialog();
    }

    function remove() {
        if (CalendarEvents.editingEventId !== "") {
            CalendarEvents.deleteEvent(CalendarEvents.editingEventId);
        }
        CalendarEvents.closeDialog();
    }

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2ecc"

        MouseArea {
            anchors.fill: parent
            onClicked: CalendarEvents.closeDialog()
        }

        Rectangle {
            id: dialogBox
            width: 480
            height: Math.min(640, parent.height - 80)
            anchors.centerIn: parent
            radius: 14
            color: "#1e1e2e"
            border.color: "#313244"
            border.width: 1
            focus: true

            Keys.onEscapePressed: CalendarEvents.closeDialog()

            // Klicks im Dialog nicht an den Hintergrund durchreichen
            MouseArea {
                anchors.fill: parent
            }

            ScrollView {
                anchors.fill: parent
                anchors.margins: 20
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: dialogBox.width - 40
                    spacing: 14

                    // Kopfzeile
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: CalendarEvents.editingEventId !== "" ? "Termin bearbeiten" : "Neuer Termin"
                            color: "#cdd6f4"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Rectangle {
                            width: 24; height: 24; radius: 4
                            color: closeArea.containsMouse ? "#313244" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: "#6c7086"
                                font.pixelSize: 14
                            }
                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CalendarEvents.closeDialog()
                            }
                        }
                    }

                    // Bereits vorhandene Termine an diesem Tag
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: dialogWindow.existingEventsForDate.length > 0

                        Text {
                            text: "Termine an diesem Tag"
                            color: "#6c7086"
                            font.pixelSize: 11
                        }

                        Repeater {
                            model: dialogWindow.existingEventsForDate
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 6
                                color: "#313244"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: modelData.color
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        color: "#cdd6f4"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: "Bearbeiten"
                                        color: "#89b4fa"
                                        font.pixelSize: 11
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: CalendarEvents.openForEdit(modelData.id, dialogWindow.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#313244"; Layout.topMargin: 4 }
                    }

                    // Titel
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Titel"; color: "#6c7086"; font.pixelSize: 11 }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 6
                            color: "#313244"
                            border.color: titleInput.activeFocus ? "#89b4fa" : "transparent"
                            border.width: 1
                            TextInput {
                                id: titleInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#cdd6f4"
                                font.pixelSize: 13
                                text: dialogWindow.fTitle
                                onTextChanged: dialogWindow.fTitle = text
                            }
                        }
                    }

                    // Ganztägig (eigener Toggle statt nativem Switch)
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Ganztägig"; color: "#cdd6f4"; font.pixelSize: 13; Layout.fillWidth: true }

                        Rectangle {
                            id: allDayToggle
                            width: 40; height: 22; radius: 11
                            color: dialogWindow.fAllDay ? "#a6e3a1" : "#313244"
                            border.color: "#45475a"
                            border.width: dialogWindow.fAllDay ? 0 : 1

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                color: "#1e1e2e"
                                anchors.verticalCenter: parent.verticalCenter
                                x: dialogWindow.fAllDay ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dialogWindow.fAllDay = !dialogWindow.fAllDay
                            }
                        }
                    }

                    // Von
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text { text: "Von (JJJJ-MM-TT)"; color: "#6c7086"; font.pixelSize: 11 }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 6
                                color: "#313244"
                                border.color: startDateInput.activeFocus ? "#89b4fa" : "transparent"
                                border.width: 1
                                TextInput {
                                    id: startDateInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: "#cdd6f4"
                                    font.pixelSize: 13
                                    text: dialogWindow.fStartDate
                                    onTextChanged: dialogWindow.fStartDate = text
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.preferredWidth: 90
                            spacing: 4
                            visible: !dialogWindow.fAllDay
                            Text { text: "Uhrzeit"; color: "#6c7086"; font.pixelSize: 11 }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 6
                                color: "#313244"
                                border.color: startTimeInput.activeFocus ? "#89b4fa" : "transparent"
                                border.width: 1
                                TextInput {
                                    id: startTimeInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: "#cdd6f4"
                                    font.pixelSize: 13
                                    text: dialogWindow.fStartTime
                                    onTextChanged: dialogWindow.fStartTime = text
                                }
                            }
                        }
                    }

                    // Bis
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text { text: "Bis (JJJJ-MM-TT)"; color: "#6c7086"; font.pixelSize: 11 }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 6
                                color: "#313244"
                                border.color: endDateInput.activeFocus ? "#89b4fa" : "transparent"
                                border.width: 1
                                TextInput {
                                    id: endDateInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: "#cdd6f4"
                                    font.pixelSize: 13
                                    text: dialogWindow.fEndDate
                                    onTextChanged: dialogWindow.fEndDate = text
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.preferredWidth: 90
                            spacing: 4
                            visible: !dialogWindow.fAllDay
                            Text { text: "Uhrzeit"; color: "#6c7086"; font.pixelSize: 11 }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 6
                                color: "#313244"
                                border.color: endTimeInput.activeFocus ? "#89b4fa" : "transparent"
                                border.width: 1
                                TextInput {
                                    id: endTimeInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: "#cdd6f4"
                                    font.pixelSize: 13
                                    text: dialogWindow.fEndTime
                                    onTextChanged: dialogWindow.fEndTime = text
                                }
                            }
                        }
                    }

                    // Ort
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Ort"; color: "#6c7086"; font.pixelSize: 11 }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 6
                            color: "#313244"
                            border.color: locationInput.activeFocus ? "#89b4fa" : "transparent"
                            border.width: 1
                            TextInput {
                                id: locationInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#cdd6f4"
                                font.pixelSize: 13
                                text: dialogWindow.fLocation
                                onTextChanged: dialogWindow.fLocation = text
                            }
                        }
                    }

                    // Beschreibung
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Beschreibung"; color: "#6c7086"; font.pixelSize: 11 }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 70
                            radius: 6
                            color: "#313244"
                            border.color: descArea.activeFocus ? "#89b4fa" : "transparent"
                            border.width: 1
                            TextEdit {
                                id: descArea
                                anchors.fill: parent
                                anchors.margins: 8
                                color: "#cdd6f4"
                                font.pixelSize: 13
                                wrapMode: TextEdit.Wrap
                                text: dialogWindow.fDescription
                                onTextChanged: dialogWindow.fDescription = text
                            }
                        }
                    }

                    // Erinnerung (Pill-Buttons statt ComboBox)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Erinnerung"; color: "#6c7086"; font.pixelSize: 11 }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: dialogWindow.reminderOptions
                                delegate: Rectangle {
                                    height: 26
                                    width: pillText.implicitWidth + 16
                                    radius: 13
                                    color: dialogWindow.fReminder === modelData.value ? "#89b4fa" : "#313244"
                                    Text {
                                        id: pillText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: dialogWindow.fReminder === modelData.value ? "#1e1e2e" : "#cdd6f4"
                                        font.pixelSize: 11
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dialogWindow.fReminder = modelData.value
                                    }
                                }
                            }
                        }
                    }

                    // Wiederholung (Pill-Buttons statt ComboBox)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Wiederholung"; color: "#6c7086"; font.pixelSize: 11 }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: dialogWindow.repeatOptions
                                delegate: Rectangle {
                                    height: 26
                                    width: repeatText.implicitWidth + 16
                                    radius: 13
                                    color: dialogWindow.fRepeat === modelData.value ? "#89b4fa" : "#313244"
                                    Text {
                                        id: repeatText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: dialogWindow.fRepeat === modelData.value ? "#1e1e2e" : "#cdd6f4"
                                        font.pixelSize: 11
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dialogWindow.fRepeat = modelData.value
                                    }
                                }
                            }
                        }
                    }

                    // Farbe
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Farbe"; color: "#6c7086"; font.pixelSize: 11 }
                        Row {
                            spacing: 8
                            Repeater {
                                model: dialogWindow.colorChoices
                                delegate: Rectangle {
                                    width: 24; height: 24; radius: 12
                                    color: modelData
                                    border.width: dialogWindow.fColor === modelData ? 2 : 0
                                    border.color: "#cdd6f4"
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dialogWindow.fColor = modelData
                                    }
                                }
                            }
                        }
                    }

                    // Buttons
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 90
                            Layout.preferredHeight: 36
                            radius: 6
                            color: "#313244"
                            visible: CalendarEvents.editingEventId !== ""
                            Text { anchors.centerIn: parent; text: "Löschen"; color: "#f38ba8"; font.pixelSize: 12 }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dialogWindow.remove()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: 90
                            Layout.preferredHeight: 36
                            radius: 6
                            color: "#313244"
                            Text { anchors.centerIn: parent; text: "Abbrechen"; color: "#cdd6f4"; font.pixelSize: 12 }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CalendarEvents.closeDialog()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 90
                            Layout.preferredHeight: 36
                            radius: 6
                            color: "#a6e3a1"
                            Text { anchors.centerIn: parent; text: "Speichern"; color: "#11111b"; font.pixelSize: 12; font.bold: true }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dialogWindow.save()
                            }
                        }
                    }
                }
            }
        }
    }
}
