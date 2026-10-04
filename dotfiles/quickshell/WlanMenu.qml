import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// WLAN-Menue, das beim Klick auf den WLAN-Namen in der Leiste aufgeht
// (StatusIcons.qml). Ersetzt das Rechtsklick-Menue von nm-applet und nutzt
// dafuer nmcli:
//   - WLAN an/aus
//   - Liste der verfuegbaren Netzwerke (aktives zuerst, dann nach Signal)
//   - Klick verbindet (bekanntes Netz: gespeichertes Profil; offenes Netz:
//     direkt; verschluesseltes neues Netz: Passwort-Feld)
//   - Verbindung trennen, neu scannen, "Verbindungen bearbeiten" (oeffnet
//     nm-connection-editor aus networkmanagerapplet)
//
// Es ist bewusst ein eigenes Overlay-Fenster (wie TaskDialog/Launcher) und
// kein PopupWindow, damit das Passwort-Feld Tastatur-Fokus bekommt.
PanelWindow {
    id: wlanMenu

    property var barWindow: null
    property var anchorItem: null
    property bool open: false

    screen: barWindow ? barWindow.screen : null
    visible: open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: wlanMenu.pendingSsid !== ""
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.OnDemand

    // ---------- Zustand ----------
    property bool wifiEnabled: true
    property var networks: []            // [{ssid, signal, secure, inUse}]
    property string activeSsid: ""
    property string activeConn: ""       // Profilname der aktiven WLAN-Verbindung
    property var savedSsids: ({})        // Profilname -> true
    property string pendingSsid: ""      // Netz, fuer das gerade ein Passwort erfragt wird
    property string statusText: ""
    property bool statusIsError: false
    property bool busy: false
    property real panelX: 0
    readonly property int panelWidth: 340

    // Puffer fuer die Prozess-Ausgaben
    property var _listBuf: []
    property var _savedBuf: []
    property var _activeBuf: []
    property var _connectBuf: []

    function setStatus(text, isError) {
        wlanMenu.statusText = text;
        wlanMenu.statusIsError = isError;
    }

    function show() {
        var ax = 0;
        var aw = 0;
        if (wlanMenu.anchorItem) {
            ax = wlanMenu.anchorItem.mapToItem(null, 0, 0).x;
            aw = wlanMenu.anchorItem.width;
        }
        var maxX = Math.max(8, (wlanMenu.barWindow ? wlanMenu.barWindow.width : 1920) - wlanMenu.panelWidth - 8);
        wlanMenu.panelX = Math.max(8, Math.min(maxX, ax + aw / 2 - wlanMenu.panelWidth / 2));
        wlanMenu.pendingSsid = "";
        wlanMenu.setStatus("", false);
        wlanMenu.open = true;
        wlanMenu.refresh();
        wlanMenu.rescan();
    }

    function close() {
        wlanMenu.open = false;
        wlanMenu.pendingSsid = "";
    }

    function toggle() {
        if (wlanMenu.open) wlanMenu.close();
        else wlanMenu.show();
    }

    // ---------- nmcli-Ausgabe parsen ----------
    // Terse-Modus (-t) trennt mit ":" und escaped ":" und "\" im Inhalt
    // (z.B. SSIDs mit Doppelpunkt) als "\:" bzw. "\\".
    function splitTerse(line) {
        var out = [];
        var cur = "";
        for (var i = 0; i < line.length; i++) {
            var c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                cur += line[i + 1];
                i++;
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    function applyNetworks(lines) {
        var best = {};
        for (var i = 0; i < lines.length; i++) {
            var f = wlanMenu.splitTerse(lines[i]);
            if (f.length < 4) continue;
            var inUse = f[0] === "*";
            var ssid = f[1];
            if (ssid === "") continue; // versteckte Netze ohne Namen
            var signal = parseInt(f[2]) || 0;
            var secure = f[3] !== "" && f[3] !== "--";
            var e = best[ssid];
            if (!e) {
                best[ssid] = { ssid: ssid, signal: signal, secure: secure, inUse: inUse };
            } else {
                if (signal > e.signal) e.signal = signal;
                if (inUse) e.inUse = true;
            }
        }
        var list = Object.keys(best).map(function (k) { return best[k]; });
        list.sort(function (a, b) {
            if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
            return b.signal - a.signal;
        });

        var active = "";
        for (var j = 0; j < list.length; j++) if (list[j].inUse) active = list[j].ssid;
        wlanMenu.activeSsid = active;

        // Waehrend der Passwort-Eingabe oder ohne Aenderung die Liste nicht
        // ersetzen: ein neues Modell zerstoert die Delegates (und damit das
        // gerade getippte Passwort).
        if (wlanMenu.pendingSsid !== "") return;
        if (JSON.stringify(list) === JSON.stringify(wlanMenu.networks)) return;
        wlanMenu.networks = list;
    }

    function applySaved(lines) {
        var saved = {};
        for (var i = 0; i < lines.length; i++) {
            var f = wlanMenu.splitTerse(lines[i]);
            if (f.length >= 2 && f[1] === "802-11-wireless") saved[f[0]] = true;
        }
        wlanMenu.savedSsids = saved;
    }

    function applyActive(lines) {
        var name = "";
        for (var i = 0; i < lines.length; i++) {
            var f = wlanMenu.splitTerse(lines[i]);
            if (f.length >= 2 && f[1] === "802-11-wireless") name = f[0];
        }
        wlanMenu.activeConn = name;
    }

    // ---------- Aktualisieren ----------
    function refreshList() {
        wlanMenu._listBuf = [];
        listProc.running = true;
    }

    function refresh() {
        wlanMenu.refreshList();
        wlanMenu._savedBuf = [];
        savedProc.running = true;
        wlanMenu._activeBuf = [];
        activeProc.running = true;
        radioProc.running = true;
    }

    function rescan() {
        rescanProc.running = true;
    }

    // ---------- Aktionen ----------
    function connectTo(net) {
        if (wlanMenu.busy || net.inUse) return;
        var base = ["env", "LC_ALL=C", "nmcli"];
        if (wlanMenu.savedSsids[net.ssid]) {
            wlanMenu.startConnect(base.concat(["connection", "up", "id", net.ssid]), net.ssid);
        } else if (!net.secure) {
            wlanMenu.startConnect(base.concat(["device", "wifi", "connect", net.ssid]), net.ssid);
        } else {
            wlanMenu.setStatus("", false);
            wlanMenu.pendingSsid = net.ssid;
        }
    }

    function submitPassword(password) {
        if (password === "") return;
        var ssid = wlanMenu.pendingSsid;
        wlanMenu.pendingSsid = "";
        // Hinweis: das Passwort steht kurz in der Prozess-Argumentliste von nmcli.
        wlanMenu.startConnect(["env", "LC_ALL=C", "nmcli", "device", "wifi", "connect", ssid, "password", password], ssid);
    }

    function startConnect(cmd, ssid) {
        wlanMenu.busy = true;
        wlanMenu.setStatus("Verbinde mit " + ssid + " …", false);
        wlanMenu._connectBuf = [];
        connectProc.connectingSsid = ssid;
        connectProc.command = cmd;
        connectProc.running = true;
    }

    function disconnectWifi() {
        if (wlanMenu.activeConn === "" || wlanMenu.busy) return;
        wlanMenu.busy = true;
        wlanMenu.setStatus("Trenne Verbindung …", false);
        disconnectProc.command = ["env", "LC_ALL=C", "nmcli", "connection", "down", "id", wlanMenu.activeConn];
        disconnectProc.running = true;
    }

    function toggleWifi() {
        toggleProc.command = ["nmcli", "radio", "wifi", wlanMenu.wifiEnabled ? "off" : "on"];
        toggleProc.running = true;
    }

    // ---------- Prozesse ----------
    Process {
        id: listProc
        command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        stdout: SplitParser { onRead: data => wlanMenu._listBuf.push(data) }
        onExited: wlanMenu.applyNetworks(wlanMenu._listBuf)
    }

    Process {
        id: savedProc
        command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: SplitParser { onRead: data => wlanMenu._savedBuf.push(data) }
        onExited: wlanMenu.applySaved(wlanMenu._savedBuf)
    }

    Process {
        id: activeProc
        command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"]
        stdout: SplitParser { onRead: data => wlanMenu._activeBuf.push(data) }
        onExited: wlanMenu.applyActive(wlanMenu._activeBuf)
    }

    Process {
        id: radioProc
        command: ["env", "LC_ALL=C", "nmcli", "radio", "wifi"]
        stdout: SplitParser { onRead: data => wlanMenu.wifiEnabled = (data.trim() === "enabled") }
    }

    Process {
        id: rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        // Scan-Ergebnisse treffen erst nach ein paar Sekunden ein
        onExited: afterRescanTimer.restart()
    }

    Timer {
        id: afterRescanTimer
        interval: 3000
        onTriggered: if (wlanMenu.open) wlanMenu.refresh()
    }

    // Liste waehrend das Menue offen ist regelmaessig auffrischen
    Timer {
        interval: 6000
        running: wlanMenu.open && wlanMenu.wifiEnabled
        repeat: true
        onTriggered: wlanMenu.refresh()
    }

    Process {
        id: toggleProc
        onExited: toggleRefreshTimer.restart()
    }

    Timer {
        id: toggleRefreshTimer
        interval: 1500
        onTriggered: {
            wlanMenu.refresh();
            wlanMenu.rescan();
        }
    }

    Process {
        id: connectProc
        property string connectingSsid: ""
        stdout: SplitParser { onRead: data => wlanMenu._connectBuf.push(data) }
        stderr: SplitParser { onRead: data => wlanMenu._connectBuf.push(data) }
        onExited: code => {
            wlanMenu.busy = false;
            if (code === 0) {
                wlanMenu.setStatus("Verbunden mit " + connectProc.connectingSsid, false);
            } else {
                var msg = wlanMenu._connectBuf.join(" ");
                if (msg.indexOf("Secrets were required") >= 0 || msg.indexOf("802-1x") >= 0)
                    msg = "Verbindung fehlgeschlagen (Passwort falsch?)";
                else if (msg === "")
                    msg = "Verbindung fehlgeschlagen";
                wlanMenu.setStatus(msg, true);
            }
            wlanMenu.refresh();
        }
    }

    Process {
        id: disconnectProc
        onExited: code => {
            wlanMenu.busy = false;
            wlanMenu.setStatus(code === 0 ? "Verbindung getrennt" : "Trennen fehlgeschlagen", code !== 0);
            wlanMenu.refresh();
        }
    }

    // ---------- UI ----------
    // Klick daneben schliesst das Menue
    MouseArea {
        anchors.fill: parent
        onClicked: wlanMenu.close()
    }

    Rectangle {
        id: panel
        x: wlanMenu.panelX
        y: (wlanMenu.barWindow ? wlanMenu.barWindow.height : 32) + 4
        width: wlanMenu.panelWidth
        height: Math.min(content.implicitHeight + 24, Math.max(120, wlanMenu.height - y - 16))
        color: "#1e1e2e"
        border.color: "#313244"
        border.width: 1
        radius: 8
        focus: true

        Keys.onEscapePressed: wlanMenu.close()

        // Klicks ins Panel nicht an den Scrim durchreichen
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "WLAN"
                    color: "#cdd6f4"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    visible: wlanMenu.wifiEnabled
                    text: "Neu scannen"
                    color: "#89b4fa"
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wlanMenu.setStatus("Suche Netzwerke …", false);
                            wlanMenu.rescan();
                        }
                    }
                }

                // An/Aus-Schalter
                Rectangle {
                    width: 38
                    height: 20
                    radius: 10
                    color: wlanMenu.wifiEnabled ? "#a6e3a1" : "#45475a"

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        y: 2
                        x: wlanMenu.wifiEnabled ? parent.width - width - 2 : 2
                        color: "#1e1e2e"
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wlanMenu.toggleWifi()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: wlanMenu.statusText !== ""
                text: wlanMenu.statusText
                color: wlanMenu.statusIsError ? "#f38ba8" : "#a6adc8"
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

            Text {
                Layout.fillWidth: true
                visible: !wlanMenu.wifiEnabled
                text: "WLAN ist ausgeschaltet"
                color: "#6c7086"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                topPadding: 8
                bottomPadding: 8
            }

            Text {
                Layout.fillWidth: true
                visible: wlanMenu.wifiEnabled && wlanMenu.networks.length === 0
                text: "Keine Netzwerke gefunden"
                color: "#6c7086"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                topPadding: 8
                bottomPadding: 8
            }

            ListView {
                id: netList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Math.min(netList.contentHeight, 280)
                visible: wlanMenu.wifiEnabled && wlanMenu.networks.length > 0
                clip: true
                spacing: 2
                model: wlanMenu.networks

                delegate: Column {
                    id: netDelegate
                    required property var modelData
                    width: ListView.view.width
                    spacing: 4

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 6
                        color: rowMouse.containsMouse ? "#313244" : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                Layout.preferredWidth: 14
                                text: netDelegate.modelData.inUse ? "✓" : ""
                                color: "#a6e3a1"
                                font.pixelSize: 13
                            }

                            Text {
                                Layout.fillWidth: true
                                text: netDelegate.modelData.ssid
                                color: netDelegate.modelData.inUse ? "#a6e3a1" : "#cdd6f4"
                                font.pixelSize: 13
                                font.bold: netDelegate.modelData.inUse
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: netDelegate.modelData.secure
                                text: ""
                                color: "#6c7086"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                            }

                            Text {
                                Layout.preferredWidth: 34
                                horizontalAlignment: Text.AlignRight
                                text: netDelegate.modelData.signal + "%"
                                color: netDelegate.modelData.signal >= 60 ? "#a6e3a1"
                                     : netDelegate.modelData.signal >= 30 ? "#f9e2af"
                                     : "#f38ba8"
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wlanMenu.connectTo(netDelegate.modelData)
                        }
                    }

                    // Passwort-Eingabe fuer ein neues, verschluesseltes Netz
                    RowLayout {
                        width: parent.width
                        visible: wlanMenu.pendingSsid === netDelegate.modelData.ssid
                        spacing: 6

                        TextField {
                            id: pwField
                            Layout.fillWidth: true
                            placeholderText: "Passwort"
                            echoMode: TextInput.Password
                            onVisibleChanged: {
                                if (visible) {
                                    text = "";
                                    forceActiveFocus();
                                }
                            }
                            Keys.onReturnPressed: wlanMenu.submitPassword(text)
                            Keys.onEnterPressed: wlanMenu.submitPassword(text)
                            Keys.onEscapePressed: event => {
                                wlanMenu.pendingSsid = "";
                                event.accepted = true;
                            }
                        }

                        Text {
                            text: "Verbinden"
                            color: "#a6e3a1"
                            font.pixelSize: 12
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wlanMenu.submitPassword(pwField.text)
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Text {
                    visible: wlanMenu.activeSsid !== ""
                    text: "Verbindung trennen"
                    color: "#f38ba8"
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wlanMenu.disconnectWifi()
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Verbindungen bearbeiten …"
                    color: "#89b4fa"
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["nm-connection-editor"]);
                            wlanMenu.close();
                        }
                    }
                }
            }
        }
    }
}
