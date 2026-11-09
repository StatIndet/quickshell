import QtQuick
import qs.Common
import qs.Services

QtObject {
    required property real clockLength
    required property bool recordingActive
    required property bool audioActive
    required property bool toolsActive
    required property bool hubActive
    required property bool lyricsActive
    required property bool expandedActive
    required property bool volumeActive
    required property bool notificationsActive
    required property bool collapsedHovered
    required property real recordingWidth
    required property real recordingHeight
    required property real toolsWidth
    required property real toolsHeight
    required property real hubWidth
    required property real hubHeight
    required property real lyricsWidth
    required property real lyricsHeight
    required property real notificationsWidth
    required property real notificationsHeight
    readonly property real audioWidth: KeystoneMotion.verticalAudioRecordingWidth
    readonly property real audioHeight: KeystoneMotion.verticalAudioRecordingHeight
    property real expandedWidth: 440
    property real expandedHeight: 228
    readonly property real volumeWidth: 64
    readonly property real volumeHeight: 320
    readonly property real collapsedWidth: PersonalizationConfig.keystoneThickness
    readonly property real collapsedHeight: clockLength
    readonly property real attachedRecordingWidth: collapsedWidth
    readonly property real attachedRecordingHeight: collapsedHeight
    readonly property real targetWidth: recordingActive ? recordingWidth : audioActive ? audioWidth :
                                                                                         toolsActive
                                                                                         ? toolsWidth :
                                                                                           hubActive
                                                                                           ? hubWidth :
                                                                                             lyricsActive
                                                                                             ? lyricsWidth :
                                                                                               expandedActive
                                                                                               ? expandedWidth :
                                                                                                 volumeActive
                                                                                                 ? volumeWidth :
                                                                                                   notificationsActive
                                                                                                   ? notificationsWidth :
                                                                                                     collapsedWidth
                                                                                                     + (collapsedHovered
                                                                                                        ? 16 : 0)
    readonly property real targetHeight: recordingActive ? recordingHeight : audioActive ? audioHeight :
                                                                                           toolsActive
                                                                                           ? toolsHeight :
                                                                                             hubActive
                                                                                             ? hubHeight :
                                                                                               lyricsActive
                                                                                               ? lyricsHeight :
                                                                                                 expandedActive
                                                                                                 ? expandedHeight :
                                                                                                   volumeActive
                                                                                                   ? volumeHeight :
                                                                                                     notificationsActive
                                                                                                     ? notificationsHeight :
                                                                                                       collapsedHeight
                                                                                                       + (collapsedHovered
                                                                                                          ? 6 : 0)
}
