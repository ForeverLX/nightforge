// Caelestia-inspired StyledRect — animated, themed
import QtQuick

Rectangle {
    id: root

    property color themedColor: "#202018"
    property color themedBorder: "#939182"

    color: themedColor
    radius: 8

    Behavior on color {
        CAnim {}
    }

    Behavior on border.color {
        CAnim {}
    }
}
