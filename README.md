# xcode-device-interaction

A [Claude Code](https://claude.com/claude-code) skill that drives an iOS app on the simulator with real taps, scrolling and typed text, for end-to-end checks on a Mac where `idb` taps no longer work and there is no Simulator window.

It uses two things Xcode already ships:
- **Xcode's MCP server** (`xcrun mcpbridge`, Xcode 26+) for taps, waits, hardware buttons, screenshots and the UI hierarchy.
- **The app's own Paste menu** for typing, with lldb (setting the focused field's text in a Debug build) as a fallback.

## Install

```bash
git clone https://github.com/andyphamhp/xcode-device-interaction ~/.claude/skills/xcode-device-interaction
```

Claude Code picks the skill up in the next session. Read [SKILL.md](SKILL.md) for the full workflow.

## Scripts

| Script | What it does |
|---|---|
| `scripts/xmcp.py` | Keeps one `mcpbridge` alive on a Unix socket and calls its tools (`serve`, `tools`, `schema <Tool>`, `<Tool> '<json>'`) |
| `scripts/syn.sh` | Runs one interaction command (`t x y`, `w 2`, …), saves a screenshot, prints the new UI hierarchy |
| `scripts/type.sh` | Types into the focused field through lldb (fallback) |
| `scripts/paste.sh` | Real typing: puts text on the clipboards, long-presses the field, taps the app's Paste menu |
| `scripts/scroll.sh` | Real touch scrolling (`down`/`up`, `fast` flick or slow drag) |
| `scripts/allow_mcp.js` | Clicks Allow on Xcode's "... to access Xcode?" dialog (used by `serve`; needs Accessibility) |
| `scripts/login.sh` | Fills a login screen from `XMCP_LOGIN_EMAIL` / `XMCP_LOGIN_PASSWORD` and taps Login |

## Limits

- Typing via `paste.sh` needs no Debug build; the lldb fallback (`type.sh`) does.
- The `mt` multi-touch command can't catch a gliding scroll view mid-deceleration.
- Tested with Xcode 26 and iOS 26–27 simulators on Apple silicon.

## License

MIT
