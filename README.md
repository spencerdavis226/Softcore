# Softcore

Softcore is a lightweight Retail World of Warcraft addon for hardcore-style leveling accountability with friends.

Version 0.4.0 tracks your local run, applies structured rules, syncs resilient status, includes a simple group run proposal flow, and provides a log/violation review GUI.

## Setup

1. Place the `Softcore` folder in:
   `World of Warcraft/_retail_/Interface/AddOns/`
2. Enable `Softcore` on the character select addon screen.
3. Log in or run `/reload`.
4. Use `/sc status` to confirm the addon loaded.

## Slash Commands

- `/softcore` or `/sc` - show current status.
- `/sc start` - start a new local run.
- `/sc new` - open the Start New Run window.
- `/sc status` - print current run status.
- `/sc reset confirm` - reset the local run.
- `/sc log` - open the Log GUI (Events tab). Use `/sc log chat` to print to chat instead.
- `/sc violations` - open the Log GUI on the Violations tab.
- `/sc gear` - print gear rules and invalid equipped items.
- `/sc dungeons` - print dungeon entries for the current run.
- `/sc roster` - print tracked run participants.
- `/sc add Player-Realm` - add a pending participant until the v0.3 join UI exists.
- `/sc retire` - retire this character without marking it failed.
- `/sc rules` - print the current ruleset.
- `/sc rule mailbox ALLOWED` - change a rule locally and log a prospective amendment.
- `/sc resync` - request full run state from party members.
- `/sc participants` - print tracked run participants.
- `/sc run` - print run metadata.
- `/sc conflicts` - print detected sync conflicts.
- `/sc access` - print storage and economy access rules.
- `/sc propose` - open/propose a new group run.
- `/sc proposal` - show the pending proposal.
- `/sc accept` - accept the pending proposal.
- `/sc decline` - decline the pending proposal.
- `/sc propose-add Player-Realm` - propose a late or replacement participant.

## What It Tracks

- Character name, realm, class, level, and zone.
- Run start time.
- Active, inactive, valid, and failed state.
- Death count and violation count.
- Run participants and participant status.
- Party status: `VALID`, `BLOCKED`, `CONFLICT`, `UNSYNCED`, `VIOLATION`, or `INACTIVE`.
- Structured ruleset values and prospective rule amendments.
- Storage/economy access openings for bank, Warband bank, guild bank, void storage, crafting orders, and vendors.
- Equipped gear quality and heirloom checks.
- Party level-gap checks and dungeon repeat tracking.
- Leaderless governance for active-party-majority style runs.
- Sync metadata for run, ruleset, addon version, sender sequence, and conflict detection.
- Recent local event log.
- Level changes and zone changes.
- Violations for disallowed trade, mail, auction house, storage, movement, gear, or dungeon actions.
- Death is always permanent for the character that died.

## Group Sync

Softcore uses Blizzard addon messages with the `SOFTCORE` prefix.

Status sync is sent only to the current group channel:

- `PARTY`
- `RAID`
- `INSTANCE_CHAT`

The group section of the UI shows nearby group members as `VALID`, `FAILED`, `INACTIVE`, `BLOCKED`, `CONFLICT`, or `UNSYNCED`. `UNSYNCED` means Softcore has not received a recent status update from that character.

A party member's failure does not fail your character. Softcore shows group blockers and conflicts, but each character's run validity is individual.

## Group Proposals

Use `/sc new` to configure and start a run. The window is organized into Run Setup, Core Rules, Economy / Storage, Movement, Gear / Item, and Group / Dungeon sections. Most rules are simple allowed/disallowed checkboxes.

Death is permanent per character.

Grouping mode has two choices:

- `Group` requires party members to be synced with matching Softcore rules. Unsynced members block group progress but do not fail anyone.
- `Solo` does not auto-add group members as valid run participants. Grouping can create a local violation according to the solo/self-found grouping rule.

The primary button at the bottom of the window is dynamic:

- **Start Run** — shown when the player is not grouped. Clicking starts the run immediately.
- **Propose Run** — shown when the player is grouped. Clicking sends a proposal to all current party members.
- **Proposal Pending** — shown while waiting for all party members to accept.

A proposed run does not start for any player until all current party members accept. If any member declines, the proposal is cancelled for everyone. All party members must be running Softcore and synced before the run can begin. Use `/sc accept` or `/sc decline` as slash-command fallbacks.

Disallowed actions create violations. Event violations, like opening a disallowed mailbox, can be reviewed and cleared in the Log GUI (`/sc violations`). State violations, like invalid equipped gear, remain active until the condition is fixed and then cleared with a reason. Compatibility blockers — unsynced party members, rule mismatches, or a level gap above the allowed maximum — block party progress but do not fail any character and are not violations.

## Violations and the Log GUI

Use `/sc log` to open the Log GUI. The **Events** tab shows a scrollable history of recorded events. The **Violations** tab shows a paginated list of all violations with their current status.

Violations are never deleted. Cleared violations remain in the audit log marked `CLEARED` with the reason and who cleared them.

Rules for clearing violations:

- Death violations are **never** clearable.
- Fatal or character-fail severity violations are **never** clearable.
- Compatibility blocker types (unsynced members, level gap, outsider grouping) are **never** clearable.
- All other violations — including gear violations — can be cleared by entering a reason in the Log GUI.

Gear limit tiers are:

- `Any gear`
- `White/gray only`
- `Green or lower`
- `Blue or lower`

For late or replacement joins, use `/sc propose-add Player-Realm`. Failed characters remain failed; a replacement character is tracked separately by `Player-Realm`.

No combat automation, combat recommendations, protected action buttons, or external libraries are used.
