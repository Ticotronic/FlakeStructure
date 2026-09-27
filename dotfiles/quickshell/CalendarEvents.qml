pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Local event store (JSON on disk, outside the read-only Nix-store-symlinked
// config tree) merged together with read-only events fetched from Nextcloud
// via CalDAV (NextcloudCalDAV.qml). Also owns the reminder-toast trigger
// logic and the EventDialog open/close state shared across all screens.
//
// Stufe 2: local events created/edited/deleted here are also pushed to
// Nextcloud via CalDAV PUT/DELETE (nextcloud-caldav-push), fire-and-forget.
// Nextcloud-native events (created directly in Nextcloud) stay read-only.
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
        // Events we pushed ourselves come back from the next Nextcloud
        // fetch with the same "local-<id>" UID. Filter those remote echoes
        // out so a self-authored event doesn't show up twice (once local/
        // yellow, once nextcloud/blue).
        var remote = NextcloudCalDAV.remoteEvents.filter(function (e) {
            return !(e.uid && e.uid.indexOf("local-") === 0);
        });
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

    // ---- CRUD (local events; also pushed to Nextcloud) -------------------

    function addEvent(evt) {
        var list = eventsFile.adapter.events.slice();
        list.push(evt);
        eventsFile.adapter.events = list;
        pushEventToNextcloud(evt);
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
        pushEventToNextcloud(updatedEvt);
    }

    function deleteEvent(id) {
        var list = eventsFile.adapter.events.filter(function (e) { return e.id !== id; });
        eventsFile.adapter.events = list;
        deleteEventFromNextcloud(id);
    }

    function newEventId() {
        return Date.now() + "-" + Math.floor(Math.random() * 100000);
    }

    // ---- Nextcloud push (Stufe 2, fire-and-forget) ------------------------

    function pushEventToNextcloud(evt) {
        var uid = "local-" + evt.id;
        var ics = calendarEvents.buildIcs(evt, uid);
        Quickshell.execDetached(["nextcloud-caldav-push", "put", uid, ics]);
    }

    function deleteEventFromNextcloud(id) {
        var uid = "local-" + id;
        Quickshell.execDetached(["nextcloud-caldav-push", "delete", uid, ""]);
    }

    function escapeIcsText(s) {
        return String(s)
            .replace(/\\/g, "\\\\")
            .replace(/;/g, "\\;")
            .replace(/,/g, "\\,")
            .replace(/\n/g, "\\n");
    }

    function pad2(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function nowIcsUtc() {
        var d = new Date();
        return d.getUTCFullYear() + pad2(d.getUTCMonth() + 1) + pad2(d.getUTCDate()) + "T" +
               pad2(d.getUTCHours()) + pad2(d.getUTCMinutes()) + pad2(d.getUTCSeconds()) + "Z";
    }

    function toIcsUtc(dateStr, timeStr) {
        // Interprets dateStr/timeStr as local wall-clock time (system tz),
        // then formats as UTC — avoids dealing with VTIMEZONE/TZID entirely.
        var d = new Date(dateStr + "T" + (timeStr || "00:00") + ":00");
        return d.getUTCFullYear() + pad2(d.getUTCMonth() + 1) + pad2(d.getUTCDate()) + "T" +
               pad2(d.getUTCHours()) + pad2(d.getUTCMinutes()) + "00Z";
    }

    function addDaysToDateStr(dateStr, days) {
        var parts = dateStr.split("-");
        var d = new Date(Date.UTC(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2])));
        d.setUTCDate(d.getUTCDate() + days);
        return d.getUTCFullYear() + "-" + pad2(d.getUTCMonth() + 1) + "-" + pad2(d.getUTCDate());
    }

    function buildIcs(evt, uid) {
        var lines = [];
        lines.push("BEGIN:VCALENDAR");
        lines.push("VERSION:2.0");
        lines.push("PRODID:-//quickshell//calendar//DE");
        lines.push("BEGIN:VEVENT");
        lines.push("UID:" + uid);
        lines.push("DTSTAMP:" + calendarEvents.nowIcsUtc());

        if (evt.allDay) {
            // DTEND is exclusive per RFC 5545, so add one day to the
            // (inclusive) local endDate.
            lines.push("DTSTART;VALUE=DATE:" + evt.startDate.replace(/-/g, ""));
            lines.push("DTEND;VALUE=DATE:" + calendarEvents.addDaysToDateStr(evt.endDate, 1).replace(/-/g, ""));
        } else {
            lines.push("DTSTART:" + calendarEvents.toIcsUtc(evt.startDate, evt.startTime));
            lines.push("DTEND:" + calendarEvents.toIcsUtc(evt.endDate, evt.endTime));
        }

        lines.push("SUMMARY:" + calendarEvents.escapeIcsText(evt.title));
        if (evt.location) lines.push("LOCATION:" + calendarEvents.escapeIcsText(evt.location));
        if (evt.description) lines.push("DESCRIPTION:" + calendarEvents.escapeIcsText(evt.description));

        if (evt.repeat && evt.repeat !== "none") {
            var freqMap = { daily: "DAILY", weekly: "WEEKLY", monthly: "MONTHLY", yearly: "YEARLY" };
            if (freqMap[evt.repeat]) lines.push("RRULE:FREQ=" + freqMap[evt.repeat]);
        }

        if (!evt.allDay && evt.reminder !== undefined && evt.reminder !== null && evt.reminder >= 0) {
            lines.push("BEGIN:VALARM");
            lines.push("ACTION:DISPLAY");
            lines.push("DESCRIPTION:Erinnerung");
            lines.push("TRIGGER:-PT" + evt.reminder + "M");
            lines.push("END:VALARM");
        }

        lines.push("END:VEVENT");
        lines.push("END:VCALENDAR");
        return lines.join("\r\n") + "\r\n";
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
