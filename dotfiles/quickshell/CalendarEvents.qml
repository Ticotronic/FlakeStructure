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
