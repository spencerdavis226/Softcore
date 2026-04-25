# Softcore Addon: Loose Project Context and Roadmap

Softcore is a Retail World of Warcraft Lua addon for hardcore-style leveling with friends.

The goal is not server-side enforcement. The goal is a lightweight accountability addon that helps players track deaths, rule breaks, group compatibility, logs, and run status.

## Core Product Principle

Softcore should be individual-first.

A party member’s death, failure, violation, unsynced state, or ruleset mismatch should not directly fail or mutate the local player’s character state.

Local character validity should be affected only by local events, such as:

- the local character dying
- the local character triggering a disallowed action
- the local character equipping disallowed gear
- the local user explicitly accepting, retiring, resetting, or changing something

Remote player state should mainly be used for display, compatibility checks, group status, and logs.

Party/group status should be derived from local and remote state. It should not be treated as authoritative over an individual character’s validity.

## General Design Direction

Keep the addon simple and readable.

Prefer one primary interface: a master Softcore menu with a small, optional HUD later for quick status. Avoid proliferating separate windows unless there is a strong reason.

Prefer clear user-facing concepts:

- `Failed`: a character died or permanently failed
- `Violation`: a rule was broken
- `Cleared`: a violation was reviewed and forgiven, but not deleted
- `Blocked`: group progress is blocked by a compatibility issue
- `Conflict`: rules/run mismatch
- `Unsynced`: a party member is not syncing valid Softcore data
- `Valid`: character is alive and has no active issues

Avoid exposing overly technical internal states in the UI unless needed.

The master menu should stay compact and understandable. A good current shape is:

- `Overview`: local run status plus party/participant snapshot
- `Run`: start a run, review active locked rules, stop a run, and eventually modify rules through a visible amendment flow
- `Violations`: active clearable issues
- `Log`: audit history, newest entries first

If no run is active, opening the menu should emphasize starting/configuring a run. If a run is active, opening the menu should emphasize current status.

A future HUD should be small and glanceable, with simple local and party indicators such as safe, blocked, violation, or failed/death states. Remote failures should be visible without automatically failing the local player.

## Rule Philosophy

Death should be permanent for the character.

Non-death rule breaks should generally create violations, not fail the character outright.

Examples of violations:

- opening a disallowed mailbox
- opening a disallowed bank
- opening the auction house when disallowed
- opening a trade window when disallowed
- using disallowed mounts or flying
- equipping disallowed gear

Examples of group blockers or conflicts:

- unsynced party member
- ruleset mismatch
- run mismatch
- failed character still grouped
- max level gap exceeded, if enabled

Blockers/conflicts should generally affect party status, not individual character validity.

## Grouping Direction

Grouping should be simple.

A good baseline is:

- Group mode: party members should be synced and using compatible Softcore rules.
- Solo/self-found mode: grouping is not intended and should be treated accordingly.

In group mode:

- players should be able to join and leave as long as they are synced and compatible
- unsynced players should block or conflict with group progress until they sync or leave
- a failed character should not continue with the group
- a failed remote character should not fail anyone else

The addon should avoid tedious approval flows unless they are needed for a clear reason.

## Start Run Direction

The Start Run / Run UI should stay simple.

Prefer:

- clear rule sections
- concise wording
- minimal required inputs
- one obvious primary action
- no unnecessary run-name or setup friction unless needed
- safe behavior when a run is already active

Starting while solo can start immediately.

Starting while grouped may need a proposal/acceptance flow so everyone uses compatible settings.

When a run is already active, rule values should be visible but not casually editable. Mid-run changes should go through a future amendment/modify flow and should be logged.

The UI should avoid long dropdown labels that run into columns or overlap.

## Rules UI Direction

Favor simple controls.

Where possible, use:

- checkboxes for allowed/disallowed rules
- short dropdown labels
- simple helper text
- clear descriptions only where needed

Avoid showing internal severity language like `LOG_ONLY`, `WARNING`, or `FATAL` in the main Start Run UI unless there is a strong reason.

A disallowed non-death action should normally create a violation that can later be reviewed.

## Gear Direction

Gear rules should be understandable.

Prefer a short gear limit dropdown such as:

- Any gear
- White/gray only
- Green or lower
- Blue or lower

Heirlooms should stay separate from normal gear quality if the code supports that cleanly.

Gear validation should focus on equipped gear only. Do not try to prove item origin.

## Logging and Forgiveness Direction

