import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Item {
    id: clockWidget
    implicitWidth: clockText.implicitWidth
    implicitHeight: clockText.implicitHeight

    // Von Bar.qml gesetzt: das PanelWindow, unter dem der Kalender erscheinen soll
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

    Text {
        id: clockText
        anchors.centerIn: parent
        text: clockWidget.currentText
        color: "#cdd6f4"
        font.pixelSize: 14
        font.family: "Symbols Nerd Font"
    }

    MouseArea {
        id: clockMouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: clockWidget.calendarOpen = !clockWidget.calendarOpen
    }

    // ==========================================
    // Kalender-Popup unterhalb der Bar
    // ==========================================
    PopupWindow {
        id: calendarPopup
        visible: clockWidget.calendarOpen

        // Ankerpunkt: horizontale Mitte des ClockWidget als Punkt (Breite 0),
        // damit der Popup unabhängig von seiner eigenen Breite exakt zentriert wird
        anchor.window: clockWidget.barWindow
        anchor.rect: Qt.rect(
            clockWidget.mapToItem(null, 0, 0).x + clockWidget.width / 2 - calendarPopup.implicitWidth / 2,
            clockWidget.barWindow ? clockWidget.barWindow.height : 0,
            0,
            0
        )
        anchor.edges: Edges.Top

        // Doppelte Größe gegenüber dem ursprünglichen Stand
        implicitWidth: 460
        implicitHeight: 420
        color: "transparent"

        // Aktuell angezeigter Monat/Jahr (0-11 wie bei JS Date)
        property int viewMonth: new Date().getMonth()
        property int viewYear: new Date().getFullYear()

        // Beim Öffnen immer wieder auf den aktuellen Monat zurückspringen
        onVisibleChanged: {
            if (visible) {
                viewMonth = new Date().getMonth();
                viewYear = new Date().getFullYear();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            radius: 12
            border.color: "#313244"
            border.width: 1

            ColumnLayout {
                id: calendarColumn
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                // Monats-Navigation
                RowLayout {
                    Layout.fillWidth: true

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 6
                        color: prevMonthArea.containsMouse ? "#313244" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            color: "#cdd6f4"
                            font.pixelSize: 22
                        }

                        MouseArea {
                            id: prevMonthArea
                            anchors.fill: parent
                            hoverEnabled: true
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

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale("de_DE").monthName(calendarPopup.viewMonth, Locale.LongFormat) + " " + calendarPopup.viewYear
                        color: "#cdd6f4"
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 6
                        color: nextMonthArea.containsMouse ? "#313244" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "›"
                            color: "#cdd6f4"
                            font.pixelSize: 22
                        }

                        MouseArea {
                            id: nextMonthArea
                            anchors.fill: parent
                            hoverEnabled: true
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

                // Wochentags-Kopfzeile
                DayOfWeekRow {
                    Layout.fillWidth: true
                    locale: Qt.locale("de_DE")

                    delegate: Text {
                        required property string shortName
                        text: shortName
                        color: "#6c7086"
                        font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Tage-Grid
                MonthGrid {
                    id: monthGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    month: calendarPopup.viewMonth
                    year: calendarPopup.viewYear
                    locale: Qt.locale("de_DE")

                    delegate: Rectangle {
                        id: dayCell
                        required property var model
                        readonly property bool isCurrentMonth: model.month === monthGrid.month
                        readonly property string dateKey: Qt.formatDate(model.date, "yyyy-MM-dd")
                        readonly property bool hasEvents: CalendarEvents.datesWithEvents[dateKey] === true

                        color: model.today ? "#a6e3a1" : (dayMouseArea.containsMouse ? "#313244" : "transparent")
                        radius: 6
                        opacity: isCurrentMonth ? 1 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: dayCell.model.day
                            color: dayCell.model.today ? "#11111b" : "#cdd6f4"
                            font.pixelSize: 16
                            font.bold: dayCell.model.today
                        }

                        // Kleiner Marker-Punkt für Tage mit Terminen
                        Rectangle {
                            visible: dayCell.hasEvents
                            width: 4; height: 4; radius: 2
                            color: dayCell.model.today ? "#11111b" : "#f9e2af"
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                        }

                        MouseArea {
                            id: dayMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (clockWidget.barWindow) {
                                    CalendarEvents.openForDate(dayCell.dateKey, clockWidget.barWindow.screen);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
