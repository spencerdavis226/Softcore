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
- **Achievements**: account-level leveling, ruleset, and max-level milestones.

When no run is active, the menu focuses on starting a run. When a run is active, it focuses on current status.
The Run tab also includes compact own-character death announcement checkboxes beside the core death rules.

The Ironman preset follows the common WoW Challenges shape and allows flight paths. No-flight-path completion is tracked as a stricter achievement, including the Ironman + no flight paths + camera mode milestone.

## HUD

The HUD is a compact glance view shown during active runs.

- Toggle visibility with `/sc hud`.
- Starting a new run always shows the HUD by default.
- Lamp colors: green (valid), yellow (warning/conflict/blocked), orange (party member failed, local character still valid), red (local failed), gray (no run/pending).
- The text is intentionally short and single-line.
- Clicking the HUD opens the most relevant main tab (typically Overview, Violations, or Run).

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
| `/sc debuglog` or `/sc dl` | Open a copyable sync/audit debug export |
| `/sc debugclear` or `/sc dc` | Clear the in-memory debug trace and test counters before a test pass |
| `/sc syncdebug` or `/sc sd` | Print sync diagnostics |
| `/sc proposal` | Show the current pending proposal |
| `/sc propose` | Propose a grouped run from chat |
| `/sc propose-add Player-Realm` | Invite a party member into the current run |
| `/sc access` | Print access/storage rules |
| `/sc run chat` | Print run integrity summary |
| `/sc export` | Open a copyable CSV run summary for spreadsheets |
| `/sc export chat` | Print the CSV run summary to chat |
| `/sc debuglog chat` | Print the debug export to chat |
| `/sc announce off\|chat\|party\|guild` | Configure optional death announcements; combine targets with spaces |
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

Softcore syncs over Blizzard addon messages using the `SOFTCORE` prefix. It supports normal parties only; raid groups are treated as local-only and show a raid-unsupported note instead of syncing or displaying a 40-player roster.

Status heartbeats are sent every 10 seconds as a safety net, while user-driven changes send compact high-priority updates immediately. Proposals and rule amendments wake the Run tab with a tiny notice first, then fetch the larger rule details before acceptance is enabled. If details are delayed, the Run tab offers retry/decline/cancel controls instead of leaving the flow stuck. Party audit logs are treated as delayed bulk traffic so they do not slow proposal/rule controls. Reloading or rejoining may briefly show Unsynced until addon messages arrive. Use `/sc resync` or **Party Sync** in the Run tab if the display looks stale.

Party state is display and compatibility data. Remote state should not reset, fail, or overwrite the local character's run.

Contributor- and agent-oriented notes (module map, queue/stale-send behavior, what `/sc dc` resets) live in [`AGENTS.md`](AGENTS.md) under **Sync implementation map**. Anyone changing sync, UI, or commands should follow **Rolling documentation updates** there in the same commit.

Softcore sync is built around current WoW addon-message limits:

- The `SOFTCORE` prefix is registered after login/reload and must fit the 16-byte prefix limit.
- Addon message bodies are limited to 255 bytes and are delivered through `CHAT_MSG_ADDON`.
- `C_ChatInfo.SendAddonMessage` success means the client enqueued the message, not that peers have received it.
- Blizzard applies a per-prefix throttle; Softcore paces outbound messages through its send queue, prioritizes proposal/control/fresh-state traffic, coalesces disposable queued status updates, delays low-priority party audit logs, and chunks larger detail/full-state payloads.
- Common sync payload keys and message types are compacted on the wire while the Lua code keeps readable field names.
- Proposal and control retries must remain paced. Do not bypass the send queue for chunked messages.
- Rule serialization must preserve booleans exactly. `false` is a real rule value, not an empty string.
- Every enforced rule that affects local behavior must be part of the canonical ruleset sync/hash order. Camera rules (`firstPersonOnly`, `actionCam`) are included so a synced run cannot silently enforce camera on one client but not another.

If a party converts to a raid, Softcore stops party sync, clears remote roster display, and expires pending group proposals/amendments instead of applying them late. The local run remains active and locally tracked.

## Dungeon Handling

Softcore treats instance entry as an audit event, not as a protected gate. Manual entrances, Group Finder dungeon instances, follower dungeons, raids, scenarios, and instanced PvP are recorded in the local run ledger and shown by `/sc dungeons`.

Follower dungeons are allowed by default. Follower NPCs are not treated as unsynced party members; only real player party members can create synced-run compatibility issues.

Group Finder dungeons are allowed when the resulting player group is compatible with the run. If Group Finder adds unsynced, unconfirmed, or run-mismatched players, Softcore records that as an instance-with-unsynced-players rule outcome according to the active rules. This affects the ledger and party status, but it does not directly fail or reset the local character unless the accepted rules explicitly make that outcome fatal.

Raid groups remain local-only. Raid and scenario entries are logged as audit context, but they do not count as repeated dungeons. Repeated dungeon entries are tracked by instance name and governed by the repeated-dungeon rule.

## Graceful World Mechanics

Pet battles are allowed by default. Starting and ending a pet battle is logged locally for audit context and does not create a violation.

Quest vehicles, vehicle UI, override action bars, taxis, and forced movement are allowed by default. While those states are active, Softcore suppresses mount/flying rule outcomes so normal quest mechanics and forced flights do not create false violations. Player-selected flight paths are still detected through the taxi-node action when that rule is enabled.

Summons, portals, quest teleports, Chromie Time, Timewalking, level scaling, and similar world systems are treated as normal game context unless a future rule explicitly governs them.

