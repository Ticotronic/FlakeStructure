import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 16

    Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: wlanStatus }
    Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: "󰁹 " + batStatus }
    Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: "󰍛 " + ramStatus }
    Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: "󰘚 " + cpuStatus }
}