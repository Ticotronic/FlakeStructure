import QtQuick
import QtQuick.Layouts
import Quickshell

Row {
    spacing: 6

    // 3 Slots, initial leer
    property var slots: [null, null, null]

    // Snapshot des aktuellen Zustands erstellen
    function captureSnapshot() {
        var snapshot = [];
        for (var i = 0; i < workspaceList.length; i++) {
            var ws = workspaceList[i];
            if (ws.is_active) {
                snapshot.push({
                    output:    ws.output,
                    wsIdx:     ws.idx,
                    windowId:  ws.active_window_id
                });
            }
        }
        return snapshot;
    }

    // Snapshot wiederherstellen
    function restoreSnapshot(snapshot) {
        for (var i = 0; i < snapshot.length; i++) {
            var entry = snapshot[i];
            Quickshell.execDetached([
                "niri", "msg", "action", "focus-workspace", String(entry.wsIdx)
            ]);
            if (entry.windowId !== null) {
                Quickshell.execDetached([
                    "niri", "msg", "action", "focus-window",
                    "--id", String(entry.windowId)
                ]);
            }
        }
    }

    Repeater {
        model: 3

        Rectangle {
            id: slotButton
            width: 28; height: 28
            anchors.verticalCenter: parent.verticalCenter
            radius: 4

            // Slot belegt = blau, leer = dunkelgrau
            color: slots[index] !== null ? "#89b4fa" : "#181825"
            border.color: slots[index] !== null ? "transparent" : "#45475a"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: index + 1
                color: slots[index] !== null ? "#11111b" : "#585b70"
                font.bold: slots[index] !== null
                font.pixelSize: 11
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                // Linksklick: Slot wiederherstellen (wenn belegt)
                // Rechtsklick: aktuellen Stand speichern
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        // Neues Array erzwingen damit QML die Änderung erkennt
                        var updated = [slots[0], slots[1], slots[2]];
                        updated[index] = captureSnapshot();
                        slots = updated;
                    } else if (slots[index] !== null) {
                        restoreSnapshot(slots[index]);
                    }
                }
            }
        }
    }
}