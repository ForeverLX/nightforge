import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../services"

RowLayout {
    id: root

    property string icon: "🔊"
    property int value: 50
    property string textColor: ""
    property string primaryColor: ""
    property string surfaceVariantColor: ""
    property var onChange: function(v) {}

    MatugenColors { id: mocha }

    spacing: 8

    Text {
        text: root.icon
        font.pixelSize: 14
        color: mocha.subtext0
    }

    Slider {
        id: slider
        from: 0
        to: 100
        value: root.value
        Layout.fillWidth: true

        background: Rectangle {
            implicitHeight: 6
            radius: 3
            color: mocha.surface0
            Rectangle {
                width: parent.width * (slider.value / 100)
                height: parent.height
                radius: 3
                color: mocha.mauve
            }
        }

        handle: Rectangle {
            width: 14
            height: 14
            radius: 7
            color: mocha.text
            x: slider.visualPosition * (slider.width - width)
            anchors.verticalCenter: parent.verticalCenter
        }

        onMoved: {
            root.value = slider.value;
            if (root.onChange) root.onChange(Math.round(slider.value));
        }
    }

    Text {
        text: root.value + "%"
        font.pixelSize: 11
        color: mocha.text
        Layout.minimumWidth: 30
    }
}