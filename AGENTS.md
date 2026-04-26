# Softcore Addon Project Notes

Softcore is a Retail World of Warcraft Lua addon for hardcore-style leveling accountability with friends.

The addon is not server-side enforcement. It is a lightweight run ledger that helps players track deaths, rule breaks, group compatibility, logs, party state, and current run status.

## Current Product Shape

Softcore has three frontend surfaces:

- master menu
- HUD
- minimap button

The master menu is the primary interface. Group run proposals, run sync proposals, party invites, and rule amendments are reviewed in the Run tab. Do not add separate proposal popup windows.

Current menu tabs:

- `Overview`: local run status, party status, participant snapshot, run ID, elapsed time, deaths, and active violation count
- `Run`: start a run, review locked active rules, stop/reset a run, invite party, propose sync, and modify rules
- `Violations`: active clearable issues
- `Log`: audit history, newest first

The HUD is compact and glanceable. It shows local run status when solo and party status/member rows when grouped. The minimap button opens the main menu.

## Core Safety Principle

Softcore is individual-first.

A remote player death, failure, violation, unsynced state, ruleset mismatch, run mismatch, or reset must not directly fail, reset, overwrite, or invalidate the local player's character.

Local character validity and progress should change only from:

- the local character dying
- the local character triggering a local disallowed action
- the local character equipping disallowed gear
- the local user accepting a proposal
- the local user applying/accepting a rule amendment
- the local user retiring, resetting, stopping, or starting a run

Remote state is mainly display and compatibility data. It can affect derived party status, conflicts, shared audit display, and proposal state. It must not silently overwrite local run validity, local deaths, local violations, local rules, or local history.

## Persistence Model

Run data is per-character through `SoftcoreCharDB`.

This is intentional. A reroll, alt, or replacement character should not inherit another character's active run simply because the account previously used Softcore.

Do not move active run state back to account-wide storage unless there is a very deliberate migration plan. Account-wide history/export can be considered separately, but active run state should stay character-scoped.

## Sync Model

Sync uses Blizzard addon messages with the `SOFTCORE` prefix.

The channel is selected automatically:

- instance group: `INSTANCE_CHAT`
- raid: `RAID`
- party: `PARTY`

Status heartbeats are sent periodically. Full rules/proposals may be chunked. Incomplete chunk buffers expire and should never mutate run state.

Incoming sync can update:

- remote player status
- peer display data
- party status display
- compatibility warnings/conflicts
- proposal state
- shared same-run audit events
- shared same-run violations

Incoming sync must not directly:

- reset local run state
- fail local character
- clear local authoritative violations
- replace local rules
- overwrite local logs/history
- start a new run without local acceptance

## Proposal And Amendment Boundaries

Run proposals, run sync proposals, party invites, and rule amendments are explicit acceptance flows.

Current behavior:

- Group run start creates a Run-tab proposal.
- Separate active runs can align only through `Propose Sync`.
- Active players can invite party members through `Invite Party`.
- Mid-run rules change through `Modify Rules` and grouped amendment acceptance.
- Pending proposals expire after 30 minutes.
- Pending/accepted amendments expire after 30 minutes.
- Late proposal confirmations or amendment applies after expiry should be ignored.
- Simultaneous incoming proposals should not replace the local pending proposal.

Do not add automatic merge behavior for different run IDs. Aligning run IDs must remain explicit.

## Rule Philosophy

Death is permanent for the character.

Non-death rule breaks generally create violations rather than directly failing the character.

Examples of violations:

- opening a disallowed mailbox
- opening a disallowed bank
- opening the auction house when disallowed
- opening a trade window when disallowed
- using disallowed mounts or flying
- equipping disallowed gear

Examples of group blockers/conflicts:

- unsynced party member
- addon version mismatch
- ruleset mismatch
- run mismatch
- failed character still grouped
- max level gap exceeded, if enabled

Blockers and conflicts affect party status and display. They should not mutate individual character validity.

## Logging And Violations

Preserve audit history.

Do not delete important history. Clearing a violation should mark it cleared and log the clear event. Death and fatal/character-fail violations are not clearable.

Remote violation-clear messages may clear imported shared violations only. They must not clear local authoritative violations.

Logs should display newest first in the UI.

## UI Direction

Keep the addon compact and readable.

Prefer simple controls:

- checkboxes for allowed/disallowed rules
- short dropdown labels
- clear buttons for clearable violations
- Run-tab proposal states for group decisions

Avoid technical internal severity labels such as `LOG_ONLY`, `WARNING`, or `FATAL` in primary setup UI unless needed for debugging.

Avoid adding new windows. Use the master menu, HUD, or minimap button unless there is a strong reason.

## Architecture Direction

Keep files modular and changes targeted.

Use Lua 5.1-compatible code. Avoid external dependencies, build tooling, obfuscation, protected action behavior, combat automation, rotation suggestions, or boss-mechanic solving.

Before changing a feature, inspect the current implementation and preserve existing behavior unless the request explicitly replaces it.

## Testing Expectations

After each feature or bug fix, test in WoW when possible.

Useful commands:

- `/reload`
- `/sc status`
- `/sc rules`
- `/sc log`
- `/sc violations`
- `/sc participants`
- `/sc conflicts`
- `/sc gear`
- `/sc dungeons`
- `/sc resync`

Check for:

- no BugSack errors
- no UI overlap
- no nil errors when no run exists
- active run persistence after `/reload`
- party leave/rejoin settling after heartbeat or resync
- local character state not affected by remote deaths, resets, mismatches, or stale messages
- proposals/amendments expiring instead of applying late
- commands handling inactive states safely

## Commit Discipline

After each working feature or bug fix, summarize changed files and commit.

Use concise commit messages such as:

- `Fix proposal flow`
- `Harden sync edge cases`
- `Improve party run UI`
- `Fix gear validation`
