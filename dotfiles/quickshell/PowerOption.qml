import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

ColumnLayout {
    id: option
    property string icon: ""
    property string label: ""
    property real size: 96
    signal clicked()

    spacing: size * 0.12

    Rectangle {
        id: optionBg
        Layout.preferredWidth: option.size
        Layout.preferredHeight: option.size
        radius: option.size * 0.16
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
            font.pixelSize: option.size * 0.38
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
        font.pixelSize: option.size * 0.15

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.6
            shadowBlur: 0.4
        }
    }
}