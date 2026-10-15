import QtQuick
import QtMultimedia

// Video-Player fuer die Immich-Erinnerungen. Absichtlich eine eigene Datei, die
// nur per Loader geladen wird (LockMemoryWidget.qml): Fehlt QtMultimedia in
// Quickshell, schlaegt nur dieser Loader fehl, der Sperrbildschirm bleibt heil.
Item {
    id: root

    property url source: ""
    property bool sound: false
    readonly property bool failed: player.error !== MediaPlayer.NoError
    readonly property string errorText: player.errorString
    readonly property real progress: player.duration > 0 ? player.position / player.duration : 0
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState

    MediaPlayer {
        id: player
        source: root.source
        videoOutput: output
        audioOutput: AudioOutput {
            muted: !root.sound
        }
        loops: MediaPlayer.Infinite
        onSourceChanged: if (source.toString() !== "") play()
        Component.onCompleted: if (source.toString() !== "") play()
        onErrorOccurred: (error, errorString) => console.warn("Sperrbildschirm-Erinnerungen: Videofehler: " + errorString)
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }
}
