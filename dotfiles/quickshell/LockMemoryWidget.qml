import QtQuick

// Immich-Erinnerungen unten links auf dem Sperrbildschirm.
//
//  - Vorschau-Leiste: bis zu 5 Kacheln ("Vor einem Jahr", ...) mit dem ersten Bild
//  - Klick auf eine Kachel: dieses Jahr als groessere Karte
//  - Karte, rechte Haelfte: naechstes Bild desselben Jahres, linke Haelfte: vorheriges
//  - Klick neben die Anzeige: zurueck zur Leiste (siehe LockSurface.qml)
// Ohne erreichbares Immich (memories.available == false) ist alles ausgeblendet.
Item {
    id: root

    required property var memories
    property real u: 1

    readonly property bool expanded: memories.currentItem !== null
    readonly property real tileW: 150 * u
    readonly property real tileH: 112 * u
    readonly property real gap: 14 * u
    readonly property real cardW: 500 * u
    readonly property real photoH: 375 * u

    width: Math.max(strip.width, card.width)
    height: Math.max(strip.height, card.height)

    opacity: memories.available ? 1.0 : 0.0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    // ---- Vorschau-Leiste ----
    Column {
        id: strip
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        spacing: 10 * root.u
        enabled: !root.expanded
        opacity: root.expanded ? 0.0 : 1.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Text {
            text: "An diesem Tag"
            color: "#a6adc8"
            font.pixelSize: 19 * root.u
            leftPadding: 4 * root.u
        }

        Row {
            spacing: root.gap

            Repeater {
                model: root.memories.items

                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property string firstId: modelData.assets[0].id

                    width: root.tileW
                    height: root.tileH + 30 * root.u

                    LockPhoto {
                        width: root.tileW
                        height: root.tileH
                        radius: 14 * root.u
                        u: root.u
                        source: root.memories.fileUrl(tile.firstId)
                        failed: root.memories.loadState(tile.firstId) === 2
                    }

                    Text {
                        y: root.tileH + 6 * root.u
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: tile.modelData.label
                        color: "#cdd6f4"
                        font.pixelSize: 17 * root.u
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.memories.open(tile.index)
                    }
                }
            }
        }
    }

    // ---- Grosse Karte ----
    Item {
        id: card
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: root.cardW
        height: root.photoH + 46 * root.u
        transformOrigin: Item.BottomLeft
        enabled: root.expanded
        opacity: root.expanded ? 1.0 : 0.0
        scale: root.expanded ? 1.0 : 0.9
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        readonly property var asset: root.memories.currentAsset
        readonly property int count: root.memories.currentItem ? root.memories.currentItem.assets.length : 0
        readonly property bool isVideo: asset !== null && asset.type === "VIDEO"
        readonly property int videoState: isVideo ? root.memories.videoState(asset.id) : 0
        property bool soundOn: false

        // Videos starten stumm; Ton nur per Knopf oben rechts
        onAssetChanged: soundOn = false

        // Hinweistext in der Bildmitte, solange das Video nicht laeuft
        readonly property string videoNote: {
            if (!isVideo)
                return "";
            if (videoLoader.status === Loader.Error)
                return "Videowiedergabe nicht verfügbar (QtMultimedia fehlt in Quickshell)";
            if (videoState === 2)
                return "Video nicht ladbar";
            if (videoLoader.item && videoLoader.item.failed)
                return "Video nicht abspielbar";
            if (videoState === 0)
                return "Video wird geladen …";
            return "";
        }

        LockPhoto {
            id: bigPhoto
            width: parent.width
            height: root.photoH
            radius: 18 * root.u
            u: root.u
            fillMode: Image.PreserveAspectFit
            backdrop: Qt.rgba(0.07, 0.07, 0.11, 0.85)
            source: card.asset ? root.memories.fileUrl(card.asset.id) : ""
            failed: card.asset ? root.memories.loadState(card.asset.id) === 2 : false
        }

        // Video: erst wenn die Datei komplett geladen ist. Der Loader haelt den
        // Player (und QtMultimedia) aus dem Rest heraus, siehe LockVideo.qml.
        Loader {
            id: videoLoader
            anchors.fill: bigPhoto
            active: card.isVideo && card.videoState === 1
            source: Qt.resolvedUrl("LockVideo.qml")
            opacity: item && item.playing ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            onStatusChanged: {
                if (status === Loader.Error)
                    console.warn("Sperrbildschirm-Erinnerungen: LockVideo.qml nicht ladbar (QtMultimedia installiert?)");
            }
        }
        Binding {
            target: videoLoader.item
            property: "source"
            value: card.asset ? root.memories.videoUrl(card.asset.id) : ""
            when: videoLoader.item !== null
        }
        Binding {
            target: videoLoader.item
            property: "sound"
            value: card.soundOn
            when: videoLoader.item !== null
        }

        Text {
            anchors.centerIn: bigPhoto
            width: bigPhoto.width - 40 * root.u
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: card.videoNote !== ""
            text: card.videoNote
            color: Qt.rgba(1, 1, 1, 0.85)
            font.pixelSize: 18 * root.u
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.6)
        }

        // Fortschrittsbalken
        Rectangle {
            anchors.left: bigPhoto.left
            anchors.bottom: bigPhoto.bottom
            height: 4 * root.u
            width: bigPhoto.width * (videoLoader.item ? videoLoader.item.progress : 0)
            visible: videoLoader.item !== null && videoLoader.item.playing
            color: Qt.rgba(1, 1, 1, 0.7)
        }

        // Pfeile: zeigen, wo vor und zurueck geklickt wird
        Text {
            anchors.left: bigPhoto.left
            anchors.leftMargin: 14 * root.u
            anchors.verticalCenter: bigPhoto.verticalCenter
            visible: root.memories.pos > 0
            text: "‹"
            color: Qt.rgba(1, 1, 1, 0.75)
            font.pixelSize: 54 * root.u
        }
        Text {
            anchors.right: bigPhoto.right
            anchors.rightMargin: 14 * root.u
            anchors.verticalCenter: bigPhoto.verticalCenter
            visible: root.memories.pos < card.count - 1
            text: "›"
            color: Qt.rgba(1, 1, 1, 0.75)
            font.pixelSize: 54 * root.u
        }

        // Video-Hinweis (es wird nur das Standbild gezeigt)
        Text {
            anchors.left: bigPhoto.left
            anchors.top: bigPhoto.top
            anchors.margins: 16 * root.u
            visible: card.isVideo && !(videoLoader.item && videoLoader.item.playing)
            text: String.fromCodePoint(0xF040D) + "  Video"
            font.family: "Symbols Nerd Font"
            color: Qt.rgba(1, 1, 1, 0.85)
            font.pixelSize: 20 * root.u
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 6 * root.u
            y: root.photoH + 12 * root.u
            text: root.memories.currentItem
                ? root.memories.currentItem.label + "  ·  " + root.memories.currentItem.year : ""
            color: "#cdd6f4"
            font.pixelSize: 20 * root.u
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 6 * root.u
            y: root.photoH + 12 * root.u
            text: (root.memories.pos + 1) + " / " + card.count
            color: "#a6adc8"
            font.pixelSize: 20 * root.u
        }

        // Rechte Haelfte = weiter, linke Haelfte = zurueck (nur auf dem Bild)
        MouseArea {
            anchors.fill: bigPhoto
            onClicked: mouse => {
                if (mouse.x > width / 2)
                    root.memories.next();
                else
                    root.memories.prev();
            }
        }

        // Ton an/aus (liegt ueber der Blaetter-Flaeche)
        Rectangle {
            id: soundButton
            anchors.top: bigPhoto.top
            anchors.right: bigPhoto.right
            anchors.margins: 14 * root.u
            width: 40 * root.u
            height: width
            radius: width / 2
            visible: videoLoader.item !== null && !videoLoader.item.failed
            color: Qt.rgba(0, 0, 0, 0.45)
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.35)

            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(card.soundOn ? 0xF057E : 0xF0581)
                font.family: "Symbols Nerd Font"
                font.pixelSize: 22 * root.u
                color: "#cdd6f4"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: card.soundOn = !card.soundOn
            }
        }
    }
}
