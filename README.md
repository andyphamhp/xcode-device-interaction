# xcode-device-interaction

A [Claude Code](https://claude.com/claude-code) skill that drives an iOS app on the simulator with real taps and typed text, for end-to-end checks on a Mac where `idb` taps no longer work and there is no Simulator window.

It uses two things Xcode already ships:
- **Xcode's MCP server** (`xcrun mcpbridge`, Xcode 26+) for taps, waits, hardware buttons, screenshots and the UI hierarchy.
- **lldb** for typing, by setting the focused text field's text in a Debug build.

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
| `scripts/type.sh` | Types into the focused field through lldb |
| `scripts/login.sh` | Fills a login screen from `XMCP_LOGIN_EMAIL` / `XMCP_LOGIN_PASSWORD` and taps Login |

## Limits

- Scrolling doesn't work yet.
- Typing needs a Debug build that lldb can attach to.
- Tested with Xcode 26 and iOS 26–27 simulators on Apple silicon.

## License

MIT
