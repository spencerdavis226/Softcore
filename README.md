# Softcore

Softcore is a Retail World of Warcraft addon for hardcore-style leveling accountability with friends.

It tracks a per-character run, local deaths, rule violations, party compatibility, shared party audit events, and current run status. It is not server-side enforcement. The addon is meant to make group expectations visible and auditable while keeping each character's validity under that player's control.

## Install

1. Place the `Softcore` folder in `World of Warcraft/_retail_/Interface/AddOns/`.
2. Enable `Softcore` on the character-select addon screen.
3. Log in or run `/reload`.
4. Use `/sc` to confirm the addon loaded.

## UI Surfaces

Softcore has three frontend surfaces:

- **Main menu**: the primary interface for setup, status, proposals, violations, and logs.
- **HUD**: compact active-run status display.
- **Minimap button**: opens the main menu.

There are no proposal popup windows. Group proposals and rule amendments are reviewed in the Run tab.

## Main Menu

Open with `/sc menu`, the minimap button, or the HUD.

- **Overview**: local run status, party status, participants, run ID, elapsed time, deaths, and active violation count.
- **Run**: start a run, review locked active rules, stop a run, invite party members, propose run sync, or modify rules.
- **Violations**: active clearable issues with one-click Clear where allowed.
- **Log**: audit history, newest first.

When no run is active, the menu focuses on starting a run. When a run is active, it focuses on current status.

## HUD

The HUD appears when a run is active unless hidden with `/sc hud`.

- Green: valid/active
- Yellow: blocked, conflict, or violation
- Red: failed
- Grey: unsynced or inactive

Solo runs show local run status. Grouped runs show party status plus synced party members. Clicking the HUD opens the Violations tab if local active violations exist, otherwise Overview.

## Slash Commands

Use `/sc` for help.

Common commands:

| Command | What it does |
|---|---|
| `/sc menu` | Open the main menu |
| `/sc status` | Open Overview |
| `/sc status chat` | Print status in chat |
| `/sc rules` | Open Run |
| `/sc rules chat` | Print rules in chat |
| `/sc violations` | Open Violations |
| `/sc log` | Open Log |
| `/sc resync` | Request and broadcast party sync state |
| `/sc hud` | Toggle the HUD |
| `/sc minimap` | Toggle the minimap button |
| `/sc reset` | Stop/reset the local active run |
| `/sc retire` | Retire this character from the active run |
| `/sc accept` | Accept the current pending proposal |
| `/sc decline` | Decline the current pending proposal |
| `/sc gear` | Print equipped gear rule status |
| `/sc dungeons` | Print dungeon tracking state |
| `/sc participants` | Print current participants |
| `/sc conflicts` | Print active conflicts |
| `/sc proposal` | Show the current pending proposal |
| `/sc propose` | Propose a grouped run from chat |
| `/sc propose-add Player-Realm` | Invite a party member into the current run |
| `/sc access` | Print access/storage rules |
| `/sc run chat` | Print run integrity summary |
| `/sc rule name value` | Change or propose a single rule value |

## Starting Runs

Solo runs start immediately from the Run tab.

Grouped starts create a Run-tab proposal:

1. The proposer configures rules and clicks Start Run.
2. Party members review the rules in the Run tab.
3. Every current party member must accept.
4. The proposer confirms the run.
5. Accepted members start the same run ID and rules.

Declining cancels the proposal for everyone. Pending proposals expire after 30 minutes.

## Existing Runs And Party Sync

Softcore syncs over Blizzard addon messages using the `SOFTCORE` prefix. It automatically uses party, raid, or instance chat depending on group type.

Status heartbeats are sent every 10 seconds. Reloading or rejoining may briefly show Unsynced until addon messages arrive. Use `/sc resync` or the Overview Resync button if the display looks stale.

Party state is display and compatibility data. Remote state should not reset, fail, or overwrite the local character's run.

## Separate Runs

If two players started separate runs, matching rules are not enough by themselves because each run has a different run ID.

Use **Propose Sync** in the Run tab when:

- both characters have active runs
- rules match
- the players explicitly want to align to one shared run ID

Accepting a sync proposal changes the accepting player's run ID to the proposer run ID. It does not wipe local deaths, violations, logs, or character progress.

If rules differ, sync acceptance is blocked and the party remains in conflict until rules are aligned through accepted rule changes or another explicit choice.

## Inviting Party Members

An active grouped player can use **Invite Party** in the Run tab to invite party members into the current run.

Accepted invitees join the existing run ID after proposal confirmation. Existing participants keep their progress and logs.

Targeted invites are also available with `/sc propose-add Player-Realm`.

## Rule Amendments

Active run rules are locked by default. Use **Modify Rules** in the Run tab to create a draft.

- Solo: Apply Changes applies immediately and logs the old/new values.
- Grouped: Propose to Party creates a Run-tab amendment proposal.
- Members review changed rules and accept or decline.
- All accept: proposer applies and broadcasts the amendment.
- Any decline: amendment is cancelled.

Pending amendments expire after 30 minutes. Late amendment messages are ignored after expiry.

## Violations And Failures

Death is permanent for the character.

Non-death disallowed actions generally create violations. Examples include disallowed bank/mail/auction/trade access, movement rules, and equipped gear rules.

Clearing a violation marks it cleared, records who cleared it and when, and preserves the audit trail. Death and fatal/character-fail violations are not clearable.

Remote violations may be displayed and shared as audit records for the same synced run, but they do not directly mutate local character validity.

## Persistence And Safety

Run data is stored per character in `SoftcoreCharDB`. This protects alts and replacement characters from inheriting another character's active run.

Softcore preserves the current run across `/reload`, logout, and party leave/rejoin. The addon does not start a new run or reset progress unless the local user starts, accepts, resets, retires, fails, or changes something through the UI/commands.

Boundary behavior:

- Incomplete chunked sync messages are discarded after 30 seconds.
- Stale proposals expire after 30 minutes.
- Stale rule amendments expire after 30 minutes.
- Simultaneous incoming proposals are declined if another proposal is already pending.
- Remote violation-clear messages can only clear imported shared violations, not local authoritative violations.
- Remote deaths, failures, mismatches, or resets do not fail or reset the local character.

## What Softcore Tracks

- Character name, realm, class, level, and zone
- Active run ID, start time, start level, rules, and party status
- Local deaths and violations
- Active and cleared violations
- Participants and participant states
- Rule amendments
- Party proposals, sync proposals, and run invites
- Party conflicts such as run mismatch, rules mismatch, version mismatch, unsynced members, and level-gap blockers
- Dungeon repeat state
- Equipped gear quality and heirloom checks
- Economy/storage/movement/access rule events, including flight path use
- Audit log entries and shared same-run audit events

## Testing Checklist

Useful in-game checks:

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

Look for:

- no BugSack errors
- no UI overlap
- inactive/no-run states handled safely
- active runs preserved after `/reload`
- party leave/rejoin settling after sync heartbeat
- remote events not resetting local progress
- proposals and amendments expiring instead of applying late
