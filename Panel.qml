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

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.55)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property color ledColor: Model.hexToRgb(led.accent) ? ("#" + led.accent) : foreground
    readonly property bool needsSetup: led.available === false
    readonly property string installScript: String(Qt.resolvedUrl("bin/omarchy-install-predator-rgb")).replace(/^file:\/\//, "")

    moduleName: "skvggor.predator-rgb"
    ipcTarget: "skvggor.predator-rgb"
    manageIpc: false
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
                "accent": led.accent,
                "backLogoEnabled": led.backLogoEnabled
            });
        }

        target: root.ipcTarget
    }

    Process {
        id: installProcess

        property bool running: false

        command: ["pkexec", root.installScript, "--install"]
        onExited: function(exitCode) {
            running = false;
            if (exitCode === 0) {
                led.refresh();
            }
        }
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
        tooltipText: root.needsSetup
            ? "Predator RGB: click to install kernel module"
            : !led.available ? "Acer Predator Helios Neo 16: not detected" : "Acer Predator Helios Neo 16: " + led.themeName + " (" + led.accent + ")"
        onPressed: function(buttonCode) {
            if (root.needsSetup) {
                installProcess.running = true;
                return;
            }
            if (buttonCode === Qt.MiddleButton)
                led.apply();
            else
                root.toggle();
        }

        iconComponent: Component {
            Item {
                LedIndicator {
                    anchors.centerIn: parent
                    ledColor: root.needsSetup ? root.dim : root.ledColor
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
        contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(160))

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
                        color: led.backLogoEnabled ? Util.alpha(root.ledColor, 0.12) : Util.alpha(root.dim, 0.12)
                        border.width: 1
                        border.color: led.backLogoEnabled ? Util.alpha(root.ledColor, 0.35) : Util.alpha(root.dim, 0.35)
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
                            color: led.backLogoEnabled ? root.ledColor : root.dim
                        }

                        Text {
                            id: logoStatusLabel
                            anchors.left: logoDot.right
                            anchors.leftMargin: Style.space(6)
                            anchors.verticalCenter: parent.verticalCenter
                            text: led.backLogoEnabled ? "ON" : "OFF"
                            color: led.backLogoEnabled ? root.ledColor : root.dim
                            textFormat: Text.PlainText
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            font.letterSpacing: 1.2
                            font.capitalization: Font.AllUppercase
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
