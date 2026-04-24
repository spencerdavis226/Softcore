# Agent Instructions for Softcore

This is a Retail World of Warcraft addon for Midnight / Retail.

Goal:
Build a non-combat group accountability tracker for hardcore-style leveling with friends.

Do:

- Use Lua 5.1-compatible code.
- Keep files modular and simple.
- Use SavedVariables named SoftcoreDB.
- Use slash commands under /softcore and /sc.
- Track run state, deaths, warnings, zone changes, level changes, and group roster changes.
- Build a small movable UI frame.
- Add group sync using addon messages only after the local MVP works.
- Keep code heavily commented.

Do not:

- Add combat automation.
- Add rotation recommendations.
- Add boss mechanic solving.
- Add protected action buttons.
- Add dependencies on external libraries unless explicitly requested.
- Rewrite the whole addon without explaining the file changes.
- Create build tooling, npm, TypeScript, React, or a local server.

Development workflow:

- Save files.
- Test in WoW with /reload.
- Use BugSack/BugGrabber for Lua errors.
- Prefer small incremental changes.
