pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: powerMenu

    property bool visible: false
    property bool isClosing: false

    signal closeRequested()

    function show() {
        isClosing = false;
        visible = true;
    }

    function hide() {
        isClosing = true;
        closeRequested();
    }

    function hideImmediately() {
        visible = false;
        isClosing = false;
    }

    function shutdown() {
        hide();
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    function reboot() {
        hide();
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function suspend() {
        hide();
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function lock() {
        hide();
        Quickshell.execDetached(["swaylock"]);
    }
}