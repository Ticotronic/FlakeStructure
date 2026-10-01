pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CalDAV client fuer VTODO-Aufgaben.
//
// Lesen (Stufe 1):
//  1. "nextcloud-tasks-discover" listet per PROPFIND alle Kalender-
//     sammlungen im Calendar-Home des Nutzers auf. Wir filtern die
//     heraus, die VTODO unterstuetzen (= Task-Listen) -> taskLists.
//  2. "nextcloud-tasks-fetch <href1> <href2> ..." holt per REPORT alle
//     VTODOs aus genau diesen Sammlungen, mit einer "### HREF ..."-
//     Markerzeile vor jedem Abschnitt, damit jede Aufgabe ihrer
//     Ursprungsliste zugeordnet werden kann.
//
// Schreiben (Stufe 2, analog zu NextcloudCalDAV.qml/CalendarEvents.qml):
//  - createTask/updateTask/deleteTask stossen "nextcloud-tasks-push" (PUT
//    bzw. DELETE) fire-and-forget an (Quickshell.execDetached), patchen den
//    lokalen "tasks"-Zustand optimistisch fuer eine sofort reagierende UI,
//    und stossen kurz danach ein echtes Re-Fetch an, damit der optimistische
//    Stand mit dem tatsaechlich vom Server akzeptierten Stand abgeglichen
//    wird.
//  - Beim Anlegen waehlen WIR den Dateinamen (href = listHref + uid + ".ics"),
//    beim Bearbeiten/Loeschen wird immer der echte, beim Fetch gelieferte
//    href verwendet (siehe extractHref) - NIE ein aus der UID geratener Pfad.
Singleton {
    id: tasksDav

    property var taskLists: []   // [{ href, name }]
    property var tasks: []       // geparste VTODOs, siehe parseTasksXml()
    property bool lastFetchFailed: false

    // ---- Dialog-Zustand (TaskDialog.qml, geteilt ueber alle Screens) ----

    property bool dialogVisible: false
    property var activeScreen: null
    property string editingTaskUid: ""   // "" => neue Aufgabe anlegen
    property string selectedListHref: "" // Vorauswahl fuer eine neue Aufgabe

    function openForCreate(listHref, screen) {
        tasksDav.editingTaskUid = "";
        tasksDav.selectedListHref = listHref && listHref.length > 0
            ? listHref
            : (tasksDav.taskLists.length > 0 ? tasksDav.taskLists[0].href : "");
        tasksDav.activeScreen = screen;
        tasksDav.dialogVisible = true;
    }

    function openForEdit(uid, screen) {
        tasksDav.editingTaskUid = uid;
        tasksDav.activeScreen = screen;
        tasksDav.dialogVisible = true;
    }

    function closeDialog() {
        tasksDav.dialogVisible = false;
        tasksDav.activeScreen = null;
    }

    function findTask(uid) {
        for (var i = 0; i < tasksDav.tasks.length; i++) {
            if (tasksDav.tasks[i].uid === uid) return tasksDav.tasks[i];
        }
        return null;
    }

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

    // ---- Optimistisches lokales Patchen (analog zu NextcloudCalDAV.qml) --

    function patchRemoteTask(uid, href, listHref, listName, fields) {
        var list = tasksDav.tasks.slice();
        for (var i = 0; i < list.length; i++) {
            if (list[i].uid === uid) {
                list[i] = Object.assign({}, list[i], fields, { href: href, listHref: listHref, listName: listName });
                tasksDav.tasks = list;
                return;
            }
        }
        // Neu angelegte Aufgabe: taucht erst nach dem naechsten Fetch aus dem
        // REPORT auf, bis dahin haengen wir sie selbst vorne an.
        list.push(Object.assign({
            id: "nc-task-" + uid,
            uid: uid,
            href: href,
            listHref: listHref,
            listName: listName
        }, fields));
        tasksDav.tasks = list;
    }

    function removeRemoteTask(uid) {
        tasksDav.tasks = tasksDav.tasks.filter(function (t) { return t.uid !== uid; });
    }

    Timer {
        id: quickRefetchTimer
        interval: 2000
        repeat: false
        onTriggered: tasksDav.fetchNow()
    }
    function scheduleQuickRefetch() {
        quickRefetchTimer.restart();
    }

    // ---- CRUD --------------------------------------------------------

    // fields: { title, description, completed, dueDate, dueTime, priority,
    //           parentUid }
    // parentUid wird NICHT von hier aus gesetzt (Anlegen einer Teilaufgabe
    // gibt es im Dialog noch nicht) - aber beim Bearbeiten/Abhaken einer
    // BESTEHENDEN Teilaufgabe muss sie mit durchgereicht werden, sonst geht
    // die RELATED-TO-Verknuepfung beim naechsten PUT verloren.
    function createTask(listHref, fields) {
        if (!listHref) return;
        var uid = tasksDav.newUid();
        var href = listHref + uid + ".ics";
        var listName = "";
        for (var i = 0; i < tasksDav.taskLists.length; i++) {
            if (tasksDav.taskLists[i].href === listHref) { listName = tasksDav.taskLists[i].name; break; }
        }
        var ics = tasksDav.buildVTodoIcs(fields, uid);
        Quickshell.execDetached(["nextcloud-tasks-push", "put", href, ics]);
        tasksDav.patchRemoteTask(uid, href, listHref, listName, {
            title: fields.title,
            description: fields.description || "",
            completed: !!fields.completed,
            dueDate: fields.dueDate || "",
            dueTime: fields.dueTime || "",
            priority: fields.priority || 0,
            parentUid: fields.parentUid || ""
        });
        tasksDav.scheduleQuickRefetch();
    }

    function updateTask(uid, href, listHref, listName, fields) {
        var target = href && href.length > 0 ? href : (listHref + uid + ".ics");
        var ics = tasksDav.buildVTodoIcs(fields, uid);
        Quickshell.execDetached(["nextcloud-tasks-push", "put", target, ics]);
        tasksDav.patchRemoteTask(uid, target, listHref, listName, {
            title: fields.title,
            description: fields.description || "",
            completed: !!fields.completed,
            dueDate: fields.dueDate || "",
            dueTime: fields.dueTime || "",
            priority: fields.priority || 0,
            parentUid: fields.parentUid || ""
        });
        tasksDav.scheduleQuickRefetch();
    }

    // Bequemlichkeitsfunktion fuer den Checkbox-Klick in TasksWidget.qml -
    // erledigt/wiedereroeffnet eine Aufgabe (Haupt- oder Teilaufgabe), ohne
    // den Dialog zu oeffnen.
    function setCompleted(task, completed) {
        tasksDav.updateTask(task.uid, task.href, task.listHref, task.listName, {
            title: task.title,
            description: task.description,
            completed: completed,
            dueDate: task.dueDate,
            dueTime: task.dueTime,
            priority: task.priority,
            parentUid: task.parentUid || ""
        });
    }

    function deleteTask(uid, href) {
        Quickshell.execDetached(["nextcloud-tasks-push", "delete", href, ""]);
        tasksDav.removeRemoteTask(uid);
        tasksDav.scheduleQuickRefetch();
    }

    // ---- iCalendar-Erzeugung (VTODO) ----------------------------------

    function newUid() {
        return "quickshell-" + Date.now() + "-" + Math.floor(Math.random() * 100000);
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
        return d.getUTCFullYear() + tasksDav.pad2(d.getUTCMonth() + 1) + tasksDav.pad2(d.getUTCDate()) + "T" +
               tasksDav.pad2(d.getUTCHours()) + tasksDav.pad2(d.getUTCMinutes()) + tasksDav.pad2(d.getUTCSeconds()) + "Z";
    }

    function toIcsUtc(dateStr, timeStr) {
        // Interpretiert dateStr/timeStr als lokale Wanduhrzeit (System-TZ)
        // und formatiert als UTC - vermeidet VTIMEZONE/TZID komplett,
        // genau wie CalendarEvents.qml das fuer Termine macht.
        var d = new Date(dateStr + "T" + (timeStr || "00:00") + ":00");
        return d.getUTCFullYear() + tasksDav.pad2(d.getUTCMonth() + 1) + tasksDav.pad2(d.getUTCDate()) + "T" +
               tasksDav.pad2(d.getUTCHours()) + tasksDav.pad2(d.getUTCMinutes()) + "00Z";
    }

    function buildVTodoIcs(task, uid) {
        var lines = [];
        lines.push("BEGIN:VCALENDAR");
        lines.push("VERSION:2.0");
        lines.push("PRODID:-//quickshell//tasks//DE");
        lines.push("BEGIN:VTODO");
        lines.push("UID:" + uid);
        lines.push("DTSTAMP:" + tasksDav.nowIcsUtc());
        lines.push("SUMMARY:" + tasksDav.escapeIcsText(task.title));
        if (task.description) lines.push("DESCRIPTION:" + tasksDav.escapeIcsText(task.description));

        if (task.dueDate) {
            if (task.dueTime) {
                lines.push("DUE:" + tasksDav.toIcsUtc(task.dueDate, task.dueTime));
            } else {
                lines.push("DUE;VALUE=DATE:" + task.dueDate.replace(/-/g, ""));
            }
        }

        if (task.priority) lines.push("PRIORITY:" + task.priority);
        if (task.parentUid) lines.push("RELATED-TO:" + task.parentUid);

        if (task.completed) {
            lines.push("STATUS:COMPLETED");
            lines.push("PERCENT-COMPLETE:100");
            lines.push("COMPLETED:" + tasksDav.nowIcsUtc());
        } else {
            lines.push("STATUS:NEEDS-ACTION");
            lines.push("PERCENT-COMPLETE:0");
        }

        lines.push("END:VTODO");
        lines.push("END:VCALENDAR");
        return lines.join("\r\n") + "\r\n";
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
                    // Teilaufgaben: RELATED-TO zeigt (ohne expliziten RELTYPE,
                    // oder mit RELTYPE=PARENT) auf die UID der uebergeordneten
                    // Aufgabe - so legen sowohl Tasks.org als auch Nextcloud
                    // selbst Teilaufgaben-Beziehungen per CalDAV ab.
                    var relatedToField = tasksDav.findIcsField(tLines, "RELATED-TO");

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
                        priority: priorityField ? (parseInt(priorityField.value) || 0) : 0,
                        parentUid: relatedToField ? relatedToField.value.trim() : ""
                    });
                }
            }
        }

        return allTasks;
    }
}
