import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland

// Bluetooth-Menue, das beim Klick auf das Bluetooth-Icon in der Leiste
// aufgeht (StatusIcons.qml). Nutzt das Quickshell-Modul Quickshell.Bluetooth
// (BlueZ ueber D-Bus), kein bluetoothctl:
//   - Bluetooth an/aus
//   - Geraeteliste: verbunden zuerst, dann gekoppelte, dann neu gefundene
//   - Klick verbindet / trennt; ein neues Geraet wird erst gekoppelt und
//     danach verbunden
//   - "Entfernen" vergisst ein gekoppeltes Geraet
//   - Suche nach neuen Geraeten laeuft nur, solange das Menue offen ist
//
// Wie WlanMenu.qml ein eigenes Overlay-Fenster mit Klick-daneben-schliesst.
PanelWindow {
    id: btMenu

    property var barWindow: null
    property var anchorItem: null
    property bool open: false

    screen: barWindow ? barWindow.screen : null
    visible: open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // ---------- Zustand ----------
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter !== null && adapter.enabled

    // Geraete, die gerade verbunden sind (fuer die Leiste)
    readonly property var connectedDevices: adapter
        ? adapter.devices.values.filter(function (d) { return d.connected; })
        : []

    // Text fuer die Leiste: Icon + Name des verbundenen Geraets
    // ("Name +1" bei mehreren)
    readonly property string iconGlyph: !btMenu.powered ? "󰂲"
        : btMenu.connectedDevices.length > 0 ? "󰂱"
        : "󰂯"
    readonly property string labelText: {
        var list = btMenu.connectedDevices;
        if (list.length === 0) return btMenu.iconGlyph;
        var name = list[0].name;
        if (name.length > 18) name = name.substring(0, 17) + "…";
        return btMenu.iconGlyph + " " + name + (list.length > 1 ? " +" + (list.length - 1) : "");
    }

    property real panelX: 0
    readonly property int panelWidth: 340

    // Adresse eines Geraets, das nach erfolgreichem Koppeln verbunden werden soll
    property string connectAfterPair: ""

    function isAddressName(d) {
        return /^([0-9a-f]{2}[-:]){5}[0-9a-f]{2}$/i.test(d.name);
    }

    // Verbunden zuerst, dann gekoppelt, dann neu gefundene; innerhalb nach Name.
    // Namenlose Geraete (nur MAC-Adresse) werden ausgeblendet, solange sie
    // nicht gekoppelt oder verbunden sind.
    function sortedDevices() {
        if (!btMenu.adapter) return [];
        var list = btMenu.adapter.devices.values.filter(function (d) {
            return d.connected || d.paired || !btMenu.isAddressName(d);
        });
        function rank(d) { return d.connected ? 0 : (d.paired ? 1 : 2); }
        list.sort(function (a, b) {
            var r = rank(a) - rank(b);
            return r !== 0 ? r : a.name.localeCompare(b.name);
        });
        return list;
    }

    function show() {
        var ax = 0;
        var aw = 0;
        if (btMenu.anchorItem) {
            ax = btMenu.anchorItem.mapToItem(null, 0, 0).x;
            aw = btMenu.anchorItem.width;
        }
        var maxX = Math.max(8, (btMenu.barWindow ? btMenu.barWindow.width : 1920) - btMenu.panelWidth - 8);
        btMenu.panelX = Math.max(8, Math.min(maxX, ax + aw / 2 - btMenu.panelWidth / 2));
        btMenu.connectAfterPair = "";
        btMenu.open = true;
        if (btMenu.powered) btMenu.adapter.discovering = true;
    }

    function close() {
        btMenu.open = false;
        btMenu.connectAfterPair = "";
        // Suche nur waehrend das Menue offen ist (spart Strom)
        if (btMenu.adapter && btMenu.adapter.discovering) btMenu.adapter.discovering = false;
    }

    function toggle() {
        if (btMenu.open) btMenu.close();
        else btMenu.show();
    }

    function toggleAdapter() {
        if (!btMenu.adapter) return;
        btMenu.adapter.enabled = !btMenu.adapter.enabled;
    }

    function activate(dev) {
        if (dev.state === BluetoothDeviceState.Connecting
            || dev.state === BluetoothDeviceState.Disconnecting
            || dev.pairing) return;
        if (dev.connected) {
            dev.disconnect();
        } else if (dev.paired) {
            dev.connect();
        } else {
            btMenu.connectAfterPair = dev.address;
            dev.pair();
        }
    }

    // Suche starten, sobald Bluetooth bei offenem Menue eingeschaltet wird
    Connections {
        target: btMenu.adapter
        ignoreUnknownSignals: true
        function onEnabledChanged() {
            if (btMenu.open && btMenu.adapter && btMenu.adapter.enabled)
                btMenu.adapter.discovering = true;
        }
    }

    // ---------- UI ----------
    MouseArea {
        anchors.fill: parent
        onClicked: btMenu.close()
    }

    Rectangle {
        id: panel
        x: btMenu.panelX
        y: (btMenu.barWindow ? btMenu.barWindow.height : 32) + 4
        width: btMenu.panelWidth
        height: Math.min(content.implicitHeight + 24, Math.max(120, btMenu.height - y - 16))
        color: "#1e1e2e"
        border.color: "#313244"
        border.width: 1
        radius: 8
        focus: true

        Keys.onEscapePressed: btMenu.close()

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
                    text: "Bluetooth"
                    color: "#cdd6f4"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    visible: btMenu.powered
                    text: btMenu.adapter && btMenu.adapter.discovering ? "Suche läuft …" : "Suchen"
                    color: "#89b4fa"
                    font.pixelSize: 11
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btMenu.adapter.discovering = !btMenu.adapter.discovering
                    }
                }

                // An/Aus-Schalter
                Rectangle {
                    visible: btMenu.adapter !== null
                    width: 38
                    height: 20
                    radius: 10
                    color: btMenu.powered ? "#a6e3a1" : "#45475a"

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        y: 2
                        x: btMenu.powered ? parent.width - width - 2 : 2
                        color: "#1e1e2e"
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btMenu.toggleAdapter()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

            Text {
                Layout.fillWidth: true
                visible: btMenu.adapter === null
                text: "Kein Bluetooth-Adapter gefunden"
                color: "#6c7086"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                topPadding: 8
                bottomPadding: 8
            }

            Text {
                Layout.fillWidth: true
                visible: btMenu.adapter !== null && !btMenu.powered
                text: "Bluetooth ist ausgeschaltet"
                color: "#6c7086"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                topPadding: 8
                bottomPadding: 8
            }

            Text {
                Layout.fillWidth: true
                visible: btMenu.powered && deviceModel.values.length === 0
                text: "Keine Geräte gefunden"
                color: "#6c7086"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                topPadding: 8
                bottomPadding: 8
            }

            // ScriptModel behaelt Delegates bei, solange dasselbe Geraet in der
            // Liste bleibt (ein normales JS-Array-Modell wuerde bei jeder
            // Aenderung, z.B. neu gefundenes Geraet, alle Zeilen neu bauen).
            ScriptModel {
                id: deviceModel
                values: btMenu.powered ? btMenu.sortedDevices() : []
            }

            ListView {
                id: devList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Math.min(devList.contentHeight, 280)
                visible: btMenu.powered && deviceModel.values.length > 0
                clip: true
                spacing: 2
                model: deviceModel

                delegate: Item {
                    id: devDelegate
                    required property var modelData
                    readonly property var dev: modelData
                    width: ListView.view.width
                    height: 34

                    // Beim Entfernen einer Zeile (Geraet verschwindet aus dem
                    // ScriptModel) wird modelData kurz null, waehrend die
                    // Bindings noch einmal ausgewertet werden. Darum lesen die
                    // Kind-Elemente nur diese null-sicheren Werte und nicht
                    // direkt dev.
                    readonly property bool devConnected: dev ? dev.connected : false
                    readonly property bool devPaired: dev ? dev.paired : false
                    readonly property bool devPairing: dev ? dev.pairing : false
                    readonly property string devName: dev ? dev.name : ""
                    readonly property string statusLabel: {
                        var d = devDelegate.dev;
                        if (!d) return "";
                        if (d.pairing) return "Koppelt …";
                        if (d.state === BluetoothDeviceState.Connecting) return "Verbindet …";
                        if (d.state === BluetoothDeviceState.Disconnecting) return "Trennt …";
                        if (d.connected) return d.batteryAvailable ? Math.round(d.battery * 100) + "%" : "Verbunden";
                        if (d.paired) return "Gekoppelt";
                        return "";
                    }

                    // Nach erfolgreichem Koppeln direkt verbinden
                    Connections {
                        target: devDelegate.dev
                        ignoreUnknownSignals: true
                        function onPairedChanged() {
                            if (devDelegate.dev && devDelegate.dev.paired && btMenu.connectAfterPair === devDelegate.dev.address) {
                                btMenu.connectAfterPair = "";
                                devDelegate.dev.trusted = true;
                                devDelegate.dev.connect();
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: rowMouse.containsMouse ? "#313244" : "transparent"
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btMenu.activate(devDelegate.dev)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 14
                            text: devDelegate.devConnected ? "✓" : ""
                            color: "#a6e3a1"
                            font.pixelSize: 13
                        }

                        Text {
                            Layout.fillWidth: true
                            text: devDelegate.devName
                            color: devDelegate.devConnected ? "#a6e3a1" : "#cdd6f4"
                            font.pixelSize: 13
                            font.bold: devDelegate.devConnected
                            elide: Text.ElideRight
                        }

                        // Status / Akku
                        Text {
                            text: devDelegate.statusLabel
                            color: devDelegate.devConnected ? "#a6e3a1" : "#6c7086"
                            font.pixelSize: 11
                        }

                        // Gekoppeltes, nicht verbundenes Geraet vergessen
                        Text {
                            visible: devDelegate.devPaired && !devDelegate.devConnected
                            text: "Entfernen"
                            color: "#f38ba8"
                            font.pixelSize: 11
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devDelegate.dev.forget()
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                Text {
                    text: "Bluetooth-Einstellungen …"
                    color: "#89b4fa"
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["blueman-manager"]);
                            btMenu.close();
                        }
                    }
                }
            }
        }
    }
}
