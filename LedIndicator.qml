import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
    id: indicator

    required property color ledColor
    property color borderColor: Qt.white
    property int size: Style.space(12)

    width: size
    height: size
    radius: size / 2
    color: "transparent"
    border.color: borderColor
    border.width: 1

    Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(2)
        radius: Style.space(4)
        visible: indicator.ledColor !== indicator.borderColor
        color: indicator.ledColor
    }
}
