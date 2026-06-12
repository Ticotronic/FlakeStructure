import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls

Row {
    spacing: 6




    // Fenstertitel anhand der ID nachschlagen
    function windowTitle(windowId) {
        if (windowId === null) return null;
        for (var i = 0; i < windowList.length; i++) {
            if (windowList[i].id === windowId) {
                // Titel kürzen falls zu lang
                var title = windowList[i].title;
                if (title.length > 40) {
                    title = title.substring(0, 37) + "...";
                }
                return title + " (" + windowList[i].app_id + ")";
            }
        }
        return "Fenster #" + windowId;
    }

    Repeater {
        model: 3

        Rectangle {
            id: slotButton
            width: 28; height: 28
            anchors.verticalCenter: parent.verticalCenter
            radius: 4

            // Slot belegt = blau, leer = dunkelgrau
            color: sessionSlots[index] !== null ? "#89b4fa" : "#181825"
            border.color: sessionSlots[index] !== null ? "transparent" : "#45475a"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: index + 1
                color: sessionSlots[index] !== null ? "#11111b" : "#585b70"
                font.bold: sessionSlots[index] !== null
                font.pixelSize: 11
            }

            MouseArea {
                id: slotMouseArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                // Linksklick: Slot wiederherstellen (wenn belegt)
                // Rechtsklick: aktuellen Stand speichern
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        // Neues Array erzwingen damit QML die Änderung erkennt
                        var updated = [sessionSlots[0], sessionSlots[1], sessionSlots[2]];
                        updated[index] = captureSnapshot();
                        sessionSlots = updated;
                    } else if (sessionSlots[index] !== null) {
                        restoreSnapshot(sessionSlots[index]);
                    }
                }
            }

            PopupWindow {
                id: slotTooltip
                visible: slotMouseArea.containsMouse

                // Position: unterhalb des Buttons
                anchor.window: topBar
                anchor.rect: Qt.rect(
                    slotButton.mapToItem(null, 0, 0).x,
                    topBar.height,
                    slotButton.width,
                    0
                )
                anchor.edges: Edges.Top

                implicitWidth: tooltipText.implicitWidth + 16
                implicitHeight: tooltipText.implicitHeight + 12
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: "#313244"
                    radius: 4
                    border.color: "#45475a"
                    border.width: 1

                    Text {
                        id: tooltipText
                        anchors.centerIn: parent
                        color: "#cdd6f4"
                        font.pixelSize: 12
                        text: {
                            if (sessionSlots[index] === null) {
                                return "Rechtsklick zum Speichern";
                            }
                            var lines = ["Slot " + (index + 1) + ":"];
                            for (var i = 0; i < sessionSlots[index].length; i++) {
                                var entry = sessionSlots[index][i];
                                var winInfo = entry.windowId !== null
                                    ? "\n    " + windowTitle(entry.windowId)
                                    : " (kein Fenster)";
                                lines.push(entry.output + " → Workspace " + entry.wsIdx + winInfo);
                            }
                            return lines.join("\n");
                        }
                    }
                }
            }
        }
    }
}