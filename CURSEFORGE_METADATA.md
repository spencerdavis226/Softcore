# CurseForge Metadata

Use this as the source text for the first public CurseForge project/file.

## Project

- Name: Softcore
- Summary: Group accountability tracker for hardcore-style Retail WoW runs.
- Game flavor: World of Warcraft Retail
- Supported game version: 12.0.5
- TOC interface: 120005
- Addon version: 0.5.0
- Release type: Beta
- License: MIT
- Primary logo/icon: `Assets/SoftcoreLogo.tga`
- In-addon icon: `Assets/SoftcoreLogoMinimap.tga`
- Suggested categories: Quests & Leveling, Guild, Miscellaneous

## Short Description

Softcore tracks hardcore-style leveling runs with deaths, rule violations, party compatibility, audit logs, achievements, and run status.

## Long Description

Softcore is a Retail WoW addon for players who want hardcore-style accountability without server-side enforcement. It keeps a per-character run ledger and makes the group's rules visible through a compact menu, HUD, minimap button, violation list, audit log, and achievement journal.

Runs can be played solo or with friends. Grouped play uses Charter-tab proposals and Party Sync so players explicitly accept shared run starts, run alignment, invites, and rule amendments. Remote state is display and compatibility data; it does not silently reset, fail, overwrite, or invalidate the local character.

Key features:

- Per-character run tracking for deaths, rule violations, active status, and audit history.
- Four built-in presets: Casual, Chef's Special, Ironman, and Iron Vigil.
- Charter-tab group proposals, run sync, party invites, and rule amendments.
- Compact Overview, Violations, Log, and Achievements tabs.
- HUD and minimap button for quick status and menu access.
- Rule checks for gear, enchants, heirlooms, economy access, mounts, flying, flight paths, dungeons, and grouped-play compatibility.
- Advisory item tooltip warnings for active run item restrictions.
- CSV export plus bounded `/sc bug` diagnostics for testing and support.
- Achievement milestones and max-level completion awards.

Softcore is intentionally individual-first. Local character validity changes only from local deaths, local rule violations, or explicit local user actions such as accepting proposals, applying amendments, starting, resetting, stopping, or retiring a run.

## File Changelog

Softcore 0.5.0 is the first public Beta candidate.

Highlights:

- Retail 12.0.5 / interface 120005 support.
- Master menu, HUD, minimap button, violations, audit log, achievements, and exports.
- Solo runs, group proposals, Party Sync, active-run invites, and rule amendments.
- Hardened `/sc bug` export, reset/no-run states, warband bank detection, player-facing rules output, and visible log filtering.

Known limitations:

- Multiplayer release passes are still required before promoting a file to stable Release.
- Raid groups are local-only and do not sync through raid channels.
- The addon is an accountability ledger, not server-side enforcement.

## Package Notes

The uploaded zip should contain a top-level `Softcore` folder with:

- `Softcore.toc`
- TOC-loaded Lua files
- `Assets/*.tga`
- `README.md`
- `CHANGELOG.md`
- `LICENSE`

Exclude local development files and directories:

- `.git`
- `.claude`
- `.cursor`
- `.vscode`
- `AGENTS.md`
- `DESIGN.md`
- editor metadata
- local test files
- unused empty stubs
