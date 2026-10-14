import QtQuick
import QtQuick.Effects
import Quickshell

// Oberflaeche des Sperrbildschirms fuer EINEN Monitor. Der gemeinsame Zustand
// (Passwort, Fehler, PAM) liegt in LockScreen.qml (ctx), damit alle Monitore
// dasselbe zeigen - die Tastatureingaben landen nur auf einem davon.
Rectangle {
    id: root

    required property var ctx
    property string screenName: ""

    color: "#1e1e2e"

    // Skalierungseinheit, damit es auf dem 4K- wie auf dem Full-HD-Bildschirm
    // aehnlich proportioniert aussieht
    readonly property real u: Math.max(height, 600) / 1080

    // ---- Hintergrund: verwischter Screenshot (von grim), sonst einfarbig ----
    Image {
        id: shot
        anchors.fill: parent
        visible: false          // nur Quelle fuer den Blur
        cache: false
        asynchronous: true
        fillMode: Image.Stretch
        source: root.screenName === "" ? "" :
            "file://" + root.ctx.captureDir + "/qs-lock-" + root.screenName + ".ppm"
    }

    MultiEffect {
        anchors.fill: parent
        source: shot
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        autoPaddingEnabled: false
        opacity: shot.status === Image.Ready ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    }

    // Toenung fuer die Lesbarkeit (passt zum Power-Menue)
    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
        opacity: shot.status === Image.Ready ? 0.65 : 0.0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
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
        y: parent.height * 0.18
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

    // ---- Benutzer, Passwortfeld, Statuszeile ----
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.56
        spacing: 22 * root.u

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Quickshell.env("USER") || ""
            color: "#cdd6f4"
            font.pixelSize: 26 * root.u
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
                anchors.leftMargin: 22 * root.u
                anchors.verticalCenter: parent.verticalCenter
                text: "󰌾"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 26 * root.u
                color: root.ctx.showFailure ? "#f38ba8" : "#cdd6f4"
            }

            Text {
                anchors.centerIn: parent
                visible: input.text.length === 0
                text: root.ctx.busy ? "Prüfe …" : "Passwort"
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
                onAccepted: root.ctx.tryUnlock()
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
            text: root.ctx.showFailure ? root.ctx.failureText
                : (root.ctx.capsLock ? "⇪  Feststelltaste ist aktiv" : "")
            color: root.ctx.showFailure ? "#f38ba8" : "#f9e2af"
            font.pixelSize: 20 * root.u
        }
    }
}
