import QtQuick
import Quickshell.Widgets
import Quickshell

Column {
    id: appItem
    property var app: null
    spacing: 4
    width: 80

    signal activated()

    Rectangle {
        width: 56; height: 56
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 10
        color: itemMouseArea.containsMouse ? "#313244" : "transparent"
        border.color: itemMouseArea.containsMouse ? "#45475a" : "transparent"
        border.width: 1

        IconImage {
            source: appItem.app ? appItem.app.icon : ""
            width: 36; height: 36
            anchors.centerIn: parent
        }

        MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                LauncherMenu.hide();
                Quickshell.execDetached(appItem.app.exec.split(" "));
            }
        }
    }

    Text {
        text: appItem.app ? appItem.app.name : ""
        color: "#cdd6f4"
        font.pixelSize: 10
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        wrapMode: Text.WordWrap
        maximumLineCount: 2
    }
}