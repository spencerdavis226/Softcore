# Changelog

## 0.5.0 - 2026-05-05

### Release Type

Beta candidate for first public CurseForge upload.

### Added

- Retail 12.0.5 support with interface `120005`.
- Per-character Softcore run ledger for deaths, violations, audit history, party state, and current run status.
- Master menu with Overview, Charter, Violations, Log, and Achievements tabs.
- Compact HUD and minimap button.
- Four visible presets: Casual, Chef's Special, Bronzeman, and Bronze Vigil.
- Charter-tab group run proposals, run sync proposals, party invites, and rule amendments.
- Party Sync over Blizzard addon messages on party and instance-chat channels.
- Rule violation tracking for gear, enchants, heirlooms, economy access, travel, dungeons, grouped-play blockers, and other run rules.
- CSV export and bounded `/sc bug` diagnostic export.
- Account-level achievements and per-character max-level completion award support.
- Advisory item tooltip warnings for active run item restrictions.

### Hardened

- Inactive and no-run slash commands, menu tabs, HUD, and exports handle reset state cleanly.
- `/sc bug` export window sizing is compatible with clients where edit boxes do not expose string-height helpers.
- `/sc rules chat` hides legacy death-limit internals that are not part of the current player-facing rules.
- Warband bank access is detected on current Retail bank panels and account-bank interactions.
- Visible logs hide forced-movement start/end audit rows while keeping the stored history available to exports.
- TOC-loaded Lua files pass syntax checks for this release candidate.

### Known Limitations

- Softcore is not server-side enforcement. It records and displays local and party accountability state.
- Raid groups are local-only and intentionally do not use raid addon-message sync.
- Multiplayer release passes are still required before a stable public release.
- First public CurseForge file should be uploaded as Beta until the full multiplayer checklist passes.
