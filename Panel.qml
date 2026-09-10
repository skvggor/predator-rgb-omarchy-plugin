import "Model.js" as Model
import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
    id: root

    property var anchorItem: null
    property var hostWidget: null

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.55)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property color ledColor: Model.hexToRgb(led.accent) ? ("#" + led.accent) : foreground

    moduleName: "skvggor.predator-rgb"
    manageIpc: false

    function open() {
        root.controller.show()
    }

    function close() {
        root.controller.hide()
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction)
        return false
    }

    Service {
        id: led
        settings: root.settings
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(300))
        contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(220))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }

            Column {
                id: column
                width: parent.width
                spacing: Style.space(12)

                PanelHero {
                    width: parent.width
                    title: "Predator RGB"
                    meta: "Acer Predator Helios Neo 16"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    iconComponent: Component {
                        Text {
                            text: "󰌌"
                            color: root.ledColor
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.display
                        }
                    }
                }

                PanelSeparator {
                    foreground: root.foreground
                }

                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: !led.loaded

                    Text {
                        width: parent.width
                        text: "Kernel module not active."
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Item {
                        width: parent.width
                        height: commandBox.height + copyHint.implicitHeight + Style.space(4)

                        Rectangle {
                            id: commandBox
                            width: parent.width
                            height: installCmd.implicitHeight + Style.space(24)
                            radius: Style.space(6)
                            color: installMouse.containsMouse ? Util.alpha(root.ledColor, 0.2) : Util.alpha(root.ledColor, 0.1)
                            border.width: 1
                            border.color: Util.alpha(root.ledColor, 0.3)

                            Column {
                                anchors.fill: parent
                                anchors.margins: Style.space(12)

                                Text {
                                    id: installCmd
                                    width: parent.width
                                    text: "cd ~/.config/omarchy/plugins/skvggor.predator-rgb && sudo ./bin/omarchy-install-predator-rgb --install"
                                    color: root.ledColor
                                    font.family: root.fontFamily
                                    font.pixelSize: Style.font.caption
                                    wrapMode: TextEdit.Wrap
                                }
                            }

                            MouseArea {
                                id: installMouse
                                property bool copied: false
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(installCmd.text) + " | wl-copy"])
                                    copied = true
                                    copiedTimer.restart()
                                }
                            }
                        }

                        Text {
                            id: copyHint
                            anchors.top: commandBox.bottom
                            anchors.topMargin: Style.space(2)
                            anchors.right: commandBox.right
                            text: installMouse.containsMouse ? (installMouse.copied ? "copied!" : "click to copy") : ""
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption - 2
                        }

                        Timer {
                            id: copiedTimer
                            interval: 2000
                            onTriggered: installMouse.copied = false
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: led.loaded

                    Item {
                        width: parent.width
                        height: Style.space(18)
                        visible: led.available

                        Text {
                            id: kbdIcon
                            text: "󰌌"
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.icon
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: kbdLabel
                            text: "Keyboard"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            anchors.left: kbdIcon.right
                            anchors.leftMargin: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            id: kbdStatus
                            height: Style.space(18)
                            width: Style.space(7) + kbdDot.width + Style.space(6) + Math.ceil(kbdStatusLabel.implicitWidth) + Style.space(8)
                            radius: height / 2
                            color: Util.alpha(root.ledColor, 0.12)
                            border.width: 1
                            border.color: Util.alpha(root.ledColor, 0.35)
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: kbdDot
                                anchors.left: parent.left
                                anchors.leftMargin: Style.space(7)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Style.space(6)
                                height: width
                                radius: width / 2
                                color: root.ledColor
                            }

                            Text {
                                id: kbdStatusLabel
                                anchors.left: kbdDot.right
                                anchors.leftMargin: Style.space(6)
                                anchors.verticalCenter: parent.verticalCenter
                                text: "ON"
                                color: root.ledColor
                                textFormat: Text.PlainText
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                font.letterSpacing: 1.2
                                font.capitalization: Font.AllUppercase
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: Style.space(18)
                        visible: led.available

                        Text {
                            id: logoIcon
                            text: "󰖨"
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.icon
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: logoLabel
                            text: "Back logo"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            anchors.left: logoIcon.right
                            anchors.leftMargin: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            id: logoStatus
                            height: Style.space(18)
                            width: Style.space(7) + logoDot.width + Style.space(6) + Math.ceil(logoStatusLabel.implicitWidth) + Style.space(8)
                            radius: height / 2
                            color: Util.alpha(root.ledColor, 0.12)
                            border.width: 1
                            border.color: Util.alpha(root.ledColor, 0.35)
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: logoDot
                                anchors.left: parent.left
                                anchors.leftMargin: Style.space(7)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Style.space(6)
                                height: width
                                radius: width / 2
                                color: root.ledColor
                            }

                            Text {
                                id: logoStatusLabel
                                anchors.left: logoDot.right
                                anchors.leftMargin: Style.space(6)
                                anchors.verticalCenter: parent.verticalCenter
                                text: "ON"
                                color: root.ledColor
                                textFormat: Text.PlainText
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                font.bold: true
                                font.letterSpacing: 1.2
                                font.capitalization: Font.AllUppercase
                            }
                        }
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
                }
            }
        }
    }
}
