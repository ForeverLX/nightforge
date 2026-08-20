// NightForge MaterialIcon — ported from caelestia
// Icon component using Nerd Font symbols
import QtQuick
import QtQuick.Controls

StyledText {
    property real iconSize: 18

    font.family: "Symbols Nerd Font"
    font.pixelSize: iconSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    themedColor: "#e6e3d5"
}
