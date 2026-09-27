import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Item {
    id: clockWidget
    property var barWindow: null
    property bool calendarOpen: false

    readonly property var weekdayShort: ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

    function formatNow() {
        var now = new Date();
        var day = weekdayShort[now.getDay()];
        var rest = Qt.formatDateTime(now, "dd.MM.yyyy   HH:mm");
        return day + ", " + rest;
    }

    property string currentText: formatNow()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockWidget.currentText = clockWidget.formatNow()
    }

    implicitWidth: clockText.implicitWidth + 16
    implicitHeight: clockText.implicitHeight

    Text {
        id: clockText
        anchors.centerIn: parent
        text: clockWidget.currentText
        color: "#cdd6f4"
        font.pixelSize: 14
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: clockWidget.calendarOpen = !clockWidget.calendarOpen
    }

    PopupWindow {
        id: calendarPopup
        visible: clockWidget.calendarOpen

        anchor.window: clockWidget.barWindow
        anchor.rect: Qt.rect(
            clockWidget.mapToItem(null, 0, 0).x + clockWidget.width / 2 - calendarPopup.implicitWidth / 2,
            clockWidget.barWindow ? clockWidget.barWindow.height : 0,
            0, 0
        )
        anchor.edges: Edges.Top

        implicitWidth: 460
        implicitHeight: 420

        property int viewMonth: new Date().getMonth()
        property int viewYear: new Date().getFullYear()

        onVisibleChanged: {
            if (visible) {
                viewMonth = new Date().getMonth();
                viewYear = new Date().getFullYear();
                NextcloudCalDAV.fetchNow();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            border.color: "#313244"
            border.width: 1
            radius: 8

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "‹"
                        color: "#cdd6f4"
                        font.pixelSize: 20
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (calendarPopup.viewMonth === 0) {
                                    calendarPopup.viewMonth = 11;
                                    calendarPopup.viewYear -= 1;
                                } else {
                                    calendarPopup.viewMonth -= 1;
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: Qt.locale("de_DE").standaloneMonthName(calendarPopup.viewMonth) + " " + calendarPopup.viewYear
                        color: "#cdd6f4"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "›"
                        color: "#cdd6f4"
                        font.pixelSize: 20
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (calendarPopup.viewMonth === 11) {
                                    calendarPopup.viewMonth = 0;
                                    calendarPopup.viewYear += 1;
                                } else {
                                    calendarPopup.viewMonth += 1;
                                }
                            }
                        }
                    }
                }

                DayOfWeekRow {
                    Layout.fillWidth: true
                    locale: Qt.locale("de_DE")
                    delegate: Text {
                        text: model.shortName
                        color: "#a6adc8"
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 12
                    }
                }

                MonthGrid {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    month: calendarPopup.viewMonth
                    year: calendarPopup.viewYear
                    locale: Qt.locale("de_DE")

                    delegate: Rectangle {
                        id: dayCell
                        readonly property string dateKey: Qt.formatDate(model.date, "yyyy-MM-dd")
                        readonly property var dayEvents: CalendarEvents.eventsForDate(dateKey)
                        readonly property bool hasLocalEvents: dayEvents.some(function (e) { return e.source === "local"; })
                        readonly property bool hasRemoteEvents: dayEvents.some(function (e) { return e.source === "nextcloud"; })
                        readonly property bool isToday: dateKey === Qt.formatDate(new Date(), "yyyy-MM-dd")

                        width: grid.width / 7
                        height: grid.height / 6
                        color: isToday ? "#313244" : "transparent"
                        radius: 4

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: model.day
                                color: model.month === calendarPopup.viewMonth ? "#cdd6f4" : "#585b70"
                                font.bold: dayCell.isToday
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 3
                                Rectangle {
                                    width: 5; height: 5; radius: 2.5
                                    color: "#f9e2af"
                                    visible: dayCell.hasLocalEvents
                                }
                                Rectangle {
                                    width: 5; height: 5; radius: 2.5
                                    color: "#74c7ec"
                                    visible: dayCell.hasRemoteEvents
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: CalendarEvents.openForDate(dayCell.dateKey, clockWidget.barWindow.screen)
                        }
                    }
                }
            }
        }
    }
}
