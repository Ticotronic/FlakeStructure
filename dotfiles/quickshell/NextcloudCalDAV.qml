pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Stufe 1: read-only CalDAV client against the user's self-hosted Nextcloud.
// Fetches VEVENTs in a rolling window (-31 days .. +180 days) every 10 minutes,
// parses the iCalendar response and exposes it as `remoteEvents`, which
// CalendarEvents.qml merges together with the local JSON-backed events.
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

    // ---- XML / iCalendar helpers -------------------------------------

    function extractCalendarDataBlocks(xmlText) {
        // Namespace-agnostic: matches <c:calendar-data ...>...</c:calendar-data>
        // or <calendar-data ...>...</calendar-data>, case-insensitive tag names.
        var blocks = [];
        var re = /<(?:[a-zA-Z0-9]+:)?calendar-data[^>]*>([\s\S]*?)<\/(?:[a-zA-Z0-9]+:)?calendar-data>/gi;
        var match;
        while ((match = re.exec(xmlText)) !== null) {
            blocks.push(nextcloudCalDAV.unescapeXml(match[1]));
        }
        return blocks;
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

    function parseResponse(xmlText) {
        var events = [];
        var blocks = nextcloudCalDAV.extractCalendarDataBlocks(xmlText);

        for (var b = 0; b < blocks.length; b++) {
            var lines = nextcloudCalDAV.unfoldIcs(blocks[b]);

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

                if (!uidField || !dtstartField) continue;

                var startInfo = nextcloudCalDAV.parseIcsDateTime(dtstartField.value, dtstartField.params);
                var endInfo = dtendField
                    ? nextcloudCalDAV.parseIcsDateTime(dtendField.value, dtendField.params)
                    : startInfo;

                events.push({
                    id: "nc-" + uidField.value,
                    uid: uidField.value,
                    title: summaryField ? summaryField.value : "(ohne Titel)",
                    allDay: startInfo.allDay,
                    startDate: startInfo.date,
                    startTime: startInfo.time,
                    endDate: endInfo.date,
                    endTime: endInfo.time,
                    location: locationField ? locationField.value : "",
                    description: descriptionField ? descriptionField.value : "",
                    reminder: -1,
                    repeat: "none",
                    color: "#74c7ec",
                    source: "nextcloud"
                });
            }
        }

        return events;
    }
}
