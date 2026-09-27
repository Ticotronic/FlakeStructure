import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

// One instance per screen (via Variants in shell.qml), visible only on the
// screen that CalendarEvents.activeScreen currently points to.
PanelWindow {
    id: dialogWindow
    required property var modelData
    screen: modelData

    visible: CalendarEvents.dialogVisible && CalendarEvents.activeScreen === modelData

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusiveZone: -1
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }

    readonly property var colorChoices: [
        "#f38ba8", "#fab387", "#f9e2af", "#a6e3a1",
        "#74c7ec", "#89b4fa", "#cba6f7", "#f5c2e7"
    ]

    readonly property var reminderOptions: [
        { label: "Keine", value: -1 },
        { label: "Zur Startzeit", value: 0 },
        { label: "5 Min. vorher", value: 5 },
        { label: "15 Min. vorher", value: 15 },
        { label: "30 Min. vorher", value: 30 },
        { label: "1 Std. vorher", value: 60 },
        { label: "1 Tag vorher", value: 1440 }
    ]

    readonly property var repeatOptions: [
        { label: "Keine", value: "none" },
        { label: "Täglich", value: "daily" },
        { label: "Wöchentlich", value: "weekly" },
        { label: "Monatlich", value: "monthly" },
        { label: "Jährlich", value: "yearly" }
    ]

    property string fTitle: ""
    property bool fAllDay: false
    property string fStartDate: ""
    property string fStartTime: "09:00"
    property string fEndDate: ""
    property string fEndTime: "10:00"
    property string fLocation: ""
    property string fDescription: ""
    property int fReminder: -1
    property string fRepeat: "none"
    property string fColor: colorChoices[0]

    readonly property var existingEvents: CalendarEvents.eventsForDate(CalendarEvents.selectedDate)
    readonly property bool isEditing: CalendarEvents.editingEventId !== ""

    function resetForm() {
        if (isEditing) {
            var evt = null;
            for (var i = 0; i < existingEvents.length; i++) {
                if (existingEvents[i].id === CalendarEvents.editingEventId) { evt = existingEvents[i]; break; }
            }
            if (evt) {
                fTitle = evt.title;
                fAllDay = evt.allDay;
                fStartDate = evt.startDate;
                fStartTime = evt.startTime || "09:00";
                fEndDate = evt.endDate;
                fEndTime = evt.endTime || "10:00";
                fLocation = evt.location || "";
                fDescription = evt.description || "";
                fReminder = evt.reminder !== undefined ? evt.reminder : -1;
                fRepeat = evt.repeat || "none";
                fColor = evt.color || colorChoices[0];
                return;
            }
        }
        fTitle = "";
        fAllDay = false;
        fStartDate = CalendarEvents.selectedDate;
        fStartTime = "09:00";
        fEndDate = CalendarEvents.selectedDate;
        fEndTime = "10:00";
        fLocation = "";
        fDescription = "";
        fReminder = -1;
        fRepeat = "none";
        fColor = colorChoices[0];
    }

    onVisibleChanged: if (visible) resetForm()

    function save() {
        var evt = {
            id: isEditing ? CalendarEvents.editingEventId : CalendarEvents.newEventId(),
            title: fTitle.length > 0 ? fTitle : "(ohne Titel)",
            allDay: fAllDay,
            startDate: fStartDate,
            startTime: fAllDay ? "" : fStartTime,
            endDate: fEndDate,
            endTime: fAllDay ? "" : fEndTime,
            location: fLocation,
            description: fDescription,
            reminder: fAllDay ? -1 : fReminder,
            repeat: fRepeat,
            color: fColor
        };
        if (isEditing) {
            CalendarEvents.updateEvent(evt.id, evt);
        } else {
            CalendarEvents.addEvent(evt);
        }
        CalendarEvents.closeDialog();
    }

    function remove() {
        if (isEditing) CalendarEvents.deleteEvent(CalendarEvents.editingEventId);
        CalendarEvents.closeDialog();
    }

    // Click-outside-to-close scrim
    MouseArea {
        anchors.fill: parent
        onClicked: CalendarEvents.closeDialog()
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 480
        height: 620
        color: "#1e1e2e"
        border.color: "#313244"
        border.width: 1
        radius: 10

        focus: true
        Keys.onEscapePressed: CalendarEvents.closeDialog()

        MouseArea {
            anchors.fill: parent
            onClicked: {} // swallow clicks so the scrim doesn't close the dialog
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: dialogWindow.isEditing ? "Termin bearbeiten" : "Neuer Termin"
                    color: "#cdd6f4"
                    font.pixelSize: 18
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    text: "✕"
                    color: "#a6adc8"
                    font.pixelSize: 16
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: CalendarEvents.closeDialog() }
                }
            }

            TextField {
                Layout.fillWidth: true
                placeholderText: "Titel"
                text: dialogWindow.fTitle
                onTextChanged: dialogWindow.fTitle = text
            }

            RowLayout {
                Text { text: "Ganztägig"; color: "#cdd6f4" }
                Switch { checked: dialogWindow.fAllDay; onCheckedChanged: dialogWindow.fAllDay = checked }
                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { text: "Start"; color: "#a6adc8"; font.pixelSize: 11 }
                    TextField { Layout.fillWidth: true; text: dialogWindow.fStartDate; onTextChanged: dialogWindow.fStartDate = text; placeholderText: "YYYY-MM-DD" }
                    TextField { Layout.fillWidth: true; visible: !dialogWindow.fAllDay; text: dialogWindow.fStartTime; onTextChanged: dialogWindow.fStartTime = text; placeholderText: "HH:MM" }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { text: "Ende"; color: "#a6adc8"; font.pixelSize: 11 }
                    TextField { Layout.fillWidth: true; text: dialogWindow.fEndDate; onTextChanged: dialogWindow.fEndDate = text; placeholderText: "YYYY-MM-DD" }
                    TextField { Layout.fillWidth: true; visible: !dialogWindow.fAllDay; text: dialogWindow.fEndTime; onTextChanged: dialogWindow.fEndTime = text; placeholderText: "HH:MM" }
                }
            }

            TextField {
                Layout.fillWidth: true
                placeholderText: "Ort"
                text: dialogWindow.fLocation
                onTextChanged: dialogWindow.fLocation = text
            }

            TextArea {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                placeholderText: "Beschreibung"
                text: dialogWindow.fDescription
                onTextChanged: dialogWindow.fDescription = text
                wrapMode: TextArea.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Erinnerung"; color: "#a6adc8"; font.pixelSize: 11 }
                ComboBox {
                    Layout.fillWidth: true
                    enabled: !dialogWindow.fAllDay
                    model: dialogWindow.reminderOptions.map(function (o) { return o.label; })
                    currentIndex: {
                        for (var i = 0; i < dialogWindow.reminderOptions.length; i++)
                            if (dialogWindow.reminderOptions[i].value === dialogWindow.fReminder) return i;
                        return 0;
                    }
                    onActivated: index => dialogWindow.fReminder = dialogWindow.reminderOptions[index].value
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Wiederholung"; color: "#a6adc8"; font.pixelSize: 11 }
                ComboBox {
                    Layout.fillWidth: true
                    model: dialogWindow.repeatOptions.map(function (o) { return o.label; })
                    currentIndex: {
                        for (var i = 0; i < dialogWindow.repeatOptions.length; i++)
                            if (dialogWindow.repeatOptions[i].value === dialogWindow.fRepeat) return i;
                        return 0;
                    }
                    onActivated: index => dialogWindow.fRepeat = dialogWindow.repeatOptions[index].value
                }
            }

            Row {
                spacing: 6
                Repeater {
                    model: dialogWindow.colorChoices
                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: modelData
                        border.width: dialogWindow.fColor === modelData ? 2 : 0
                        border.color: "#ffffff"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dialogWindow.fColor = modelData }
                    }
                }
            }

            // Existing events on this day
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(80, dialogWindow.existingEvents.length * 26)
                visible: dialogWindow.existingEvents.length > 0
                model: dialogWindow.existingEvents
                delegate: RowLayout {
                    width: ListView.view.width
                    Rectangle { width: 8; height: 8; radius: 4; color: modelData.color || "#74c7ec" }
                    Text { text: modelData.title; color: "#cdd6f4"; Layout.fillWidth: true; elide: Text.ElideRight }
                    Text {
                        text: modelData.source === "nextcloud" ? "☁ Nextcloud" : "Bearbeiten"
                        color: modelData.source === "nextcloud" ? "#6c7086" : "#89b4fa"
                        MouseArea {
                            anchors.fill: parent
                            enabled: modelData.source !== "nextcloud"
                            cursorShape: modelData.source !== "nextcloud" ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: CalendarEvents.openForEdit(modelData.id, dialogWindow.modelData)
                        }
                    }
                }
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
                Button { text: "Abbrechen"; onClicked: CalendarEvents.closeDialog() }
                Button { text: "Speichern"; highlighted: true; onClicked: dialogWindow.save() }
            }
        }
    }
}
