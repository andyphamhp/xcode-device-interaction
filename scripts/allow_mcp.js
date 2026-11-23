#!/usr/bin/env osascript -l JavaScript
// Created by Andy
// Clicks "Allow" on Xcode's "… to access Xcode?" MCP agent dialog (Xcode 26.3+ asks on every new mcpbridge).
// Adapted from https://gist.github.com/oronbz/74f7b5785f12554467d52f4e03056852
// Needs Accessibility permission for the app that runs it (Terminal / iTerm / Claude).

var NAMES = ["Xcode", "Xcode Service"];

function run() {
    var se = Application("System Events");
    var count = 0, seen = 0;
    NAMES.forEach(function (name) {
        var windows;
        try { windows = se.processes.byName(name).windows(); seen++; } catch (e) { return; }
        for (var i = 0; i < windows.length; i++) {
            try {
                var w = windows[i];
                if (w.subrole() !== "AXDialog") continue;
                if (!w.staticTexts().some(function (t) { return (t.value() || "").indexOf("to access Xcode?") !== -1; })) continue;
                w.buttons.byName("Allow").click();
                count++;
            } catch (e) {}
        }
    });
    if (!seen) return "Xcode not running.";
    return count ? "Allowed " + count + " MCP connection(s)." : "No MCP dialogs found.";
}
