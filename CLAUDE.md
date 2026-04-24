# Softcore Addon Project Context

Softcore is a Retail World of Warcraft Lua addon for hardcore-style leveling with friends.

## Core Principle

Softcore is individual-first.

A party member’s failure, death, violation, mismatch, or unsynced state must never fail or mutate the local player’s individual run.

Individual character state is authoritative only for the local character.

Remote player state is advisory/display-only.

Party status is derived and non-authoritative.

## Current Architecture

The addon tracks:

- local run state
- local character status
- deaths
- violations
- rules
- participant/peer sync
- party compatibility status
- proposal/accept/decline flow
- storage/economy restrictions
- gear/item restrictions
- safe command behavior

Current slash commands include:

- /sc
- /softcore
- /sc status
- /sc start
- /sc new
- /sc reset
- /sc reset confirm
- /sc rules
- /sc rule
- /sc log
- /sc gear
- /sc dungeons
- /sc participants
- /sc run
- /sc conflicts
- /sc accept
- /sc decline
- /sc proposal

## Safety Rules

Do not add:

- combat automation
- rotation suggestions
- boss mechanic logic
- protected action buttons
- external dependencies
- npm/build tooling
- obfuscated code

Use Lua 5.1-compatible code.

Keep changes modular and incremental.

Do not rewrite the whole addon unless explicitly asked.

## Design Rules

Death is always permanent for the local character.

Non-death rule breaks create violations, not character failure.

Examples of violations:

- opening a disallowed mailbox
- opening a disallowed bank
- opening a disallowed auction house
- opening a disallowed trade window
- equipping disallowed gear
- using disallowed mounts/flying

Compatibility blockers are not violations and should not affect local character validity.

Examples of blockers:

- unsynced party member
- ruleset mismatch
- run mismatch
- failed character still grouped
- max level gap exceeded

## Grouping Model

Grouping should be simple.

Grouping Mode options:

- Group
- Solo

Internal mapping:

- Group -> SYNCED_GROUP_ALLOWED
- Solo -> SOLO_SELF_FOUND

In Group mode:

- party members must be running Softcore
- party members must have matching rules
- unsynced members block group progress
- failed characters block group progress while grouped
- party members can join/leave freely if synced and compatible
- no manual approval is needed for normal joining

In Solo mode:

- grouping is disallowed
- grouping should create the appropriate violation/blocker depending current rules

## Start Run UI Direction

The Start New Run UI should be simple.

Remove:

- run name field
- separate Start Solo Run and Propose Run buttons
- severity dropdowns like Log only / Warning / Fatal
- Unsynced group member dropdown
- Death fails character checkbox
- Failed character blocks party checkbox
- Allow late joiner checkbox
- Allow replacement character checkbox
- Require approval checkbox

Use:

- static text: "Death is permanent for each character."
- Grouping dropdown: Group / Solo
- checkboxes for disallowed actions
- one primary button

Primary button behavior:

- if solo: button says "Start Run" and starts immediately
- if grouped: button says "Propose Run" and sends proposal
- if proposal pending: button says "Proposal Pending"

If grouped, the run should not activate until all current group members accept.

## Current Requested Change

Implement v0.3.2 simplification:

1. Shorten grouping dropdown to:
   - Group
   - Solo

2. Add helper text:
   "Group: party members must be synced with matching Softcore rules."

3. Remove Log only, Warning, and Fatal from the Start Run GUI.

4. Use Allowed/Disallowed style internally for GUI-selected rules.

5. Economy/storage rules should be checkboxes:
   - Disallow Auction House
   - Disallow Mailbox
   - Disallow Trade
   - Disallow Bank
   - Disallow Warband Bank
   - Disallow Guild Bank

6. Movement rules should be checkboxes:
   - Disallow mounts
   - Disallow flying

7. Gear rules should be:
   Label: Gear limit
   Options:
   - Any gear -> ALLOWED
   - White/gray only -> WHITE_GRAY_ONLY
   - Green or lower -> GREEN_OR_LOWER
   - Blue or lower -> BLUE_OR_LOWER

8. Remove "Epic or lower".

9. Keep heirlooms separate:
   - Disallow heirlooms

10. Group/Dungeon:

- Enforce max level gap checkbox
- Max gap numeric field
- Disallow repeated dungeons checkbox

11. Remove violation behavior dropdown under max level gap.

12. Remove separate Start Solo Run and Propose Run buttons.
    Use one dynamic primary button:

- Start Run when solo
- Propose Run when grouped
- Proposal Pending when a proposal is pending

13. Remove the run name field.
    Generate a default run name internally if needed.

14. Unsynced group members are always party blockers in Group mode.
    They do not fail or mutate the local player's character state.

15. Update README.md for the simplified rules.

## Testing Commands

After changes, test in WoW:

/reload
/sc new
/sc reset confirm
/sc new
/sc status
/sc run
/sc rules
/sc gear
/sc dungeons

Expected:

- no BugSack errors
- Start New Run UI has no overlapping controls
- Grouping dropdown says Group / Solo
- no Log only / Warning / Fatal options in the Start Run GUI
- no run name field
- one primary button
- gear options are Any gear, White/gray only, Green or lower, Blue or lower
- Max level gap has checkbox + number only
- no violation behavior dropdown