The addon should preserve an audit trail.

Do not delete important history.

For violations:

- mark cleared violations as cleared
- store who cleared them
- store when they were cleared
- add a log entry when something is cleared
- include useful detail in both added and cleared entries, such as item names for gear issues when available

Death should not be clearable.

Compatibility blockers and conflicts are generally not clearable violations. They should resolve when the condition resolves.

Clearing a violation should be quick and low-friction for now: click Clear, preserve the audit trail, and do not require a typed reason unless that becomes valuable later.

Logs should read from top to bottom with the newest entries at the top.

## Sync Direction

Sync should be conservative.

Incoming remote sync should not directly overwrite local run validity, local deaths, local violations, local rules, or local run history unless the local user explicitly accepts a proposal/merge/change.

Incoming sync can update:

- remote player status
- peer data
- party status
- proposal status
- compatibility warnings
- shared display state

Party-visible logs and violations should eventually make the responsible character clear. Anyone-in-party clearing and shared log behavior should be designed conservatively so local history is not silently overwritten.

Handle edge cases gracefully:

- player reloads UI
- player disconnects
- player joins/leaves group
- player has different rules
- player has different run ID
- player has no addon or no recent sync
- stale messages arrive late

## Architecture Direction

Keep files modular.

Prefer small, targeted changes.

Before changing a feature, inspect the current implementation and preserve existing behavior unless the requested change explicitly replaces it.

Avoid broad rewrites.

Avoid adding external dependencies.

Use Lua 5.1-compatible code.

Do not add:

- combat automation
- rotation suggestions
- boss mechanic solving
- protected action button behavior
- external helper executables
- npm/build tooling
- obfuscated code

## Loose Roadmap

### Current Direction: Master Menu

Use the master menu as the main UI surface:

- Overview for local/party status
- Run for start/configuration, locked active rules, stop run, and future amendments
- Violations for active clearable issues
- Log for newest-first audit history

Older standalone windows may remain as fallbacks during development, but the product direction is to keep the user-facing UI centralized.

### Next: Status Dashboard / HUD

Improve the Overview tab and later add a small HUD for:

- local character status
- party status
- group members
- synced/unsynced state
- active violations
- failed characters
- conflicts/blockers

The dashboard should clearly separate:

- individual character validity
- party compatibility
- violations
- blockers/conflicts

The HUD should be minimal and glanceable, not a second full dashboard.

### Next: Sync and Party Audit Robustness

Improve party behavior so that:

- party violations and logs clearly show which character caused them
- active and cleared violations sync in a predictable way
- clearing remote-visible violations has a conservative shared history model
- players leaving/rejoining remain understandable without corrupting local state

### Later: Merge / Compatibility Flow

Support cases where players start separately but later want to group.

If rules are compatible but run IDs differ, the addon should not silently merge them.

A future flow may allow players to explicitly align or merge into a shared group run while preserving prior history.

### Later: Rule Amendments

Support changing rules mid-run through a visible amendment flow.

Rule changes should be logged.

Rule changes should generally apply going forward, not retroactively erase past violations.

### Later: Export / Session Summary

Add a copy/paste report for Discord or group review.

Possible contents:

- run ID or session identifier
- rules summary
- players
- current statuses
- active violations
- cleared violations
- deaths
- rule changes
- recent log entries

### Later: Polish

Only after core behavior is stable:

- minimap button
- lock/unlock frame
- compact/expanded views
- better styling
- better colors
- sound toggles and intentional addon sounds
- slash command help
- README cleanup
- changelog

## Testing Expectations

After each feature or bug fix, test in WoW.

Useful commands may include:

- `/reload`
- `/sc status`
- `/sc new`
- `/sc rules`
- `/sc log`
- `/sc violations`
- `/sc run`
- `/sc participants`
- `/sc conflicts`
- `/sc gear`
- `/sc dungeons`

Check for:

- no BugSack errors
- no UI overlap
- no nil errors when no run exists
- no accidental overwrites of active runs
- local character state not affected by remote events
- commands handling inactive states safely
- persistence after `/reload`

## Commit Discipline

After each working feature or bug fix, summarize changed files and commit.

Use concise commit messages like:

- `Fix start run UI layout`
- `Simplify rule options`
- `Add log window`
- `Add violation clearing`
- `Fix sync edge cases`
- `Add party dashboard`
- `Fix gear validation`
- `Fix proposal flow`
