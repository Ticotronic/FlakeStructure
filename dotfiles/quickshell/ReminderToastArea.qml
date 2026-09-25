import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: toastWindow

    // Bewusst fest auf dem ersten Monitor statt dynamisch dem fokussierten
    // Monitor zu folgen – ein Screen-Wechsel an einem bereits sichtbaren
    // Layer-Shell-Fenster hat sich in diesem Setup als Absturzquelle
    // erwiesen (siehe Power-Menü Multi-GPU-Problem).
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    visible: toasts.length > 0
    color: "transparent"

    anchors { top: true; right: true }
    margins { top: 40; right: 12 }

    implicitWidth: 320
    implicitHeight: toastColumn.implicitHeight

    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: -1

    property var toasts: []  // [{ key, title, subtitle }]

    Connections {
        target: CalendarEvents
        function onReminderFired(evt) {
            var timeLabel = evt.startTime || "";
            var subtitle = (evt.location ? evt.location + " · " : "") + timeLabel;
            var key = evt.id + "-" + Date.now();

            var list = toastWindow.toasts.slice();
            list.push({ key: key, title: evt.title, subtitle: subtitle });
            toastWindow.toasts = list;

            toastTimerComponent.createObject(toastWindow, { toastKey: key });
        }
    }

    Component {
        id: toastTimerComponent
        Timer {
            property string toastKey: ""
            interval: 12000
            running: true
            onTriggered: {
                toastWindow.toasts = toastWindow.toasts.filter(function(t) { return t.key !== toastKey; });
                destroy();
            }
        }
    }

    ColumnLayout {
        id: toastColumn
        width: parent.width
        spacing: 8

        Repeater {
            model: toastWindow.toasts
            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: toastLayout.implicitHeight + 20
                radius: 10
                color: "#1e1e2e"
                border.color: "#89b4fa"
                border.width: 1

                ColumnLayout {
                    id: toastLayout
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "🔔 Termin-Erinnerung"
                            color: "#89b4fa"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Text {
                            text: "✕"
                            color: "#6c7086"
                            font.pixelSize: 11
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    toastWindow.toasts = toastWindow.toasts.filter(function(t) { return t.key !== modelData.key; });
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: "#cdd6f4"
                        font.pixelSize: 13
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.subtitle
                        color: "#a6adc8"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        visible: modelData.subtitle !== ""
                    }
                }
            }
        }
    }
}
