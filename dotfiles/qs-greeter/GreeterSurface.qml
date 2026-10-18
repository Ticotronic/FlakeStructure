import QtQuick
import Quickshell

// Oberflaeche des Greeters fuer EINEN Monitor. Der gemeinsame Zustand (Passwort,
// Fehler, Benutzer, Sitzung) liegt in shell.qml (ctx); die Tastatureingaben landen
// nur auf einem Monitor, alle zeigen aber denselben Text.
Rectangle {
    id: root

    required property var ctx

    color: "#1e1e2e"

    // Skalierungseinheit, damit es auf dem 4K- wie auf dem Full-HD-Bildschirm
    // aehnlich proportioniert aussieht
    readonly property real u: Math.max(height, 600) / 1080

    // ---- Hintergrund: Bild oder Farbverlauf ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#24273a" }
            GradientStop { position: 1.0; color: "#181926" }
        }
    }

    Image {
        anchors.fill: parent
        visible: source !== ""
        source: root.ctx.wallpaper === "" ? "" : "file://" + root.ctx.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // Toenung fuer die Lesbarkeit
    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
        opacity: 0.35
    }

    // Klick irgendwo = Fokus auf das Passwortfeld
    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    // ---- Uhr und Datum ----
    Column {
        id: clockBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.14
        spacing: 6 * root.u

        property var now: new Date()

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clockBox.now = new Date()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clockBox.now, "HH:mm")
            color: "#cdd6f4"
            font.pixelSize: 150 * root.u
            font.weight: Font.Light
            renderType: Text.NativeRendering
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("de_DE").toString(clockBox.now, "dddd, d. MMMM yyyy")
            color: "#a6adc8"
            font.pixelSize: 30 * root.u
        }
    }

    // ---- Akku oben rechts (wie im Sperrbildschirm) ----
    Rectangle {
        visible: root.ctx.batPresent
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20 * root.u
        anchors.rightMargin: 24 * root.u
        width: batteryBox.width + 32 * root.u
        height: 29 * root.u
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, 0.35)

        Item {
            id: batteryBox
            anchors.centerIn: parent
            width: battery.implicitWidth * battery.scale
            height: battery.implicitHeight * battery.scale

            BatteryIndicator {
                id: battery
                scale: 1.0 * root.u
                transformOrigin: Item.TopLeft
                percent: root.ctx.batPercent
                charging: root.ctx.batCharging
            }
        }
    }

    // ---- Benutzer, Passwortfeld, Meldung ----
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.50
        spacing: 22 * root.u

        // Avatar (Anfangsbuchstabe); bei mehreren Benutzern wechselt ein Klick
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96 * root.u
            height: width
            radius: width / 2
            color: "#8aadf4"
            border.width: 3
            border.color: Qt.rgba(1, 1, 1, 0.45)

            Text {
                anchors.centerIn: parent
                text: root.ctx.currentUser.name.length > 0
                    ? root.ctx.currentUser.name.charAt(0).toUpperCase() : "?"
                color: "#1e1e2e"
                font.pixelSize: 48 * root.u
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.ctx.users.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.ctx.nextUser()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.ctx.currentUser.display || root.ctx.currentUser.name
            color: "#cdd6f4"
            font.pixelSize: 28 * root.u
        }

        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 400 * root.u
            height: 60 * root.u
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1.5
            border.color: root.ctx.showFailure ? "#f38ba8"
                : Qt.rgba(1, 1, 1, input.activeFocus ? 0.6 : 0.35)
            Behavior on border.color { ColorAnimation { duration: 150 } }

            // Wackeln bei falschem Passwort
            transform: Translate { id: shake }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shake; property: "x"; to: -14 * root.u; duration: 50 }
                NumberAnimation { target: shake; property: "x"; to: 14 * root.u; duration: 80 }
                NumberAnimation { target: shake; property: "x"; to: -10 * root.u; duration: 70 }
                NumberAnimation { target: shake; property: "x"; to: 10 * root.u; duration: 70 }
                NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
            }
            Connections {
                target: root.ctx
                function onFailCountChanged() { shakeAnim.restart(); }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 24 * root.u
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(0xF033E)   // Schloss (Nerd Font)
                font.family: "Symbols Nerd Font"
                font.pixelSize: 26 * root.u
                color: root.ctx.showFailure ? "#f38ba8" : "#cdd6f4"
            }

            Text {
                anchors.centerIn: parent
                visible: input.text.length === 0
                text: root.ctx.busy ? "Anmelden …" : "Passwort"
                color: "#a6adc8"
                font.pixelSize: 22 * root.u
            }

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 64 * root.u
                anchors.rightMargin: 64 * root.u
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                clip: true
                focus: true
                echoMode: TextInput.Password
                passwordCharacter: "●"
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                color: "#cdd6f4"
                font.pixelSize: 22 * root.u
                // readOnly statt enabled:false, damit der Fokus nicht verloren geht
                readOnly: root.ctx.busy

                onTextEdited: root.ctx.currentText = text
                onAccepted: root.ctx.submit()
                Keys.onEscapePressed: root.ctx.currentText = ""

                // Alle Monitore zeigen denselben Text
                Connections {
                    target: root.ctx
                    function onCurrentTextChanged() {
                        if (input.text !== root.ctx.currentText)
                            input.text = root.ctx.currentText;
                    }
                }

                Component.onCompleted: forceActiveFocus()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 26 * root.u
            text: !root.ctx.greetdAvailable ? "greetd nicht erreichbar"
                : (root.ctx.showFailure ? root.ctx.failureText
                : (root.ctx.capsLock ? "⇪  Feststelltaste ist aktiv" : ""))
            color: (root.ctx.showFailure || !root.ctx.greetdAvailable) ? "#f38ba8" : "#f9e2af"
            font.pixelSize: 20 * root.u
        }
    }

    // ---- Sitzung unten links (nur bei mehreren Sitzungen) ----
    Rectangle {
        visible: root.ctx.sessions.length > 1
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 40 * root.u
        anchors.bottomMargin: 40 * root.u
        width: sessionText.implicitWidth + 44 * root.u
        height: 48 * root.u
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, 0.35)

        Text {
            id: sessionText
            anchors.centerIn: parent
            text: "Sitzung:  " + (root.ctx.sessions.length > 0
                  ? root.ctx.sessions[root.ctx.sessionIndex].name : "")
            color: "#cdd6f4"
            font.pixelSize: 20 * root.u
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.ctx.nextSession()
        }
    }

    // ---- Strom unten rechts ----
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40 * root.u
        anchors.bottomMargin: 40 * root.u
        spacing: 14 * root.u

        Repeater {
            model: [
                { label: "Ruhezustand", cmd: ["systemctl", "suspend"] },
                { label: "Neustart", cmd: ["systemctl", "reboot"] },
                { label: "Ausschalten", cmd: ["systemctl", "poweroff"] }
            ]

            delegate: Rectangle {
                id: powerPill
                required property var modelData
                width: powerText.implicitWidth + 40 * root.u
                height: 48 * root.u
                radius: height / 2
                color: powerMouse.pressed ? Qt.rgba(1, 1, 1, 0.22)
                    : (powerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.10))
                border.width: 1.5
                border.color: Qt.rgba(1, 1, 1, 0.35)

                Text {
                    id: powerText
                    anchors.centerIn: parent
                    text: powerPill.modelData.label
                    color: "#cdd6f4"
                    font.pixelSize: 20 * root.u
                }

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(powerPill.modelData.cmd)
                }
            }
        }
    }
}
