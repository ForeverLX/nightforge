import QtQuick
import QtQml

import "../services"

Item {
    id: pill
    property string iconSvg:     ""
    property string iconText:    ""
    property string valueText:   ""
    property color  accentColor: "#8B6FEF"
    property bool   _open:       false
    signal clicked()
    signal rightClicked()
    signal wheeled(var event)

    MatugenColors { id: mocha }

    height: 19
    width: _open ? (iconWidth + lbl.implicitWidth + 8) : iconWidth
    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    scale: pill._open ? 1.08 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

    // Glass background
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: parent._open
            ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.4)
            : "transparent"
        border.width: parent._open ? 1 : 0
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    // Nerd Font icon (preferred)
    Text {
        id: nerdIcon
        visible: pill.iconText !== ""
        text: pill.iconText
        color: pill._open ? pill.accentColor : mocha.subtext0
        anchors.left: parent.left; anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        font.family: "Iosevka Nerd Font"; font.pixelSize: 14
    }

    // SVG icon fallback
    Image {
        id: ico
        visible: pill.iconText === "" && pill.iconSvg !== ""
        width: 17; height: 17
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        smooth: true
        source: pill.iconSvg !== ""
            ? "data:image/svg+xml;utf8," + pill.iconSvg.replace(/currentColor/g,
                pill._open ? encodeColor(pill.accentColor) : encodeColor(mocha.subtext0))
            : ""
    }

    property int iconWidth: pill.iconText !== "" ? 16 : (pill.iconSvg !== "" ? 20 : 0)

    Text {
        id: lbl
        text: pill.valueText
        color: pill.accentColor
        opacity: pill._open ? 1 : 0
        anchors.left: nerdIcon.visible ? nerdIcon.right : ico.right; anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        font.family: "Google Sans"; font.pixelSize: 14; font.weight: Font.Medium
        Behavior on opacity { NumberAnimation { duration: 110 } }
    }

    MouseArea {
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: pill._open = true
        onExited:  pill._open = false
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) pill.rightClicked()
            else pill.clicked()
        }
        onWheel: function(event) { event.accepted = true; pill.wheeled(event) }
    }

    function encodeColor(c) {
        var r = Math.round(c.r * 255).toString(16).padStart(2, '0')
        var g = Math.round(c.g * 255).toString(16).padStart(2, '0')
        var b = Math.round(c.b * 255).toString(16).padStart(2, '0')
        return "%23" + r + g + b
    }
}
