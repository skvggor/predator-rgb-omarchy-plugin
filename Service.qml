import "Model.js" as Model
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var settings: ({
    })
    property bool available: false
    property bool applied: false
    property string themeName: ""
    property string accent: ""
    property string lastError: ""
    property bool busy: applyProcess.running
    readonly property int brightness: intSetting("brightness", Model.DEFAULT_BRIGHTNESS, 0, 100)
    readonly property string staticDevice: "/dev/acer-gkbbl-static-0"
    readonly property string dynamicDevice: "/dev/acer-gkbbl-0"
    // The theme-set hook ships beside this file (installed by install.sh) and is
    // run by the global theme-set.d hook; the panel invokes it on demand too.
    readonly property string hookPath: String(Qt.resolvedUrl("theme-set")).replace(/^file:\/\//, "")

    function setting(name, fallback) {
        var value = settings ? settings[name] : undefined;
        return value === undefined || value === null ? fallback : value;
    }

    function intSetting(name, fallback, minimum, maximum) {
        var number = parseInt(String(setting(name, fallback)), 10);
        if (!isFinite(number))
            number = fallback;

        if (number < minimum)
            number = minimum;

        if (number > maximum)
            number = maximum;

        return number;
    }

    function refresh() {
        if (probeProcess.running)
            return ;

        const script = [
            "keyboard_rgb=\"$HOME/.local/state/omarchy/current/theme/keyboard.rgb\"",
            "theme_file=\"$HOME/.local/state/omarchy/current/theme.name\"",
            "static_device=\"$1\"",
            "dynamic_device=\"$2\"",
            "accent=$(sed 's/^[[:space:]]*#\\?//' \"$keyboard_rgb\" 2>/dev/null)",
            "name=$(cat \"$theme_file\" 2>/dev/null)",
            "is_available=false",
            "[ -w \"$static_device\" ] && [ -w \"$dynamic_device\" ] && is_available=true",
            "printf '{\"accent\":\"%s\",\"themeName\":\"%s\",\"available\":%s}\\n' \"$accent\" \"$name\" \"$is_available\""
        ].join("; ")
        probeProcess.command = ["sh", "-c", script, "predator-rgb-probe", staticDevice, dynamicDevice]
        probeProcess.running = true
    }

    function apply() {
        if (applyProcess.running || !available)
            return ;

        applyProcess.environment = ["PREDATOR_RGB_BRIGHTNESS=" + String(brightness)];
        applyProcess.command = [hookPath];
        applyProcess.running = true;
    }

    Process {
        id: probeProcess

        running: false
        command: []
        onRunningChanged: {
            if (running) {
                probeDeadline.restart();
            } else {
                probeDeadline.stop();
            }
        }
        onExited: function(exitCode) {
            var status = Model.parseStatus(probeStdout.text);
            available = status.available;
            themeName = Model.formatThemeName(status.themeName);
            accent = status.accent;
        }

        stdout: StdioCollector {
            id: probeStdout

            waitForEnd: true
        }

    }

    Process {
        id: applyProcess

        property bool timedOut: false

        running: false
        command: []
        environment: []
        onRunningChanged: {
            if (running) {
                timedOut = false;
                applyDeadline.restart();
            } else {
                applyDeadline.stop();
            }
        }
        onExited: function(exitCode) {
            if (timedOut) {
                lastError = "Applying the LED color did not finish";
                return ;
            }
            if (exitCode === 0) {
                lastError = "";
                applied = true;
            } else {
                applied = false;
                lastError = String(applyStderr.text || applyStdout.text || "Could not apply LED color").trim();
            }
            refresh();
        }

        stdout: StdioCollector {
            id: applyStdout

            waitForEnd: true
        }

        stderr: StdioCollector {
            id: applyStderr

            waitForEnd: true
        }

    }

    Timer {
        id: probeDeadline

        interval: 10000
        repeat: false
        onTriggered: {
            probeProcess.running = false;
        }
    }

    Timer {
        id: applyDeadline

        interval: 10000
        repeat: false
        onTriggered: {
            applyProcess.timedOut = true;
            applyProcess.running = false;
        }
    }

    Timer {
        id: refreshTimer

        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

}
