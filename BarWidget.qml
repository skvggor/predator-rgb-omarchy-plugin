import "Model.js" as Model
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "skvggor.predator-rgb"

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.55)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property color ledColor: Model.hexToRgb(led.accent) ? ("#" + led.accent) : foreground
    readonly property bool needsSetup: led.available === false
    readonly property string installScript: String(Qt.resolvedUrl("bin/omarchy-install-predator-rgb")).replace(/^file:\/\//, "")

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    function open() {
        if (panelLoader.item) panelLoader.item.open()
    }

    function close() {
        if (panelLoader.item) panelLoader.item.close()
    }

    function togglePanel() {
        if (panelLoader.item) panelLoader.item.toggle()
    }

    function closeForPopoutSwitch() {
        if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
    }

    function injectPanel() {
        var target = panelLoader.item
        if (!target) return
        if ("bar" in target) target.bar = root.bar
        if ("settings" in target) target.settings = root.settings
        if ("anchorItem" in target) target.anchorItem = button
        if ("hostWidget" in target) target.hostWidget = root
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: injectPanel()
    onSettingsChanged: injectPanel()

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

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    IpcHandler {
        target: "skvggor.predator-rgb"

        function refresh(): string {
            led.refresh();
            return "ok";
        }

        function apply(): string {
            led.apply();
            return "ok";
        }

        function status(): string {
            return JSON.stringify({
                "available": led.available,
                "applied": led.applied,
                "themeName": led.themeName,
                "accent": led.accent
            });
        }

        function open(): void { root.open() }
        function close(): void { root.close() }
        function show(): void { root.open() }
        function hide(): void { root.close() }
        function toggle(): void { root.togglePanel() }
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
                root.togglePanel();
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
}
