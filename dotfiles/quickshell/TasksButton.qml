import QtQuick
import Quickshell

// Taskbar-Button fuer das Aufgaben-Widget (Stufe 1: nur Anzeige).
// Farbe/Icon zeigen an, ob es ueberfaellige, unerledigte Aufgaben gibt.
Rectangle {
    id: tasksButton
    width: 32
    height: 28
    radius: 4

    property var barWindow: null
    property bool open: false

    readonly property string todayStr: {
        var d = new Date();
        return d.getFullYear() + "-" + (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1) + "-" + (d.getDate() < 10 ? "0" : "") + d.getDate();
    }

    readonly property bool hasOverdue: {
        var list = NextcloudTasksDAV.tasks;
        for (var i = 0; i < list.length; i++) {
            var t = list[i];
            if (!t.completed && t.dueDate && t.dueDate < tasksButton.todayStr) return true;
        }
        return false;
    }

    color: tasksButton.open ? "#313244" : "transparent"
    border.color: tasksButton.hasOverdue ? "#f38ba8" : "transparent"
    border.width: tasksButton.hasOverdue ? 1 : 0

    Text {
        anchors.centerIn: parent
        text: ""
        font.family: "Symbols Nerd Font"
        font.pixelSize: 15
        color: tasksButton.hasOverdue ? "#f38ba8" : "#cdd6f4"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            tasksButton.open = !tasksButton.open;
            if (tasksButton.open) NextcloudTasksDAV.fetchNow();
        }
    }

    TasksWidget {
        anchorWindow: tasksButton.barWindow
        anchorItem: tasksButton
        open: tasksButton.open
        onCloseRequested: tasksButton.open = false
    }
}