## Separate Runs

If two players started separate runs, matching rules are not enough by themselves because each run has a different run ID.

Use **Party Sync** in the Run tab when:

- both characters have active runs
- rules match
- the players explicitly want to align to one shared run ID

Party Sync routes this case to a sync proposal for active run members. Accepting a sync proposal changes the accepting player's run ID to the proposer run ID. It does not wipe local deaths, violations, logs, or character progress.

If rules differ, Party Sync sends a rule amendment notice to active run members first, then receivers request the full current rules for review. Receivers compute and review only the values that differ from their own rules before accepting or declining. If the full-rules detail response already matches the receiver, Softcore acknowledges it without showing a stuck review. After an accepted stage settles, fresh sync responses wake the original clicker's Party Sync plan so it automatically continues to the next needed stage without waiting for the heartbeat.

Party Sync handles mixed parties in one staged plan: align active-run rules, align active-run IDs, then invite party members who are not in the run. While a proposal/amendment is pending or a rule change just settled, Party Sync waits or requests fresh state instead of starting another governance action. Stale party rows use targeted full-state requests where possible; retry timers remain as a fallback for reloads, throttling, or lost chunks. Party members who never respond to Softcore addon messages must install/enable the addon or leave the party before they can be included.

## Inviting Party Members

An active grouped player can use **Party Sync** in the Run tab to invite party members into the current run when they are not already in it.

Accepted invitees join the existing run ID after proposal confirmation. Existing participants keep their progress and logs.

Targeted invites are also available with `/sc propose-add Player-Realm`.

## Rule Amendments

Active run rules are locked by default. Use **Modify Rules** in the Run tab to create a draft. In grouped runs, **Modify Rules** and **Party Sync** share the same action slot: Party Sync is shown while the party has sync work or blockers, and Modify Rules returns once the party is synced.

- Solo: Apply Changes applies immediately and logs the old/new values.
- Grouped: Propose to Party creates a Run-tab amendment proposal.
- Members review the normal Run-tab rules layout with changed rules highlighted, then accept or decline from the bottom controls.
- All accept: proposer applies and broadcasts the amendment.
- Any decline: amendment is cancelled.

Pending amendments expire after 30 minutes. Late amendment messages are ignored after expiry.

## Violations And Failures

Death is permanent for the character.

Non-death disallowed actions generally create violations. Examples include disallowed bank/mail/auction/trade access, movement rules, and equipped gear rules.

Clearing a violation marks it cleared, records who cleared it and when, and preserves the audit trail. Death and fatal/character-fail violations are not clearable.

Remote violations may be displayed and shared as audit records for the same synced run, but they do not directly mutate local character validity.

Optional death announcements are for your own character only and default to off. Use `/sc announce chat party`, `/sc announce guild`, or the Run-tab checkboxes if you want Softcore to announce your own deaths; incoming announcements never change your local run state.

PvP safety checks are advisory only. During an active run, Softcore warns locally and records a local log entry when War Mode/player PvP flagging is detected or when you target a PvP-flagged player; these warnings do not fail the run, add violations, or sync to party members.

Use `/sc export` to open a comma-delimited CSV summary for spreadsheets. It is derived from the current local ledger: character, run ID/status, observed active time, death/violation/conflict counts, rules hash, participants, and recent log entries. The export is a convenience summary, not external verification.

## Persistence And Safety

Run data is stored per character in `SoftcoreCharDB`. This protects alts and replacement characters from inheriting another character's active run.

Softcore preserves the current run across `/reload`, logout, and party leave/rejoin. The addon does not start a new run or reset progress unless the local user starts, accepts, resets, retires, fails, or changes something through the UI/commands.

The Overview and `/sc run chat` show addon-observed active time for the current run. This is informational context for the ledger, not tamper-proof verification; time while logged out or between reload sessions is not counted.

Boundary behavior:

- Incomplete chunked sync messages are discarded after 30 seconds.
- Sync sequence checks are scoped by sender session, so a party member reinstalling, clearing saved variables, or reloading with a reset counter should not stay permanently ignored.
- Stale proposals expire after 30 minutes.
- Stale rule amendments expire after 30 minutes.
- Simultaneous incoming proposals are declined if another proposal is already pending.
- Remote status heartbeats update peer display/conflict data, but they do not add run participants unless normal late-join rules allow it.
- Remote violation-clear messages can only clear imported shared violations, not local authoritative violations.
- Remote deaths, failures, mismatches, or resets do not fail or reset the local character.

## Backend Hardening TODOs

- [x] Make sync stale-message protection tolerate peer sequence resets.
- [x] Keep raids explicitly local-only and expire pending group governance when a party converts to raid.
- [x] Audit remote status participant writes so same-run display remains useful without bypassing proposal, invite, late-join, or leader-approval rules.
- [ ] Add in-game party test passes for disconnect/reload, non-addon members, members joining/leaving during pending proposals, and rule amendment expiry.

## What Softcore Tracks

- Character name, realm, class, level, and zone
- Active run ID, start time, addon-observed active time, start level, rules, and party status
- Local deaths and violations
- Active and cleared violations
- Participants and participant states
- Rule amendments
- Party proposals, sync proposals, and run invites
- Party conflicts such as run mismatch, rules mismatch, version mismatch, unsynced members, and level-gap blockers
- Dungeon repeat state
- Equipped gear quality and heirloom checks
- Economy/storage/movement/access rule events, including flight path use
- Local PvP advisory warnings for War Mode, player PvP flagging, and PvP-flagged targets
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
