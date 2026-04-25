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

Prefer clear user-facing concepts:

- `Failed`: a character died or permanently failed
- `Violation`: a rule was broken
- `Cleared`: a violation was reviewed and forgiven, but not deleted
- `Blocked`: group progress is blocked by a compatibility issue
- `Conflict`: rules/run mismatch
- `Unsynced`: a party member is not syncing valid Softcore data
- `Valid`: character is alive and has no active issues

Avoid exposing overly technical internal states in the UI unless needed.

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

The Start Run UI should stay simple.

Prefer:

- clear rule sections
- concise wording
- minimal required inputs
- one obvious primary action
- no unnecessary run-name or setup friction unless needed
- safe behavior when a run is already active

Starting while solo can start immediately.

Starting while grouped may need a proposal/acceptance flow so everyone uses compatible settings.

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

Death should not be clearable.

Compatibility blockers and conflicts are generally not clearable violations. They should resolve when the condition resolves.

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

### Near-term: Log / Violations UI

Build or improve a GUI for:

- viewing events
- viewing active violations
- clearing accidental violations while preserving audit history
- preserving audit history

### Next: Status Dashboard

Build a clearer dashboard for:

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
- sound toggles
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
