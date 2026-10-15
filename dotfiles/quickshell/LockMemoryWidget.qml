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
            visible: card.asset !== null && card.asset.type === "VIDEO"
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
    }
}
