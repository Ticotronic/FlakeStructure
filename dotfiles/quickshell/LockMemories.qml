import QtQuick
import Quickshell
import Quickshell.Io

// Immich-Erinnerungen "An diesem Tag" fuer den Sperrbildschirm.
//
// Alles laeuft ueber den Wrapper "qs-immich" (modules/qs-immich-body.sh, der
// API-Schluessel kommt aus sops). Ist Immich nicht erreichbar (nicht im
// Heimnetz und kein VPN), schlaegt die Abfrage fehl und `available` bleibt
// false - dann zeigt LockMemoryWidget.qml gar nichts an.
//
// Die Vorschaubilder werden nur waehrend der Sperre in $XDG_RUNTIME_DIR (tmpfs,
// nur fuer dich lesbar) abgelegt und beim Entsperren wieder geloescht.
Scope {
    id: root

    // ---- Einstellungen ----
    readonly property int maxYears: 8       // so weit zurueck
    readonly property int maxTiles: 5       // so viele Jahre gleichzeitig anzeigen
    readonly property int freshSeconds: 300 // juenger als das: Anzeige bleibt waehrend der Neupruefung sichtbar
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-lock-immich"

    // ---- Ergebnis ----
    property bool available: false          // Immich erreichbar und Erinnerungen vorhanden
    property var items: []                  // [{year, ago, label, assets:[{id,type}]}], neueste zuerst
    property string lastJson: ""
    property double checkedMs: 0

    // ---- Betrachter (gemeinsam fuer alle Monitore) ----
    property int openIndex: -1              // -1 = nur die Vorschau-Leiste
    property int pos: 0                     // Bild innerhalb des Jahres
    readonly property var currentItem:
        (openIndex >= 0 && openIndex < items.length) ? items[openIndex] : null
    readonly property var currentAsset:
        currentItem ? (currentItem.assets[pos] || null) : null

    // ---- Beschriftung ----
    readonly property var words: ["", "einem", "zwei", "drei", "vier", "fünf", "sechs",
                                  "sieben", "acht", "neun", "zehn", "elf", "zwölf"]
    function label(n) {
        if (n === 1)
            return "Vor einem Jahr";
        return "Vor " + (n < words.length ? words[n] : String(n)) + " Jahren";
    }

    // JSON von `qs-immich memories` -> Liste fuer die Oberflaeche
    // Beispiel: [{"year":2025,"assets":[{"id":"...","type":"IMAGE"}]}, ...]
    function parseItems(text, nowYear) {
        var arr = JSON.parse(text);
        var out = [];
        for (var i = 0; i < arr.length; i++) {
            var e = arr[i];
            if (!e || typeof e.year !== "number" || !e.assets || e.assets.length === 0)
                continue;
            var n = nowYear - e.year;
            if (n < 1 || n > maxYears)
                continue;
            var assets = [];
            for (var k = 0; k < e.assets.length; k++)
                assets.push({ id: e.assets[k].id, type: e.assets[k].type });
            out.push({ year: e.year, ago: n, label: label(n), assets: assets });
        }
        out.sort(function (a, b) { return b.year - a.year; });
        return out.slice(0, maxTiles);
    }

    // ---- Abfrage ----
    function refresh() {
        if (listProc.running)
            return;
        failedIds = {};
        videoFailed = {};
        listProc.buf = "";
        listProc.command = ["qs-immich", "memories",
                            Qt.formatDate(new Date(), "yyyy-MM-dd"), String(maxYears)];
        listProc.running = true;
    }

    // Beim Sperren aufrufen: alles zuruecksetzen und neu pruefen. Ist die letzte
    // erfolgreiche Pruefung aelter, bleibt die Anzeige verborgen, bis Immich
    // wieder geantwortet hat.
    function prepare() {
        reset();
        if (Date.now() - checkedMs > freshSeconds * 1000)
            available = false;
        refresh();
    }

    function listDone(code, text) {
        if (code !== 0) {
            available = false;
            console.info("Sperrbildschirm-Erinnerungen: Immich nicht erreichbar (Code " + code + ")");
            return;
        }
        var parsed = null;
        try {
            parsed = parseItems(text, new Date().getFullYear());
        } catch (e) {
            console.warn("Sperrbildschirm-Erinnerungen: Antwort nicht lesbar: " + e);
        }
        if (parsed === null) {
            available = false;
            return;
        }
        var json = JSON.stringify(parsed);
        if (json !== lastJson) {
            lastJson = json;
            reset();
            items = parsed;
        }
        checkedMs = Date.now();
        available = items.length > 0;
        console.info("Sperrbildschirm-Erinnerungen: " + items.length + " Jahre");
        // erstes Bild jedes Jahres fuer die Vorschau-Leiste laden
        for (var i = 0; i < items.length; i++)
            ensure(items[i].assets[0].id, false);
    }

    Process {
        id: listProc
        property string buf: ""
        stdout: SplitParser {
            onRead: data => listProc.buf += data
        }
        onExited: code => root.listDone(code, buf)
    }

    // ---- Vorschaubilder laden (eins nach dem anderen) ----
    property var have: ({})         // id -> true, sobald die Datei da ist
    property var failedIds: ({})
    property var queue: []
    property int tick: 0            // aendert sich, wenn sich have/failedIds aendert

    // 0 = laedt noch / nicht angefordert, 1 = fertig, 2 = fehlgeschlagen
    function loadState(id) {
        var t = tick;
        if (have[id])
            return 1;
        if (failedIds[id])
            return 2;
        return 0;
    }

    // file://-URL des geladenen Bildes, sonst ""
    function fileUrl(id) {
        var t = tick;
        return have[id] ? "file://" + cacheDir + "/" + id + ".img" : "";
    }

    function ensure(id, urgent) {
        if (!id || have[id] || failedIds[id] || fetchProc.current === id)
            return;
        var q = queue.filter(function (x) { return x !== id; });
        if (urgent)
            q.unshift(id);
        else
            q.push(id);
        queue = q;
        pump();
    }

    function pump() {
        if (fetchProc.running || queue.length === 0)
            return;
        var id = queue[0];
        queue = queue.slice(1);
        fetchProc.current = id;
        fetchProc.command = ["qs-immich", "fetch", id, cacheDir + "/" + id + ".img"];
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        property string current: ""
        onExited: code => {
            var id = current;
            current = "";
            if (id !== "") {
                if (code === 0) {
                    have[id] = true;
                } else {
                    failedIds[id] = true;
                    console.warn("Sperrbildschirm-Erinnerungen: Bild " + id + " nicht ladbar (Code " + code + ")");
                }
                root.tick++;
            }
            root.pump();
        }
    }

    // ---- Videos (nur das gerade angezeigte, komplett in eine Datei) ----
    property var videoHave: ({})
    property var videoFailed: ({})

    // 0 = laedt noch, 1 = fertig, 2 = fehlgeschlagen
    function videoState(id) {
        var t = tick;
        if (videoHave[id])
            return 1;
        if (videoFailed[id])
            return 2;
        return 0;
    }

    function videoUrl(id) {
        var t = tick;
        return videoHave[id] ? "file://" + cacheDir + "/" + id + ".mp4" : "";
    }

    function ensureVideo(id) {
        if (!id || videoHave[id] || videoFailed[id])
            return;
        if (videoProc.running) {
            if (videoProc.current === id)
                return;
            // anderes Video laeuft noch: abbrechen, danach das gewuenschte starten
            videoProc.pending = id;
            videoProc.current = "";
            videoProc.running = false;
            return;
        }
        startVideo(id);
    }

    function startVideo(id) {
        videoProc.pending = "";
        videoProc.current = id;
        videoProc.command = ["qs-immich", "video", id, cacheDir + "/" + id + ".mp4"];
        videoProc.running = true;
    }

    function cancelVideo() {
        videoProc.pending = "";
        if (videoProc.running) {
            videoProc.current = "";
            videoProc.running = false;
        }
    }

    Process {
        id: videoProc
        property string current: ""
        property string pending: ""
        onExited: code => {
            var id = current;
            current = "";
            if (id !== "") {
                if (code === 0) {
                    root.videoHave[id] = true;
                } else {
                    root.videoFailed[id] = true;
                    console.warn("Sperrbildschirm-Erinnerungen: Video " + id + " nicht ladbar (Code " + code + ")");
                }
                root.tick++;
            }
            if (pending !== "")
                root.startVideo(pending);
        }
    }

    // aktuelles Bild sofort, Nachbarn danach
    function prefetch() {
        var it = currentItem;
        if (!it)
            return;
        ensure(it.assets[pos].id, true);
        if (it.assets[pos].type === "VIDEO")
            ensureVideo(it.assets[pos].id);
        else
            cancelVideo();
        if (pos + 1 < it.assets.length)
            ensure(it.assets[pos + 1].id, false);
        if (pos > 0)
            ensure(it.assets[pos - 1].id, false);
    }

    // ---- Bedienung ----
    function open(index) {
        if (index < 0 || index >= items.length)
            return;
        openIndex = index;
        pos = 0;
        prefetch();
    }

    function close() {
        openIndex = -1;
        pos = 0;
        cancelVideo();
    }

    function next() {
        if (currentItem && pos < currentItem.assets.length - 1) {
            pos++;
            prefetch();
        }
    }

    function prev() {
        if (currentItem && pos > 0) {
            pos--;
            prefetch();
        }
    }

    function reset() {
        close();
    }

    // Beim Entsperren: Bilder wieder loeschen
    function clearCache() {
        queue = [];
        fetchProc.current = "";     // ein noch laufender Abruf wird nicht mehr gezaehlt
        if (fetchProc.running)
            fetchProc.running = false;
        cancelVideo();
        have = {};
        failedIds = {};
        videoHave = {};
        videoFailed = {};
        tick++;
        Quickshell.execDetached(["rm", "-rf", cacheDir]);
    }

    // Reste eines frueheren Laufs (z.B. nach einem Absturz) entfernen
    Component.onCompleted: Quickshell.execDetached(["rm", "-rf", cacheDir])
}
