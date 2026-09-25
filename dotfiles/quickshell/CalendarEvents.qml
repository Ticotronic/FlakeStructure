pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: calendarEvents

    // ==========================================
    // Persistente Speicherung der Termine
    // JsonAdapter liest UND schreibt die Datei automatisch
    // ==========================================
    FileView {
        id: eventsFile
        path: Qt.resolvedUrl("/home/roljon/calendar-events.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            property var events: []
        }
    }

    readonly property var events: eventsFile.adapter ? eventsFile.adapter.events : []

    function addEvent(evt) {
        var list = eventsFile.adapter.events.slice();
        list.push(evt);
        eventsFile.adapter.events = list;
    }

    function updateEvent(id, updatedEvt) {
        var list = eventsFile.adapter.events.slice();
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                list[i] = updatedEvt;
                break;
            }
        }
        eventsFile.adapter.events = list;
    }

    function deleteEvent(id) {
        eventsFile.adapter.events = eventsFile.adapter.events.filter(function(e) {
            return e.id !== id;
        });
    }

    // Alle Termine, die an diesem Datum (yyyy-MM-dd) aktiv sind
    function eventsForDate(dateKey) {
        var list = eventsFile.adapter ? eventsFile.adapter.events : [];
        var result = [];
        for (var i = 0; i < list.length; i++) {
            if (list[i].startDate <= dateKey && list[i].endDate >= dateKey) {
                result.push(list[i]);
            }
        }
        return result;
    }

    // Schnelles Lookup für Marker im Kalendergrid: { "2026-09-24": true, ... }
    readonly property var datesWithEvents: {
        var set = {};
        var list = eventsFile.adapter ? eventsFile.adapter.events : [];
        for (var i = 0; i < list.length; i++) {
            set[list[i].startDate] = true;
        }
        return set;
    }

    function newEventId() {
        return Date.now() + "-" + Math.floor(Math.random() * 100000);
    }

    // ==========================================
    // Erinnerungen: periodische Prüfung + Signal
    // ==========================================
    property var firedReminders: ({})  // { eventId: true } – nur für diese Session

    signal reminderFired(var evt)

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: calendarEvents.checkReminders()
    }

    function checkReminders() {
        var now = new Date();
        var list = eventsFile.adapter ? eventsFile.adapter.events : [];
        for (var i = 0; i < list.length; i++) {
            var e = list[i];
            if (e.allDay) continue;
            if (e.reminder === undefined || e.reminder === null || e.reminder < 0) continue;
            if (firedReminders[e.id]) continue;

            var startDate = new Date(e.startDate + "T" + (e.startTime || "00:00") + ":00");
            if (isNaN(startDate.getTime())) continue;

            var triggerTime = new Date(startDate.getTime() - e.reminder * 60000);
            if (now >= triggerTime && now <= startDate) {
                firedReminders[e.id] = true;
                reminderFired(e);
            }
        }
    }

    // ==========================================
    // Dialog-Zustand (Erstellen/Bearbeiten)
    // ==========================================
    property bool dialogVisible: false
    property var activeScreen: null
    property string selectedDate: ""    // "yyyy-MM-dd"
    property string editingEventId: ""  // leer = neuer Termin

    function openForDate(dateKey, screen) {
        selectedDate = dateKey;
        editingEventId = "";
        activeScreen = screen;
        dialogVisible = true;
    }

    function openForEdit(eventId, screen) {
        var list = eventsFile.adapter.events;
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === eventId) {
                selectedDate = list[i].startDate;
                break;
            }
        }
        editingEventId = eventId;
        activeScreen = screen;
        dialogVisible = true;
    }

    function closeDialog() {
        dialogVisible = false;
        activeScreen = null;
    }
}
