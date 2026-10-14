import QtQuick
import Quickshell
import Quickshell.Io

// Wetter fuer den Sperrbildschirm.
//
// Standort: per IP-Adresse (ipinfo.io, nur Stadt-Genauigkeit). Achtung: Laeuft
// ein VPN (z.B. WireGuard), ist es der Standort des VPN-Ausgangs. Wer das nicht
// will, traegt unten fixedLat/fixedLon/fixedName ein, dann entfaellt die
// IP-Abfrage komplett.
// Wetter: Open-Meteo (kostenlos, ohne Schluessel), alle 30 Minuten.
// Beides sind Anfragen ins Internet; Open-Meteo und ipinfo.io sehen dabei deine IP.
Scope {
    id: root

    // ---- Einstellungen ----
    property string fixedLat: ""      // z.B. "52.52"
    property string fixedLon: ""      // z.B. "13.41"
    property string fixedName: ""     // z.B. "Berlin"
    readonly property int refreshMinutes: 30
    readonly property int maxAgeHours: 3   // aelter als das wird nichts mehr angezeigt

    // ---- Ergebnis ----
    property bool valid: false
    property bool stale: false
    readonly property bool show: valid && !stale
    property string place: ""
    property int temperature: 0
    property int apparent: 0
    property string condition: ""
    property string glyph: ""
    property double updatedMs: 0

    // zuletzt bekannter Standort, falls die IP-Abfrage mal fehlschlaegt
    property string lastLat: ""
    property string lastLon: ""

    // ---- Wetter-Code (WMO) -> Text und Symbol (Nerd Font, Material Design) ----
    function describe(code, isDay) {
        switch (code) {
        case 0:  return { t: "Klar", g: isDay ? 0xF0599 : 0xF0594 };
        case 1:  return { t: "Überwiegend klar", g: isDay ? 0xF0599 : 0xF0594 };
        case 2:  return { t: "Teils bewölkt", g: isDay ? 0xF0595 : 0xF0F31 };
        case 3:  return { t: "Bedeckt", g: 0xF0590 };
        case 45: case 48: return { t: "Nebel", g: 0xF0591 };
        case 51: case 53: case 55: return { t: "Nieselregen", g: 0xF0597 };
        case 56: case 57: return { t: "Gefrierender Nieselregen", g: 0xF067F };
        case 61: case 63: return { t: "Regen", g: 0xF0597 };
        case 65: return { t: "Starkregen", g: 0xF0596 };
        case 66: case 67: return { t: "Gefrierender Regen", g: 0xF067F };
        case 71: case 73: case 75: case 77: return { t: "Schnee", g: 0xF0598 };
        case 80: case 81: return { t: "Regenschauer", g: 0xF0597 };
        case 82: return { t: "Heftige Schauer", g: 0xF0596 };
        case 85: case 86: return { t: "Schneeschauer", g: 0xF0598 };
        case 95: return { t: "Gewitter", g: 0xF067E };
        case 96: case 99: return { t: "Gewitter mit Hagel", g: 0xF0593 };
        default: return { t: "", g: 0xF0590 };
        }
    }

    // ipinfo.io/json -> { lat, lon, name } oder null
    // Beispiel: {"ip":"...","city":"Berlin","loc":"52.5200,13.4050",...}
    function parseGeo(text) {
        var j = JSON.parse(text);
        var parts = (j.loc || "").split(",");
        if (parts.length !== 2)
            return null;
        var lat = parts[0].trim();
        var lon = parts[1].trim();
        if (isNaN(parseFloat(lat)) || isNaN(parseFloat(lon)))
            return null;
        return { lat: lat, lon: lon, name: j.city || "" };
    }

    // Open-Meteo -> setzt die Ergebnis-Eigenschaften, gibt true bei Erfolg
    // Beispiel: {"current":{"time":"...","temperature_2m":12.3,
    //            "apparent_temperature":10.5,"weather_code":3,"is_day":0}}
    function applyWeather(text) {
        var j = JSON.parse(text);
        var c = j.current;
        if (!c || typeof c.temperature_2m !== "number")
            return false;
        var d = describe(c.weather_code, c.is_day === 1);
        temperature = Math.round(c.temperature_2m);
        apparent = Math.round(typeof c.apparent_temperature === "number"
                              ? c.apparent_temperature : c.temperature_2m);
        condition = d.t;
        glyph = String.fromCodePoint(d.g);
        updatedMs = Date.now();
        valid = true;
        stale = false;
        return true;
    }

    // ---- Ablauf ----
    function refresh() {
        if (geoProc.running || weatherProc.running)
            return;
        if (fixedLat !== "" && fixedLon !== "") {
            place = fixedName;
            fetchWeather(fixedLat, fixedLon);
        } else {
            geoProc.buf = "";
            geoProc.running = true;
        }
    }

    // Beim Sperren: nur auffrischen, wenn die Daten schon etwas alt sind
    function refreshIfOld() {
        if (!valid || Date.now() - updatedMs > 20 * 60 * 1000)
            refresh();
    }

    function fetchWeather(lat, lon) {
        weatherProc.buf = "";
        weatherProc.command = ["curl", "-fsS", "-m", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,weather_code,is_day&timezone=auto"];
        weatherProc.running = true;
    }

    function failed(what) {
        console.warn("Sperrbildschirm-Wetter: " + what);
        if (valid && Date.now() - updatedMs > maxAgeHours * 3600 * 1000)
            stale = true;
    }

    Process {
        id: geoProc
        property string buf: ""
        command: ["curl", "-fsS", "-m", "10", "https://ipinfo.io/json"]
        stdout: SplitParser {
            onRead: data => geoProc.buf += data + "\n"
        }
        onExited: code => {
            var geo = null;
            if (code === 0) {
                try { geo = root.parseGeo(buf); } catch (e) { geo = null; }
            }
            if (geo) {
                root.lastLat = geo.lat;
                root.lastLon = geo.lon;
                root.place = geo.name;
                root.fetchWeather(geo.lat, geo.lon);
            } else if (root.lastLat !== "") {
                root.failed("Standortabfrage fehlgeschlagen, nutze letzten Standort");
                root.fetchWeather(root.lastLat, root.lastLon);
            } else {
                root.failed("Standortabfrage fehlgeschlagen (curl-Code " + code + ")");
            }
        }
    }

    Process {
        id: weatherProc
        property string buf: ""
        stdout: SplitParser {
            onRead: data => weatherProc.buf += data + "\n"
        }
        onExited: code => {
            var ok = false;
            if (code === 0) {
                try { ok = root.applyWeather(buf); } catch (e) { ok = false; }
            }
            if (!ok)
                root.failed("Wetterabfrage fehlgeschlagen (curl-Code " + code + ")");
        }
    }

    Timer {
        interval: root.refreshMinutes * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
