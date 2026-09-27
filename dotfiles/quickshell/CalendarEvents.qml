pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Local event store (JSON on disk, outside the read-only Nix-store-symlinked
// config tree) merged together with read-only events fetched from Nextcloud
// via CalDAV (NextcloudCalDAV.qml). Also owns the reminder-toast trigger
// logic and the EventDialog open/close state shared across all screens.
Singleton {
    id: calendarEvents

    // ---- Local persistence --------------------------------------------

    FileView {
        id: eventsFile
        // Deliberately OUTSIDE dotfiles/quickshell, which is a read-only
        // Nix-store symlink at runtime (xdg.configFile."quickshell".source).
        path: Qt.resolvedUrl("/home/roljon/calendar-events.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        adapter: JsonAdapter {
            property var events: []
        }
    }

    readonly property var events: eventsFile.adapter ? eventsFile.adapter.events : []

    // ---- Merge local + remote (Nextcloud) ------------------------------

    readonly property var mergedEvents: {
        var local = eventsFile.adapter ? eventsFile.adapter.events : [];
        var remote = NextcloudCalDAV.remoteEvents;
        var combined = [];
        for (var i = 0; i < local.length; i++) {
            var e = Object.assign({}, local[i]);
            e.source = "local";
            combined.push(e);
        }
        for (var j = 0; j < remote.length; j++) {
            combined.push(remote[j]);
        }
        return combined;
    }

    // ---- CRUD (local events only) --------------------------------------

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
        var list = eventsFile.adapter.events.filter(function (e) { return e.id !== id; });
        eventsFile.adapter.events = list;
    }

    function newEventId() {
        return Date.now() + "-" + Math.floor(Math.random() * 100000);
    }

    // ---- Queries used by ClockWidget's calendar grid -------------------

    function eventsForDate(dateKey) {
        var result = [];
        var list = calendarEvents.mergedEvents;
        for (var i = 0; i < list.length; i++) {
            var e = list[i];
            if (e.startDate <= dateKey && dateKey <= e.endDate) {
                result.push(e);
            }
        }
        return result;
    }

    readonly property var datesWithEvents: {
        var set = {};
        var list = calendarEvents.mergedEvents;
        for (var i = 0; i < list.length; i++) {
            set[list[i].startDate] = true;
        }
        return set;
    }

    // ---- Reminders (local events only; all-day events have no reminder) --

    property var firedReminders: ({})
    signal reminderFired(var evt)

    Timer {
        interval: 30000
        repeat: true
        running: true
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
            if (calendarEvents.firedReminders[e.id]) continue;

            var startDate = new Date(e.startDate + "T" + (e.startTime || "00:00") + ":00");
            var triggerTime = new Date(startDate.getTime() - e.reminder * 60000);

            if (now >= triggerTime && now <= startDate) {
                calendarEvents.firedReminders[e.id] = true;
                calendarEvents.reminderFired(e);
            }
        }
    }

    // ---- EventDialog open/close state (shared across per-screen dialogs) -

    property bool dialogVisible: false
    property var activeScreen: null
    property string selectedDate: ""
    property string editingEventId: ""

    function openForDate(dateKey, screen) {
        selectedDate = dateKey;
        editingEventId = "";
        activeScreen = screen;
        dialogVisible = true;
    }

    function openForEdit(eventId, screen) {
        editingEventId = eventId;
        activeScreen = screen;
        dialogVisible = true;
    }

    function closeDialog() {
        dialogVisible = false;
        activeScreen = null;
    }
}
