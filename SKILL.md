---
name: xcode-device-interaction
description: Drive an iOS app on the simulator with REAL taps, scrolling and typed text through Xcode's MCP server (xcrun mcpbridge), when idb is dead and there is no Simulator GUI. Installs and runs the scheme, taps by hierarchy hitPoints, scrolls long screens, pastes text through the app's own Paste menu (lldb typing as fallback), logs in, and screenshots each step. Use for end-to-end flow checks on the simulator.
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
python3 -I $K/xmcp.py XcodeOpenWorkspace '{"path":"<path/to/App.xcodeproj>"}'
#   -> prints workspaceIdentifier, activeScheme, activeRunDestination
python3 -I $K/xmcp.py DeviceInteractionStartWorkspaceSession '{"sessionIdentifier":"My Check","deviceIdentifier":"<UDID>","workspaceIdentifier":"<id>"}'
python3 -I $K/xmcp.py DeviceInteractionInstallAndRun '{"interactionSessionKey":"My Check","workspaceIdentifier":"<id>"}'
export XMCP_SESSION="My Check" XMCP_SHOTS=<scratchpad>/shots XMCP_APP=<bundle id> XMCP_UDID=<UDID>
```

- **Pass the simulator UDID as `deviceIdentifier`, not a name.** A name such as "iPhone 17 Pro" can match several devices (e.g. a second simulator with the same model in its name) and fail with "More than one device matches". Get the UDID from `xcrun simctl list devices available`.
- `python3 -I $K/xmcp.py tools` lists every Xcode MCP tool; `python3 -I $K/xmcp.py schema <ToolName>` prints one tool's description and input schema. `XcodeListSchemes` / `XcodeSwitchScheme` / `XcodeListRunDestinations` switch scheme/device.
- The result of StartWorkspaceSession says "spawn a subagent with the device-interaction skill" — that skill does not exist outside Xcode; drive it yourself, it works.
- Parameter names differ: Synthesize takes `interactSessionKey`; InstallAndRun and EndSession take `interactionSessionKey`.
- **"... to access Xcode?" prompt (Xcode 26.3+)**: `serve` auto-clicks Allow through `scripts/allow_mcp.js` (System Events; every 1 s for 60 s,
  then every 10 s; prints "Allowed N MCP connection(s)"). It checks the `Xcode` and `Xcode Service` processes. Needs Accessibility for the
  terminal app; `XMCP_NO_AUTO_ALLOW=1` turns it off. Adapted from gist oronbz/74f7b5785f12554467d52f4e03056852.
- **Agent approval without sudo:** Xcode identifies the agent by the PARENT process of `mcpbridge`. `xmcp.py serve` (Python, unsigned, new
  hash after each Homebrew upgrade) and a plain shell are new agents that need `sudo`; the signed Claude Code binary may already be approved.
  So run mcpbridge as a direct child of Claude Code and use pipe mode:
  `mkfifo $D/xmf.in $D/xmf.out`; background Bash #1: `exec /Applications/Xcode.app/Contents/Developer/usr/bin/mcpbridge 0<> $D/xmf.in 1<> $D/xmf.out 2>/dev/null`;
  background Bash #2: `XMCP_FIFO_IN=$D/xmf.in XMCP_FIFO_OUT=$D/xmf.out XMCP_SOCK=$D/xmf.sock XMCP_NO_AUTO_ALLOW=1 python3 -I $K/xmcp.py serve`.
  The bridge exits when Xcode reloads a regenerated project (xcodegen): restart both, reopen the workspace, start a NEW session name.
- **"Xcode is waiting for the user to approve this request"** (folder / agent approval): this is NOT the "... to access Xcode?" dialog that
  `allow_mcp.js` clicks. It is a pending approval listed by `xcrun mcp-server status` ("Pending approvals: ... folder <id>: <name> in <path>").
  Approve it from the terminal instead of waiting: `sudo xcrun mcp-server approve <id> --always` (a timeframe flag is required: `--always`
  or `--for-24-hours`). Never write a sudo password to a file or log; run `sudo -k` afterwards.

## Interacting

```bash
$K/syn.sh ""                 # capture only: prints the UI hierarchy (frames + hitPoints), saves last.png
$K/syn.sh "t 201 229" step1  # tap at a hitPoint, save $XMCP_SHOTS/step1.png, print new hierarchy
$K/scroll.sh down            # real touch scroll (see below)
$K/paste.sh "hello" 201 300  # real typing through the Paste menu (see below)
```

Always tap the `hitPoint` from the latest hierarchy (points, e.g. 402x874 on a 6.3" iPhone). Filter the dump with
`grep -E "Button|StaticText|TextField|Cell|Alert"` and drop off-screen rows (`grep -vE "\{\{-"`).
Read `$XMCP_SHOTS/last.png` to see the screen.

Verified commands: `t x y` tap, `t x y 1.0` tap-and-hold, `d x y` double tap, `w <seconds>` wait,
`b <button>` hardware button, `mt [x y] dur [x y] dur` multi-touch, `drag x1 y1 x2 y2 [hold] [move]` drag-and-drop,
`orientation landscapeLeft` / `orientation portrait` rotate the device (`c` = watch crown, `r` = tvOS remote).
Xcode's built-in doc also lists swipe and type-text commands, but this Xcode build rejects every name tried for them; use the scripts below.
`XMCP_APP` (activationBundleId) brings the app to the front first, because another session may have left a different app in front.

**Scrolling:** `$K/scroll.sh down` moves the screen about 500 pt (a slow `mt` drag, no momentum).
`$K/scroll.sh down fast` flicks with momentum, many rows at once. `up` goes the other way, and an optional x picks the column.
Scroll, then capture and check that the target row is on screen (no negative frame) before tapping it.

**Lists inside a scrolling page:** start a `drag` inside the inner list. `drag 201 615 201 80` (start inside, end far above it) moves the
inner list while the page stays put. When the list reaches its end, further drags scroll the page instead (normal iOS chaining).
Check by comparing the list's frame (unchanged) with its cells' frames (moved).

**Swipe-left (swipe-to-delete):** `drag x1 y x2 y 0.05` (a short trailing time). A plain `drag` with no time is too slow to be a swipe:
on a collection view cell it ends as a TAP and opens the row instead. `0.05`, `0.1` and `0.05 0.1` all fire a swipe gesture recognizer.
Tap `Cancel` on a confirmation unless the test means to delete.

**Pinch / two fingers:** `mt [x1 y1, x2 y2] 0.2 [x3 y3, x4 y4] 0.6`. Each `[...]` block holds one `x y` per finger, separated by a comma,
followed by a duration. `mt [180 310, 220 340] 0.2 [100 250, 300 420] 0.6` pinches out (zooms a UIScrollView in). Rejected forms: `|`
between fingers, two blocks before one duration, four numbers in one block without the comma.

**System pickers (Files, Photos) are tappable.** They run in another process and slide in late: the first capture after the tap can
still show the app's own screen, so capture again with `w 2` before deciding it did not open. The Files picker opens on Recents: tap
`Browse` (tab bar) to reach "On My iPhone". Put a test file there with
`G=$(xcrun simctl get_app_container <UDID> com.apple.DocumentsApp groups | grep LocalStorage | awk '{print $2}')` and copy it into
`"$G/File Provider Storage/"`; pictures go to Photos with `xcrun simctl addmedia <UDID> <file>`. The photo grid's cells show as
`Image ... identifier: 'PXGGridLayout-Info'` with hitPoints.

**The workspace identifier changes** when the project file is regenerated (xcodegen) or Xcode reloads it: an `InstallAndRun` with the
old id fails with "Unknown workspace identifier", and the app that then runs is the OLD build. Call `XcodeOpenWorkspace` again and read
the id each time before `InstallAndRun`; check its reply says "Application installed and running" before trusting what you see.

**Typing (real):** `$K/paste.sh "text" <x> <y> [shot]`. The simulator uses the Mac keyboard, so no on-screen keyboard appears and there
are no keys to tap. The script puts the text on the Mac and simulator clipboards (the simulator syncs from the Mac, so `simctl pbcopy`
alone pastes whatever the Mac had), long-presses the field, taps the app's own `Paste` menu item, then restores the Mac clipboard.
The field gets its real text-change events (a UISearchBar filters, edit-watching buttons update), with no lldb. It pastes at the
cursor, so clear the field first.

**Typing (fallback):** tap the field, then `$K/type.sh "text"`. The script sets the focused field's text through lldb and fires
`UITextFieldTextDidChangeNotification`. It does NOT reach a UISearchBar's delegate (see Gotchas). Needs a Debug build. If it says the
app is under Xcode's debugger, relaunch with `xcrun simctl terminate booted <bundle>; xcrun simctl launch booted <bundle>` (don't use
RunProject attachDebugger, and never attach to a debug session that belongs to someone's open Xcode window).

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
- A session key cannot be reused right away ("currently in use or was recently used"); end the old session or pick a new key.
- Two booted simulators: export `XMCP_UDID=<udid>` or type.sh / paste.sh act on the other simulator's app.
- The bridge's background task ends with exit 144 when `pkill` stops it at teardown; that is normal.
- The bridge can die with exit 144 in the middle of a tight loop of ~40 back-to-back `drag` calls, and every later call then fails with
  `ConnectionRefusedError`. Recover: remove the socket file, run `serve` again in the background, and keep using the same session key
  (the device session survives, but StartWorkspaceSession with the same name is refused). Loop in batches of about 12 and stop on the first failure.
- **UISearchBar with type.sh:** prefer `paste.sh`. `type.sh` sets the text but the search bar's delegate never hears it, so the list doesn't
  filter. If you must use it, call `searchBar:textDidChange:` on the delegate through lldb. If an lldb batch fails mid-script, the app can
  stay stopped (`ps -o stat=` shows `T`) and taps then time out with "main thread did not execute": run `kill -CONT <pid>` after every lldb call.
- The keyboard is not in the hierarchy (it runs in another process and is hidden anyway). Don't look for `Key` elements.
- An lldb `setContentOffset` scroll can look right in one capture and snap back later. Use `scroll.sh`, which scrolls with a real touch.
- Finding command names: the command table is in `strings .../Xcode.app/Contents/PlugIns/IDEDeviceInteraction.framework/Versions/A/IDEDeviceInteraction | grep -A40 "## Interaction Command Syntax"`,
  but the command letters are filled in at runtime and missing there. Probe a name with `syn.sh "<name> 1 2"`: an unknown name returns `Invalid command: '<name>'` at once.
- Seeded backend records may not show in the app even after relaunch; if one does not appear, create it through the app UI instead of debugging the seed.

## Multi-touch sequences: what works

- To lift one finger and touch again in ONE command, use a second finger slot: `mt [250 252] 0.05 [170 252] 0.01 [, 200 252] 0.15`
  (finger 1 ends, finger 2 lands). An empty block `[]` is accepted but the next touch never happens.
- A "catch a gliding scroll view" test cannot be done: no timing (0.0-0.12 s gaps) stopped a decelerating UIScrollView; the glide always
  reached its target first. The lift of a flick that ends through an empty slot can also report a REVERSED velocity, so the scroll goes the
  wrong way. Read the scroll delegate logs (`xcrun simctl spawn <udid> log stream --predicate 'eventMessage CONTAINS "TAG"'`) before calling it an app bug.
