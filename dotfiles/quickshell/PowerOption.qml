import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

ColumnLayout {
    id: option
    property string icon: ""
    property string label: ""
    signal clicked()

    spacing: 12

    Rectangle {
        id: optionBg
        Layout.preferredWidth: 96
        Layout.preferredHeight: 96
        radius: 16
        color: optionMouseArea.containsMouse 
            ? Qt.rgba(1, 1, 1, 0.18)
            : Qt.rgba(1, 1, 1, 0.10)
        border.color: Qt.rgba(1, 1, 1, 0.35)
        border.width: 1.5

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.4
            shadowBlur: 0.6
            shadowVerticalOffset: 2
        }

        Text {
            anchors.centerIn: parent
            text: option.icon
            font.family: "Symbols Nerd Font"
            font.pixelSize: 36
            color: "#ffffff"

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.6
                shadowBlur: 0.4
            }
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
        color: "#ffffff"
        font.pixelSize: 14

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.6
            shadowBlur: 0.4
        }
    }
}