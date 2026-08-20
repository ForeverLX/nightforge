// Music widget control button
import QtQuick.Controls
import QtQuick
import Quickshell

AbstractButton {
    id: btn
    property string cmd: ""
    property int btnW: 44; property int btnH: 44; property int btnR: 22; property int btnFs: 20
    property color btnColor: "#cdd6f4"
    property color btnBg: "#45475a"
    property color btnAccent: "#cba6f7"
    property color btnOutline: "#6c7086"

    implicitWidth: btnW; implicitHeight: btnH

    background: Rectangle {
        radius: btn.btnR
        color: btn.down ? Qt.rgba(btn.btnAccent.r, btn.btnAccent.g, btn.btnAccent.b, 0.3)
                        : Qt.rgba(btn.btnBg.r, btn.btnBg.g, btn.btnBg.b, 0.9)
        border.width: 1; border.color: Qt.rgba(btn.btnOutline.r, btn.btnOutline.g, btn.btnOutline.b, 0.15)
    }
    contentItem: Text {
        text: btn.text; color: btn.btnColor; font.pixelSize: btn.btnFs
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    onClicked: Quickshell.execDetached(["bash", "-c", btn.cmd])
}
