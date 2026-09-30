pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Read-only CalDAV client fuer VTODO-Aufgaben (Stufe 1: nur lesen,
// analog zur ersten Ausbaustufe von NextcloudCalDAV.qml fuer Termine).
//
// Ablauf pro Aktualisierung:
//  1. "nextcloud-tasks-discover" listet per PROPFIND alle Kalender-
//     sammlungen im Calendar-Home des Nutzers auf. Wir filtern die
//     heraus, die VTODO unterstuetzen (= Task-Listen) -> taskLists.
//  2. "nextcloud-tasks-fetch <href1> <href2> ..." holt per REPORT alle
//     VTODOs aus genau diesen Sammlungen, mit einer "### HREF ..."-
//     Markerzeile vor jedem Abschnitt, damit jede Aufgabe ihrer
//     Ursprungsliste zugeordnet werden kann.
//
// Schreiben (anlegen/bearbeiten/erledigen/loeschen) folgt in Stufe 2.
Singleton {
    id: tasksDav

    property var taskLists: []   // [{ href, name }]
    property var tasks: []       // geparste VTODOs, siehe parseTasksXml()
    property bool lastFetchFailed: false

    Timer {
        interval: 600000 // 10 Minuten
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: tasksDav.fetchNow()
    }

    function fetchNow() {
        if (!discoverProc.running) {
            discoverProc.rawBuffer = "";
            discoverProc.running = true;
        }
    }

    // ---- Schritt 1: Task-Listen entdecken ------------------------------

    Process {
        id: discoverProc
        command: ["nextcloud-tasks-discover"]
        property string rawBuffer: ""

        stdout: SplitParser {
            onRead: data => {
                discoverProc.rawBuffer += data + "\n";
            }
        }

        onExited: code => {
            if (code !== 0 || discoverProc.rawBuffer.length === 0) {
                tasksDav.lastFetchFailed = true;
                return;
            }
            try {
                var lists = tasksDav.parseDiscovery(discoverProc.rawBuffer);
                tasksDav.taskLists = lists;
                if (lists.length > 0) {
                    var hrefs = lists.map(function (l) { return l.href; });
                    fetchProc.rawBuffer = "";
                    fetchProc.command = ["nextcloud-tasks-fetch"].concat(hrefs);
                    fetchProc.running = true;
                } else {
                    tasksDav.tasks = [];
                }
            } catch (e) {
                console.log("NextcloudTasksDAV: discovery parse error", e);
                tasksDav.lastFetchFailed = true;
            }
        }
    }

    // ---- Schritt 2: VTODOs aus den entdeckten Listen abrufen -----------

    Process {
        id: fetchProc
        property string rawBuffer: ""

        stdout: SplitParser {
            onRead: data => {
                fetchProc.rawBuffer += data + "\n";
            }
        }

        onExited: code => {
            if (code === 0 && fetchProc.rawBuffer.length > 0) {
                try {
                    tasksDav.tasks = tasksDav.parseTasksXml(fetchProc.rawBuffer);
                    tasksDav.lastFetchFailed = false;
                } catch (e) {
                    console.log("NextcloudTasksDAV: fetch parse error", e);
                    tasksDav.lastFetchFailed = true;
                }
            } else {
                tasksDav.lastFetchFailed = true;
            }
        }
    }

    // ---- XML / iCalendar Hilfsfunktionen --------------------------------
    // (bewusst dupliziert aus NextcloudCalDAV.qml statt geteilt, da es
    // dafuer noch kein gemeinsames Hilfsmodul in diesem Projekt gibt)

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
        return m ? tasksDav.unescapeXml(m[1]) : "";
    }

    function extractDisplayName(responseXml) {
        var m = responseXml.match(/<(?:[a-zA-Z0-9]+:)?displayname[^>]*>([\s\S]*?)<\/(?:[a-zA-Z0-9]+:)?displayname>/i);
        return m ? tasksDav.unescapeXml(m[1]) : "";
    }

    function extractCalendarData(responseXml) {
        var m = responseXml.match(/<(?:[a-zA-Z0-9]+:)?calendar-data[^>]*>([\s\S]*?)<\/(?:[a-zA-Z0-9]+:)?calendar-data>/i);
        return m ? tasksDav.unescapeXml(m[1]) : "";
    }

    function isCalendarCollection(responseXml) {
        return /<[a-zA-Z0-9]+:calendar\s*\/>/i.test(responseXml);
    }

    function supportsVTodo(responseXml) {
        return /<[a-zA-Z0-9]+:comp\s+name=["']VTODO["']\s*\/?>/i.test(responseXml);
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

    // ---- Discovery-Antwort -> Liste VTODO-faehiger Kalender ------------

    function parseDiscovery(xmlText) {
        var lists = [];
        var blocks = tasksDav.extractResponseBlocks(xmlText);
        for (var i = 0; i < blocks.length; i++) {
            var block = blocks[i];
            if (!tasksDav.isCalendarCollection(block)) continue;
            if (!tasksDav.supportsVTodo(block)) continue;
            var href = tasksDav.extractHref(block);
            if (!href) continue;
            var name = tasksDav.extractDisplayName(block) || href;
            lists.push({ href: href, name: name });
        }
        return lists;
    }

    // ---- Fetch-Antwort (mehrere "### HREF ..."-Abschnitte) -> Aufgaben -

    function parseTasksXml(rawBuffer) {
        var allTasks = [];
        var segments = rawBuffer.split("### HREF ");

        for (var s = 1; s < segments.length; s++) { // segments[0] ist leer/Vorspann
            var segment = segments[s];
            var newlineIdx = segment.indexOf("\n");
            if (newlineIdx === -1) continue;
            var listHref = segment.substring(0, newlineIdx).trim();
            var xmlText = segment.substring(newlineIdx + 1);

            var listName = listHref;
            for (var li = 0; li < tasksDav.taskLists.length; li++) {
                if (tasksDav.taskLists[li].href === listHref) {
                    listName = tasksDav.taskLists[li].name;
                    break;
                }
            }

            var responseBlocks = tasksDav.extractResponseBlocks(xmlText);
            for (var b = 0; b < responseBlocks.length; b++) {
                var href = tasksDav.extractHref(responseBlocks[b]);
                var calData = tasksDav.extractCalendarData(responseBlocks[b]);
                if (!calData) continue;

                var lines = tasksDav.unfoldIcs(calData);

                var todoBlocks = [];
                var current = null;
                for (var i = 0; i < lines.length; i++) {
                    var trimmed = lines[i].trim().toUpperCase();
                    if (trimmed === "BEGIN:VTODO") {
                        current = [];
                    } else if (trimmed === "END:VTODO") {
                        if (current) todoBlocks.push(current);
                        current = null;
                    } else if (current) {
                        current.push(lines[i]);
                    }
                }

                for (var t = 0; t < todoBlocks.length; t++) {
                    var tLines = todoBlocks[t];

                    var uidField = tasksDav.findIcsField(tLines, "UID");
                    if (!uidField) continue;

                    var summaryField = tasksDav.findIcsField(tLines, "SUMMARY");
                    var descriptionField = tasksDav.findIcsField(tLines, "DESCRIPTION");
                    var statusField = tasksDav.findIcsField(tLines, "STATUS");
                    var priorityField = tasksDav.findIcsField(tLines, "PRIORITY");
                    var dueField = tasksDav.findIcsField(tLines, "DUE");
                    var percentField = tasksDav.findIcsField(tLines, "PERCENT-COMPLETE");

                    var dueInfo = dueField
                        ? tasksDav.parseIcsDateTime(dueField.value, dueField.params)
                        : null;

                    var statusValue = statusField ? statusField.value.trim().toUpperCase() : "";
                    var percentValue = percentField ? parseInt(percentField.value) : 0;
                    var completed = statusValue === "COMPLETED" || percentValue === 100;

                    allTasks.push({
                        id: "nc-task-" + uidField.value,
                        uid: uidField.value,
                        href: href,
                        listHref: listHref,
                        listName: listName,
                        title: summaryField ? summaryField.value : "(ohne Titel)",
                        description: descriptionField ? descriptionField.value : "",
                        completed: completed,
                        dueDate: dueInfo ? dueInfo.date : "",
                        dueTime: dueInfo ? dueInfo.time : "",
                        priority: priorityField ? (parseInt(priorityField.value) || 0) : 0
                    });
                }
            }
        }

        return allTasks;
    }
}
