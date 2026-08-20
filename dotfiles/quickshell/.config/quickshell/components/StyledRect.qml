// NightForge StyledRect — ported from caelestia
// Animated, theme-aware rectangle
import QtQuick

Rectangle {
    id: root

    color: "transparent"

    Behavior on color {
        ColorAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    Behavior on border.color {
        ColorAnimation { duration: 250; easing.type: Easing.OutCubic }
    }
}
