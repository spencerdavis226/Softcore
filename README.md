# Softcore

Softcore is a lightweight Retail World of Warcraft addon for hardcore-style leveling accountability with friends.

Version 0.5.0 tracks your local run, applies structured rules, syncs party status in real time, includes a group run proposal and amendment flow, and provides a master menu for run setup, status, logs, and violation review.

## Setup

1. Place the `Softcore` folder in:
   `World of Warcraft/_retail_/Interface/AddOns/`
2. Enable `Softcore` on the character select addon screen.
3. Log in or run `/reload`.
4. Use `/sc` to confirm the addon loaded.

## Slash Commands

Type `/sc` in-game to see the full help list. Common commands:

| Command | What it does |
|---|---|
| `/sc` | Show help |
| `/sc menu` | Open the Softcore menu |
| `/sc reset` | Stop the current run (shows confirmation) |
| `/sc hud` | Toggle the compact status HUD |
| `/sc minimap` | Toggle the minimap button |
| `/sc resync` | Re-request full state from party members |

Additional commands for inspecting state in chat:

| Command | What it does |
|---|---|
| `/sc status` | Open the Overview tab (or `/sc status chat` to print) |
| `/sc rules` | Open the Run tab (or `/sc rules chat` to print) |
| `/sc log` | Open the Log tab (or `/sc log chat` to print) |
| `/sc violations` | Open the Violations tab |
| `/sc gear` | Print gear rules and any invalid equipped items |
| `/sc dungeons` | Print dungeon entries for the current run |
| `/sc retire` | Retire this character without marking it failed |
| `/sc accept` | Accept a pending group run proposal |
| `/sc decline` | Decline a pending group run proposal |

## The Menu

Use `/sc menu` or click the minimap button to open the main menu. Four tabs:

- **Overview** — your current run status and party member states
- **Run** — start a run, review active rules, stop a run, or propose rule amendments
- **Violations** — active issues with a one-click clear where allowed
- **Log** — full audit history, newest first

When no run is active, the menu opens to the Run tab for setup. When a run is active, it opens to Overview.

## The HUD

A small always-visible overlay that shows when a run is active. Each row is a colored dot + name:

- **Green** — Active / Valid
- **Yellow** — Blocked, Conflict, or Violation
- **Red** — Failed
- **Grey** — Unsynced or Inactive

When solo it shows `Run Status`. When in a party it shows `Party Status` plus each group member. Active violations are shown below the list. Click the HUD to open the menu (or the Violations tab if you have active violations).

Use `/sc hud` to hide or restore it.

## Starting a Run

Open the menu and go to the **Run** tab. Configure your rules:

- **Grouping mode** — `Group` (party-synced) or `Solo Only`
- **Economy & Storage** — auction house, mail, bank, guild bank, void storage, etc.
- **Movement** — flying mounts
- **Gear** — allowed quality tier and heirloom rules
- **Group rules** — dungeon repeats, enforce level gap between party members

Solo runs start immediately. Group runs send a proposal to your current party — all members must accept before the run begins.

## Group Sync

Softcore uses Blizzard addon messages (`SOFTCORE` prefix) to sync status across your group. All members must have the addon installed and enabled.

Party member states shown in the Overview and HUD:

- `VALID` — in the run, no issues
- `BLOCKED` — compatibility blocker (unsynced member, level gap, rule mismatch)
- `CONFLICT` — conflicting run data detected
- `UNSYNCED` — no recent status received from this player
- `VIOLATION` — active uncleared violation
- `FAILED` — character has died (permanent)
- `INACTIVE` — not in a run

A party member's death or failure does **not** fail your character. Softcore tracks each character individually.

Use `/sc resync` if your party status looks wrong.

## Rule Amendments

Mid-run rule changes go through an amendment proposal. In the **Run** tab, click **Modify Rules** to enter draft mode. Changed rules highlight in green or red. Click **Propose to Party** to send the draft to your group — each member gets an Accept/Decline overlay. Once all accept, changes apply and are logged. If anyone declines, the amendment is cancelled.

## Violations

Disallowed actions create violations. Event violations (e.g. opening a disallowed mailbox) can be reviewed and cleared from the Violations tab. State violations (e.g. invalid equipped gear) stay active until the condition is resolved.

Rules for clearing:
- Death violations are **never** clearable
- Fatal/character-fail violations are **never** clearable
- All other violations can be cleared with one click

## What It Tracks

- Character name, realm, class, level, and zone
- Run start time, active/inactive/failed state
- Death count and active violation count
- Run participants and each participant's status
- Party level-gap checks and dungeon repeat tracking
- Storage and economy access events (bank, Warband bank, guild bank, void storage, crafting orders, vendors)
- Equipped gear quality and heirloom checks
- Recent local event log
- Sync metadata, sequence numbers, and conflict detection
