import QtQuick
import QtQuick.Layouts

import "../services"

RowLayout {
    property string icon: ""
    property string label: ""
    property string textColor: ""
    property string accentColor: ""

    MatugenColors { id: mocha }

    spacing: 4

    Text {
        text: parent.icon
        font.pixelSize: 11
        color: parent.accentColor || mocha.text
    }

    Text {
        text: parent.label
        font.pixelSize: 11
        color: parent.textColor || mocha.subtext0
    }
}