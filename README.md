# Softcore

Softcore is a lightweight Retail World of Warcraft addon for hardcore-style leveling accountability with friends.

Version 0.3.0 tracks your local run, applies structured rules, syncs resilient status, and includes a simple group run proposal flow.

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
- `/sc log` - print recent local event logs.
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
- Death count and warning count.
- Run participants and participant status.
- Party status: `VALID`, `WARNING`, `BLOCKED`, `UNSYNCED`, `CONFLICT`, or `INACTIVE`.
- Structured ruleset values and prospective rule amendments.
- Storage/economy access openings for bank, Warband bank, guild bank, void storage, crafting orders, and vendors.
- Equipped gear quality and heirloom checks.
- Party level-gap checks and dungeon repeat tracking.
- Leaderless governance for active-party-majority style runs.
- Sync metadata for run, ruleset, addon version, sender sequence, and conflict detection.
- Recent local event log.
- Level changes and zone changes.
- Warnings for trade, mail, and auction house windows.
- Death is always permanent for the character that died.

## Group Sync

Softcore uses Blizzard addon messages with the `SOFTCORE` prefix.

Status sync is sent only to the current group channel:

- `PARTY`
- `RAID`
- `INSTANCE_CHAT`

The group section of the UI shows nearby group members as `VALID`, `FAILED`, `INACTIVE`, or `UNSYNCED`. `UNSYNCED` means Softcore has not received a recent status update from that character.

## Group Proposals

Use `/sc new` to configure a run name and rules. The window is organized into Run Setup, Core Rules, Economy / Storage, Movement, Gear / Item, and Group / Dungeon sections. Rule dropdowns show friendly labels such as `Allowed`, `Log only`, `Warning`, and `Fatal`; gear uses `No restriction`, `White/gray only`, `Up to green`, and `No epics`.

The Core Rules section keeps death simple: death is permanent for each character. Grouping is controlled by one `Grouping Mode` option:

- `Group allowed with synced Softcore players` lets synced players with the same run and rules join and leave freely. Failed characters still block the party while grouped.
- `Solo / self-found only` does not auto-add group members as valid run participants. Grouping with outside or unsynced players applies the configured grouping/unsynced rule behavior.

`Unsynced group member` controls what happens when a current group member is not synced with the local Softcore run: `Allowed`, `Log only`, `Warning`, or `Fatal`.

`Propose Run` sends the proposal to the current party. Other players can accept or decline from the popup or with `/sc accept` and `/sc decline`. A proposed run does not become active for a player until they accept it.

For late or replacement joins, use `/sc propose-add Player-Realm`. Failed characters remain failed; a replacement character is tracked separately by `Player-Realm`.

No combat automation, combat recommendations, protected action buttons, or external libraries are used.
