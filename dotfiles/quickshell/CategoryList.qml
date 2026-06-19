import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Column {
    id: catList
    spacing: 0

    Item {
        width: parent.width; 
        height: 28
    
        Text {
            text: "KATEGORIEN"
            color: "#45475a"
            font.pixelSize: 10
            font.letterSpacing: 1
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter 
        }
    }

    Repeater {
        model: Object.keys(LauncherMenu.categoryIcons)
        delegate: Rectangle {
            width: parent.width
            height: 34
            color: LauncherMenu.activeCategory === modelData ? "#313244" : "transparent"
            border.color: "transparent"

            Rectangle {
                width: 2; height: parent.height
                color: LauncherMenu.activeCategory === modelData ? "#89b4fa" : "transparent"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 8

                IconImage {
                    source: LauncherMenu.categoryIcons[modelData]
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    implicitWidth: 16
                    implicitHeight: 16
                }

                Text {
                    text: modelData
                    color: LauncherMenu.activeCategory === modelData ? "#cdd6f4" : "#6c7086"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: LauncherMenu.activeCategory = modelData
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 9  // 1px Linie + 4px oben + 4px unten
        color: "transparent"

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: 1
            color: "#313244"
        }
    }

    Item {
        width: parent.width
        height: 28
        
        Text {
            text: "EIGENE"
            color: "#45475a"
            font.pixelSize: 10
            font.letterSpacing: 1
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Repeater {
        model: ["SSH-Hosts", "Favoriten", "Skripte"]
        delegate: Rectangle {
            width: parent.width
            height: 34
            color: LauncherMenu.activeCategory === modelData ? "#313244" : "transparent"

            Rectangle {
                width: 2; height: parent.height
                color: LauncherMenu.activeCategory === modelData ? "#89b4fa" : "transparent"
            }

            Text {
                text: modelData
                color: LauncherMenu.activeCategory === modelData ? "#cdd6f4" : "#6c7086"
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 30
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: LauncherMenu.activeCategory = modelData
            }
        }
    }
}