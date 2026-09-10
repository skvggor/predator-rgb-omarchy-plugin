import "Model.js" as Model
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var settings: ({
    })
    property bool available: false
    property bool loaded: false
    property bool moduleInstalled: false
    property bool applied: false
    property string themeName: ""
    property string accent: ""
    property string lastError: ""
    readonly property string acerRgbSysfs: "/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode"
    readonly property string hookPath: String(Qt.resolvedUrl("theme-set")).replace(/^file:\/\//, "")

    function refresh() {
        if (probeProcess.running)
            return ;

        const script = [
            "keyboard_rgb=\"$HOME/.local/state/omarchy/current/theme/keyboard.rgb\"",
            "theme_file=\"$HOME/.local/state/omarchy/current/theme.name\"",
            "acer_rgb_sysfs=\"$1\"",
            "accent=$(sed 's/^[[:space:]]*#\\?//' \"$keyboard_rgb\" 2>/dev/null)",
            "name=$(cat \"$theme_file\" 2>/dev/null)",
            "is_loaded=false",
            "is_available=false",
            "is_installed=false",
            "[ -d /sys/module/acer_rgb ] && is_loaded=true",
            "[ -w \"$acer_rgb_sysfs\" ] && is_available=true",
            "modinfo acer_rgb >/dev/null 2>&1 && is_installed=true",
            "printf '{\"accent\":\"%s\",\"themeName\":\"%s\",\"loaded\":%s,\"available\":%s,\"installed\":%s}\\n' \"$accent\" \"$name\" \"$is_loaded\" \"$is_available\" \"$is_installed\""
        ].join("; ")
        probeProcess.command = ["sh", "-c", script, "predator-rgb-probe", acerRgbSysfs]
        probeProcess.running = true
    }

    function apply() {
        if (applyProcess.running || !available)
            return ;

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
            loaded = status.loaded;
            available = status.available;
            moduleInstalled = status.installed;
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

        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

}
