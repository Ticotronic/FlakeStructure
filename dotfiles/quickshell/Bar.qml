import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {
    id: topBar
    color: "#1e1e2e"
    implicitHeight: 32
    anchors { top: true; left: true; right: true }

    property var filteredWorkspaces: {
        var _dep = workspaceList;
        var result = [];
        for (var i = 0; i < _dep.length; i++) {
            if (_dep[i].output === screen.name) {
                result.push(_dep[i]);
            }
        }
        return result;
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 12

        // Launcher
        Rectangle {
            width: 32; Layout.fillHeight: true; color: "#89b4fa"; radius: 4
            Text { text: "󱓞"; font.family: "Symbols Nerd Font"; anchors.centerIn: parent }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["fuzzel"])
            }
        }

        Workspaces {
            Layout.fillHeight: true
            workspaces: filteredWorkspaces
        }

        // Trennlinie
        Rectangle {
            width: 1; Layout.fillHeight: true
            color: "#313244"
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        SessionSlots {
            Layout.fillHeight: true
        }

        Item { Layout.fillWidth: true }

        StatusIcons {}

        TrayArea {
            Layout.fillHeight: true
            barWindow: topBar
        }
    }
}