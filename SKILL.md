---
name: xcode-device-interaction
description: Drive an iOS app on the simulator with REAL taps and typed text through Xcode's MCP server (xcrun mcpbridge) plus lldb, when idb is dead and there is no Simulator GUI. Installs and runs the scheme, taps by hierarchy hitPoints, types into fields, logs in, and screenshots each step. Use for end-to-end flow checks on the simulator.
---

# Xcode device interaction (real taps on the simulator)

`idb ui tap` is dead on newer Xcode (SimulatorKit moved) and a headless Mac has no Simulator.app GUI.
Xcode's MCP server (`xcrun mcpbridge`, Xcode 26+) CAN tap: tool `DeviceInteractionSynthesize`.
This skill talks to it through a small persistent bridge (`scripts/xmcp.py`), so no MCP config or session restart is needed.
(Alternative: `claude mcp add xcode -- xcrun mcpbridge`, then restart Claude Code to get native tools.)

## Setup (once per run)

```bash
K=<path to this skill>/scripts
python3 -I $K/xmcp.py serve            # run_in_background: true — keeps one mcpbridge alive on a Unix socket
python3 -I $K/xmcp.py XcodeOpenWorkspace '{"path":"/path/to/App.xcodeproj"}'
#   -> prints workspaceIdentifier, activeScheme, activeRunDestination
python3 -I $K/xmcp.py DeviceInteractionStartWorkspaceSession '{"sessionIdentifier":"My Check","deviceIdentifier":"iPhone 17 Pro","workspaceIdentifier":"<id>"}'
python3 -I $K/xmcp.py DeviceInteractionInstallAndRun '{"interactionSessionKey":"My Check","workspaceIdentifier":"<id>"}'
export XMCP_SESSION="My Check" XMCP_SHOTS=<scratch dir>/shots XMCP_APP=<app bundle id>
```

- `python3 -I $K/xmcp.py tools` lists every Xcode MCP tool; `python3 -I $K/xmcp.py schema <ToolName>` prints one tool's description and input schema. `XcodeListSchemes` / `XcodeSwitchScheme` / `XcodeListRunDestinations` switch scheme/device.
- The result of StartWorkspaceSession says "spawn a subagent with the device-interaction skill" — that skill does not exist outside Xcode; drive it yourself, it works.
- Parameter names differ: Synthesize takes `interactSessionKey`; InstallAndRun and EndSession take `interactionSessionKey`.

## Interacting

```bash
$K/syn.sh ""                 # capture only: prints the UI hierarchy (frames + hitPoints), saves last.png
$K/syn.sh "t 201 229" step1  # tap at a hitPoint, save $XMCP_SHOTS/step1.png, print new hierarchy
$K/type.sh "hello"           # type into the field you just tapped
```

Always tap the `hitPoint` from the latest hierarchy (points, e.g. 402x874 on a 6.3" iPhone). Filter the dump with
`grep -E "Button|StaticText|TextField|Cell|Alert"` and drop off-screen rows (`grep -vE "\{\{-"`).
Read `$XMCP_SHOTS/last.png` to see the screen.

Verified commands: `t x y` tap, `t x y 1.0` tap-and-hold, `d x y` double tap, `w <seconds>` wait,
`b <button>` hardware button, `mt [x y] dur ...` multi-touch. `XMCP_APP` (activationBundleId) brings the app to the front
first — another session may have left a different app in front.

**Typing:** tap the field, then `$K/type.sh "text"`. No Synthesize typing token works; the script sets the
focused field's text through lldb and fires `UITextFieldTextDidChangeNotification` (so buttons that watch edits
update). Needs a Debug build. If it says the app is under Xcode's debugger, relaunch with
`xcrun simctl terminate booted <bundle>; xcrun simctl launch booted <bundle>` (don't use RunProject attachDebugger,
and never attach to a debug session that belongs to someone's open Xcode window).

**Login:** `XMCP_LOGIN_EMAIL=... XMCP_LOGIN_PASSWORD=... $K/login.sh` finds the Email/Password fields and the Login
button in the hierarchy, types, taps, and dismisses "Save Password?". Field placeholders and the button label are
configurable (see the script header). Load the password from your keychain or a secrets file; it is never printed.

## Verify with data, not screens

A screen walk alone is not proof. Read your backend before and after the flow (e.g. firebase-admin against a dev
project) and check the records the flow should — and should not — have written.

## Teardown

```bash
python3 -I $K/xmcp.py DeviceInteractionEndSession '{"interactionSessionKey":"My Check"}'
pkill -f "xmcp.py serve"
```

## Gotchas

- Unix socket paths max ~104 chars: the socket defaults to `/tmp/xmcp-<uid>.sock` (override `XMCP_SOCK`).
- An invalid command returns in ~0.05 s with `Invalid command: '<x>'`; a valid one returns paths to screenshot + hierarchy + logs.
- Captures right after a push can show both screens mid-transition (negative x frames); capture again.
- Scrolling does not work (a `mt` drag is accepted but the screen does not move). Rows below the fold are out of reach.
- A session key cannot be reused right away ("currently in use or was recently used"); end the old session or pick a new key.
- The bridge's background task ends with exit 144 when `pkill` stops it at teardown; that is normal.
