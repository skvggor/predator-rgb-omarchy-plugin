import "Model.js" as Model
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.55)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property color ledColor: Model.hexToRgb(led.accent) ? ("#" + led.accent) : foreground

    moduleName: "skvggor.predator-rgb"
    ipcTarget: "skvggor.predator-rgb"
    manageIpc: false
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    onOpenedChanged: {
        if (opened) {
            led.refresh();
        }
    }

    Service {
        id: led

        settings: root.settings
    }

    IpcHandler {
        function refresh() : string {
            led.refresh();
            return "ok";
        }

        function apply() : string {
            led.apply();
            return "ok";
        }

        function status() : string {
            return JSON.stringify({
                "available": led.available,
                "applied": led.applied,
                "themeName": led.themeName,
                "accent": led.accent
            });
        }

        target: root.ipcTarget
    }

    component LedIndicator: Rectangle {
        id: indicator

        required property color ledColor
        property color borderColor: root.foreground
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

    BarIconButton {
        id: button

        anchors.fill: parent
        bar: root.bar
        tooltipText: !led.available ? "Acer Predator Helios Neo 16: keyboard not detected" : "Acer Predator Helios Neo 16: " + led.themeName + " (" + led.accent + ")"
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.MiddleButton)
                led.apply();
            else
                root.toggle();
        }

        iconComponent: Component {
            Item {
                LedIndicator {
                    anchors.centerIn: parent
                    ledColor: root.ledColor
                    borderColor: root.foreground
                }
            }
        }

    }

    KeyboardPanel {
        id: panel

        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        contentWidth: panel.fittedContentWidth(Style.space(300))
        contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(360))

        Column {
            id: column

            width: parent.width
            spacing: Style.space(12)

            Item {
                width: parent.width
                height: heroRow.implicitHeight

                Row {
                    id: heroRow
                    width: parent.width
                    spacing: Style.space(12)

                    LedIndicator {
                        anchors.verticalCenter: parent.verticalCenter
                        ledColor: root.ledColor
                        borderColor: root.foreground
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: Style.space(2)

                        Text {
                            Layout.fillWidth: true
                            text: "Acer Predator Helios Neo 16"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: led.available ? led.themeName + " · " + led.accent : "keyboard not detected"
                            color: led.available ? root.dim : Color.urgent
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }

                    }

                }

            }

            PanelSeparator {
                foreground: root.foreground
            }

            Text {
                visible: led.lastError !== ""
                width: parent.width
                text: led.lastError
                color: Color.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
            }

            Button {
                id: applyButton

                width: parent.width
                text: "Apply LED color"
                iconText: "󰄳"
                foreground: Color.accent
                accent: Color.accent
                fontFamily: root.fontFamily
                enabled: led.available && !led.busy
                onClicked: led.apply()
            }

            Text {
                width: parent.width
                text: "The keyboard backlight follows the active Omarchy theme automatically."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
            }

        }

    }

}
