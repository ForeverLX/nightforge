import QtQuick
import QtQuick.Layouts

import "../services"

Rectangle {
    id: slider
    property string icon: "󰕾"
    property string textColor: ""
    property string primaryColor: ""
    property string surfaceVariantColor: ""
    property int value: 50
    property var onChange: function(v) {}

    MatugenColors { id: mocha }

    height: 48
    radius: 8
    color: Qt.rgba((surfaceVariantColor || mocha.surface0).r, (surfaceVariantColor || mocha.surface0).g, (surfaceVariantColor || mocha.surface0).b, 0.4)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Text {
            text: slider.icon
            color: textColor || mocha.text
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 14
        }

        Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: surfaceVariantColor || mocha.surface0

            Rectangle {
                width: parent.width * (slider.value / 100)
                height: parent.height
                radius: 3
                color: primaryColor || mocha.mauve

                Behavior on width { NumberAnimation { duration: 100 } }
            }

            Rectangle {
                x: parent.width * (slider.value / 100) - 6
                y: -3
                width: 12
                height: 12
                radius: 6
                color: primaryColor || mocha.mauve
                border.width: 2
                border.color: textColor || mocha.text

                Behavior on x { NumberAnimation { duration: 100 } }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    var newVal = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                    slider.value = newVal
                    if (slider.onChange) slider.onChange(newVal)
                }
            }
        }

        Text {
            text: slider.value + "%"
            color: textColor || mocha.text
            font.pixelSize: 11
            font.family: "Google Sans"
            Layout.minimumWidth: 30
        }
    }
}
