import "Model.js" as Model
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    readonly property bool needsSetup: led.available === false
    readonly property string installScript: String(Qt.resolvedUrl("bin/omarchy-install-predator-rgb")).replace(/^file:\/\//, "")

    moduleName: "skvggor.predator-rgb"
    ipcTarget: "skvggor.predator-rgb"
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

    Process {
        id: installProcess
        running: false
        command: ["pkexec", root.installScript, "--install"]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                led.refresh();
            }
        }
    }

    Process {
        id: uninstallProcess
        running: false
        command: ["pkexec", root.installScript, "--uninstall"]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                led.refresh();
            }
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(300))
        contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(160))

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
                    visible: root.needsSetup

                    Text {
                        width: parent.width
                        text: "Kernel module not installed. Click the button in the bar to install it."
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Item {
                        width: parent.width
                        height: Style.space(32)

                        Rectangle {
                            anchors.centerIn: parent
                            width: installLabel.implicitWidth + Style.space(32)
                            height: Style.space(32)
                            radius: Style.space(8)
                            color: Util.alpha(root.ledColor, 0.15)
                            border.width: 1
                            border.color: Util.alpha(root.ledColor, 0.4)

                            Text {
                                id: installLabel
                                anchors.centerIn: parent
                                text: installProcess.running ? "Installing..." : "Install Kernel Module"
                                color: root.ledColor
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!installProcess.running)
                                        installProcess.running = true;
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: !root.needsSetup

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
                        height: Style.space(32)

                        Rectangle {
                            anchors.centerIn: parent
                            width: uninstallLabel.implicitWidth + Style.space(32)
                            height: Style.space(32)
                            radius: Style.space(8)
                            color: Util.alpha(Color.urgent, 0.15)
                            border.width: 1
                            border.color: Util.alpha(Color.urgent, 0.4)

                            Text {
                                id: uninstallLabel
                                anchors.centerIn: parent
                                text: uninstallProcess.running ? "Uninstalling..." : "Uninstall Kernel Module"
                                color: Color.urgent
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!uninstallProcess.running)
                                        uninstallProcess.running = true;
                                }
                            }
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
