import QtQuick

Item {
    id: clockWidget
    implicitWidth: clockText.implicitWidth
    implicitHeight: clockText.implicitHeight

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
}