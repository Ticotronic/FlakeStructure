pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Read/write CalDAV client against the user's self-hosted Nextcloud.
// Fetches VEVENTs in a rolling window (-31 days .. +180 days) every 10
// minutes, parses the iCalendar response and exposes it as `remoteEvents`,
// which CalendarEvents.qml merges together with the local JSON-backed
// events. Also exposes patchRemoteEvent/removeRemoteEvent so an edit or
// delete of a Nextcloud-native event (done via nextcloud-caldav-push,
// triggered from CalendarEvents.qml) can be reflected in the UI
// immediately, ahead of the next real fetch confirming it server-side.
Singleton {
    id: nextcloudCalDAV

    property var remoteEvents: []
    property bool lastFetchFailed: false

    Timer {
        interval: 600000 // 10 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: nextcloudCalDAV.fetchNow()
    }

    function fetchNow() {
        if (!fetchProc.running) {
            fetchProc.rawBuffer = "";
            fetchProc.running = true;
        }
    }

    Process {
        id: fetchProc
        command: ["nextcloud-caldav-fetch"]
        property string rawBuffer: ""

        stdout: SplitParser {
            onRead: data => {
                fetchProc.rawBuffer += data + "\n";
            }
        }

        onExited: code => {
            if (code === 0 && fetchProc.rawBuffer.length > 0) {
                try {
                    var parsed = nextcloudCalDAV.parseResponse(fetchProc.rawBuffer);
                    nextcloudCalDAV.remoteEvents = parsed;
                    nextcloudCalDAV.lastFetchFailed = false;
                } catch (e) {
                    console.log("NextcloudCalDAV: parse error", e);
                    nextcloudCalDAV.lastFetchFailed = true;
                }
            } else {
                nextcloudCalDAV.lastFetchFailed = true;
            }
        }
    }

    // ---- Optimistic local patching (edit/delete round-trip via push) -----

    function patchRemoteEvent(uid, evt) {
        var list = nextcloudCalDAV.remoteEvents.slice();
        for (var i = 0; i < list.length; i++) {
            if (list[i].uid === uid) {
                list[i] = Object.assign({}, list[i], {
                    title: evt.title,
                    allDay: evt.allDay,
                    startDate: evt.startDate,
                    startTime: evt.startTime,
                    endDate: evt.endDate,
                    endTime: evt.endTime,
                    location: evt.location,
                    description: evt.description,
                    reminder: evt.reminder,
                    repeat: evt.repeat,
                    color: evt.color
                });
                nextcloudCalDAV.remoteEvents = list;
                return;
            }
        }
    }

    function removeRemoteEvent(uid) {
        nextcloudCalDAV.remoteEvents = nextcloudCalDAV.remoteEvents.filter(function (e) {
            return e.uid !== uid;
        });
    }

    // ---- XML / iCalendar helpers -------------------------------------

    // A CalDAV REPORT reply is a <d:multistatus> of <d:response> elements,
    // each pairing one <d:href> (the resource's real WebDAV path — NOT the
    // same thing as the iCalendar UID inside it) with one <c:calendar-data>.
    // We need both together per event: the href is what a PUT/DELETE must
    // target for anything we didn't create ourselves, since a foreign
    // client (e.g. Nextcloud's own web UI) picks its own resource name,
    // unrelated to the VEVENT's UID property.
    function extractResponseBlocks(xmlText) {
        var blocks = [];
        var re = /<(?:[a-zA-Z0-9]+:)?response[^>]*>([\s\S]*?)<\/(?:[a-zA-Z0-9]+:)?response>/gi;
        var match;
        while ((match = re.exec(xmlText)) !== null) {
            blocks.push(match[1]);
        }
        return blocks;
    }

    function extractHref(responseXml) {
        var m = responseXml.match(/<(?:[a-zA-Z0-9]+:)?href[^>]*>([\s\S]*?)<\/(?:[a-zA-Z0-9]+:)?href>/i);
        return m ? nextcloudCalDAV.unescapeXml(m[1]) : "";
    }

    function extractCalendarData(responseXml) {
        var m = responseXml.match(/<(?:[a-zA-Z0-9]+:)?calendar-data[^>]*>([\s\S]*?)<\/(?:[a-zA-Z0-9]+:)?calendar-data>/i);
        return m ? nextcloudCalDAV.unescapeXml(m[1]) : "";
    }

    function unescapeXml(s) {
        return s
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&#39;/g, "'")
            .replace(/&amp;/g, "&");
    }

    function unfoldIcs(icsText) {
        // RFC 5545: a line starting with a single space or tab is a
        // continuation of the previous line.
        var rawLines = icsText.split(/\r\n|\n|\r/);
        var lines = [];
        for (var i = 0; i < rawLines.length; i++) {
            var line = rawLines[i];
            if ((line.charAt(0) === " " || line.charAt(0) === "\t") && lines.length > 0) {
                lines[lines.length - 1] += line.substring(1);
            } else {
                lines.push(line);
            }
        }
        return lines;
    }

    function findIcsField(lines, fieldName) {
        // Matches "FIELD:value" or "FIELD;PARAM=x:value"
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            var colonIdx = line.indexOf(":");
            if (colonIdx === -1) continue;
            var head = line.substring(0, colonIdx);
            var headName = head.split(";")[0];
            if (headName.toUpperCase() === fieldName.toUpperCase()) {
                var params = {};
                var headParts = head.split(";");
                for (var p = 1; p < headParts.length; p++) {
                    var kv = headParts[p].split("=");
                    if (kv.length === 2) params[kv[0].toUpperCase()] = kv[1];
                }
                return { value: line.substring(colonIdx + 1), params: params };
            }
        }
        return null;
    }

    function pad2(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function addDaysToDateStr(dateStr, days) {
        var parts = dateStr.split("-");
        var d = new Date(Date.UTC(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2])));
        d.setUTCDate(d.getUTCDate() + days);
        return d.getUTCFullYear() + "-" + nextcloudCalDAV.pad2(d.getUTCMonth() + 1) + "-" + nextcloudCalDAV.pad2(d.getUTCDate());
    }

    function parseIcsDateTime(raw, params) {
        // raw examples: "20260415" (all-day, VALUE=DATE),
        // "20260415T090000" (floating local time),
        // "20260415T090000Z" (UTC)
        var isAllDay = params && params["VALUE"] === "DATE";
        if (isAllDay || raw.length === 8) {
            var y = raw.substring(0, 4);
            var m = raw.substring(4, 6);
            var d = raw.substring(6, 8);
            return { date: y + "-" + m + "-" + d, time: "", allDay: true };
        }
        var datePart = raw.substring(0, 8);
        var timePart = raw.substring(9, 15);
        var y2 = datePart.substring(0, 4);
        var m2 = datePart.substring(4, 6);
        var d2 = datePart.substring(6, 8);
        var hh = timePart.substring(0, 2);
        var mm = timePart.substring(2, 4);
        return { date: y2 + "-" + m2 + "-" + d2, time: hh + ":" + mm, allDay: false };
    }

    // ---- VALARM (reminder) parsing ----------------------------------

    function parseDurationToMinutes(dur) {
        // Examples: -PT15M, -PT1H, -PT1H30M, -P1D, PT0M.
        // Only handles the simple "before start" relative-duration form
        // our own buildIcs() writes (and that Nextcloud/most clients use);
        // an absolute DATE-TIME trigger or unparsable value falls back to -1.
        var m = String(dur).match(/^[+-]?P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/);
        if (!m) return -1;
        var days = parseInt(m[1] || "0");
        var hours = parseInt(m[2] || "0");
        var minutes = parseInt(m[3] || "0");
        return days * 1440 + hours * 60 + minutes;
    }

    function findValarmTriggerMinutes(evLines) {
        var inAlarm = false;
        for (var i = 0; i < evLines.length; i++) {
            var line = evLines[i].trim();
            if (line.toUpperCase() === "BEGIN:VALARM") { inAlarm = true; continue; }
            if (line.toUpperCase() === "END:VALARM") { inAlarm = false; continue; }
            if (inAlarm) {
                var colonIdx = line.indexOf(":");
                if (colonIdx === -1) continue;
                var head = line.substring(0, colonIdx).split(";")[0];
                if (head.toUpperCase() === "TRIGGER") {
                    return nextcloudCalDAV.parseDurationToMinutes(line.substring(colonIdx + 1));
                }
            }
        }
        return -1;
    }

    function parseResponse(xmlText) {
        var events = [];
        var responseBlocks = nextcloudCalDAV.extractResponseBlocks(xmlText);

        for (var b = 0; b < responseBlocks.length; b++) {
            var href = nextcloudCalDAV.extractHref(responseBlocks[b]);
            var calData = nextcloudCalDAV.extractCalendarData(responseBlocks[b]);
            if (!calData) continue;

            var lines = nextcloudCalDAV.unfoldIcs(calData);

            // A single calendar-data block can contain several VEVENTs
            // (e.g. recurring exceptions). Split into VEVENT sections.
            var eventBlocks = [];
            var current = null;
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].trim().toUpperCase() === "BEGIN:VEVENT") {
                    current = [];
                } else if (lines[i].trim().toUpperCase() === "END:VEVENT") {
                    if (current) eventBlocks.push(current);
                    current = null;
                } else if (current) {
                    current.push(lines[i]);
                }
            }

            for (var e = 0; e < eventBlocks.length; e++) {
                var evLines = eventBlocks[e];

                var uidField = nextcloudCalDAV.findIcsField(evLines, "UID");
                var summaryField = nextcloudCalDAV.findIcsField(evLines, "SUMMARY");
                var locationField = nextcloudCalDAV.findIcsField(evLines, "LOCATION");
                var descriptionField = nextcloudCalDAV.findIcsField(evLines, "DESCRIPTION");
                var dtstartField = nextcloudCalDAV.findIcsField(evLines, "DTSTART");
                var dtendField = nextcloudCalDAV.findIcsField(evLines, "DTEND");
                var rruleField = nextcloudCalDAV.findIcsField(evLines, "RRULE");

                if (!uidField || !dtstartField) continue;

                var startInfo = nextcloudCalDAV.parseIcsDateTime(dtstartField.value, dtstartField.params);
                var endInfo = dtendField
                    ? nextcloudCalDAV.parseIcsDateTime(dtendField.value, dtendField.params)
                    : startInfo;

                // RFC 5545: DTEND on an all-day event is EXCLUSIVE (the day
                // AFTER the event actually ends). Our own model treats
                // endDate as INCLUSIVE (the last day it covers) — buildIcs()
                // already adds a day going out to Nextcloud, so mirror that
                // coming back in. Without this, a Nextcloud-created one-day
                // all-day event (DTSTART=28th, DTEND=29th) shows as spanning
                // both the 28th and 29th.
                if (startInfo.allDay && dtendField) {
                    endInfo = {
                        date: nextcloudCalDAV.addDaysToDateStr(endInfo.date, -1),
                        time: "",
                        allDay: true
                    };
                }

                var repeatValue = "none";
                if (rruleField) {
                    var freqMatch = rruleField.value.match(/FREQ=([A-Z]+)/);
                    if (freqMatch) {
                        var freqLower = freqMatch[1].toLowerCase();
                        // Only our own simple FREQ-only values round-trip cleanly;
                        // anything more complex (BYDAY, INTERVAL, COUNT, ...) is
                        // reported as its base frequency, not fully reconstructed.
                        if (["daily", "weekly", "monthly", "yearly"].indexOf(freqLower) !== -1) {
                            repeatValue = freqLower;
                        }
                    }
                }

                events.push({
                    id: "nc-" + uidField.value,
                    uid: uidField.value,
                    href: href,
                    title: summaryField ? summaryField.value : "(ohne Titel)",
                    allDay: startInfo.allDay,
                    startDate: startInfo.date,
                    startTime: startInfo.time,
                    endDate: endInfo.date,
                    endTime: endInfo.time,
                    location: locationField ? locationField.value : "",
                    description: descriptionField ? descriptionField.value : "",
                    reminder: nextcloudCalDAV.findValarmTriggerMinutes(evLines),
                    repeat: repeatValue,
                    color: "#74c7ec",
                    source: "nextcloud"
                });
            }
        }

        return events;
    }
}
