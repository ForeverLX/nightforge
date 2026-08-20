// Caelestia-inspired StyledText — animated, theme-aware
import QtQuick
import Quickshell

Text {
    id: root

    property bool animate: false
    property color themedColor: "#e6e3d5"

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: themedColor
    font.pixelSize: 13

    Behavior on color {
        CAnim {}
    }

    Behavior on text {
        enabled: root.animate
        SequentialAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 0; duration: 100 }
            PropertyAction {}
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
    }
}
