import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 16

    Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: wlanStatus }
    // Fallback 100%, damit die Anzeige beim Start (bevor der erste
    // Messwert eintrifft) nicht fälschlich rot blinkt.
    BatteryIndicator { percent: isNaN(parseInt(batStatus)) ? 100 : parseInt(batStatus) }
    Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: "󰍛 " + ramStatus }
    Text { color: "#cdd6f4"; font.pixelSize: 14; font.family: "Symbols Nerd Font"; text: "󰘚 " + cpuStatus }
}