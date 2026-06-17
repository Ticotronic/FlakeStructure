import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: option
    property string icon: ""
    property string label: ""
    signal clicked()

    spacing: 12

    Rectangle {
        Layout.preferredWidth: 96
        Layout.preferredHeight: 96
        radius: 16
        color: optionMouseArea.containsMouse ? "#ffffff22" : "#ffffff11"
        border.color: "#ffffff33"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: option.icon
            font.family: "Symbols Nerd Font"
            font.pixelSize: 36
            color: "#cdd6f4"
        }

        MouseArea {
            id: optionMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: option.clicked()
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: option.label
        color: "#cdd6f4"
        font.pixelSize: 14
    }
}