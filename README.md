# Softcore

Softcore is a lightweight Retail World of Warcraft addon for hardcore-style leveling accountability with friends.

Version 0.2.5 tracks your local run and syncs basic status with group members who also have Softcore installed.

## Setup

1. Place the `Softcore` folder in:
   `World of Warcraft/_retail_/Interface/AddOns/`
2. Enable `Softcore` on the character select addon screen.
3. Log in or run `/reload`.
4. Use `/sc status` to confirm the addon loaded.

## Slash Commands

- `/softcore` or `/sc` - show current status.
- `/sc start` - start a new local run.
- `/sc status` - print current run status.
- `/sc reset` - reset the local run.
- `/sc log` - print recent local event logs.

## What It Tracks

- Character name, realm, class, level, and zone.
- Run start time.
- Active, inactive, valid, and failed state.
- Death count and warning count.
- Recent local event log.
- Level changes and zone changes.
- Warnings for trade, mail, and auction house windows.

## Group Sync

Softcore uses Blizzard addon messages with the `SOFTCORE` prefix.

Status sync is sent only to the current group channel:

- `PARTY`
- `RAID`
- `INSTANCE_CHAT`

The group section of the UI shows nearby group members as `VALID`, `FAILED`, `INACTIVE`, or `UNSYNCED`. `UNSYNCED` means Softcore has not received a recent status update from that character.

No combat automation, combat recommendations, protected action buttons, or external libraries are used.
