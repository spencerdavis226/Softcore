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
- **HUD**: compact active-run status display; click it to open or close the main menu on the relevant tab.
- **Minimap button**: opens the main menu.

There are no proposal popup windows. Incoming group proposals and rule amendments open the Charter tab for review.

## Main Menu

Open with `/sc menu`, the minimap button, or the HUD.

- **Overview**: dynamic run label based only on the current rule signature: four exact preset rule shapes plus 25 hidden custom rule profiles, all ending in "Run"; anything else shows **Custom Run**. The tab also shows an unmodified/last-modified-level rules detail, local run status, party status, elapsed time, deaths, active violation count, recent meaningful activity with character labels when space allows, and a compact party ledger for up to five members. The ledger shows each member's current level and, when their client reports it, level at run join, plus a class-colored badge when class data is available.
- **Charter**: start a run, review locked active rules in native-WoW styled rule groups, stop a run, invite party members, propose run sync, or modify rules. Proposal/amendment state is shown through the visible rule review and footer actions rather than a top detail banner.
- **Violations**: active issues in a virtualized compact list with one-click Clear where allowed, active/clearable/shared counts, and full-detail tooltips for long rows.
- **Log**: audit history, newest first, in a virtualized compact list. The menu caps the visible list to the newest 1000 displayable rows for responsiveness and always shows an **Export CSV** button; exports still include the full stored log. The menu and `/sc log` omit entries that are not relevant to your current rules (for example pet battles; taxi trips when flight paths are allowed even if mounts/flying are restricted; vehicle/override-bar notes when mounts and flying are both allowed; instance entries when no dungeon/unsynced-instance rules apply). A successful rule amendment produces one **Rules Amended** row per changed rule in plain language (for example "Auction house: restricted (was allowed)"); applying changes that match the current rules adds no log line.
- **Achievements**: account-level leveling, class, ruleset, and max-level milestones in an expandable native-WoW styled journal with category summaries, progress bars, and unique achievement-specific icons. Characters that complete a max-level run also get a hidden-until-earned **Completion Award** section for reopening the clean parchment award screen, which uses the same discovered run label as the Overview.

When no run is active, the menu focuses on starting a run. When a run is active, it focuses on current status.
The Charter tab groups setup into Run Charter, Access and Economy, Travel and Camera, Gear and Items, and Party and Dungeons sections using a consistent two-column rule grid. The Party and Dungeons section includes `Allow Unsynced Party Members`, which controls whether normal party play is allowed with real players who are not synced into the same Softcore run. Travel rule hover tooltips clarify mount-like racial and class forms such as Worgen Running Wild, Druid Travel/Flight Form, and Dracthyr Soar. Restrict Camera is a single rule with a mode selector for the active camera preference. Gear restriction uses a checkbox; when unchecked, any gear quality is allowed, and when checked, the dropdown selects the limit. A subordinate `Allow any self-crafted gear` checkbox is only active while gear restriction is enabled and is included in Modify Rules/amendment diffing. The Run Charter section also includes compact own-character death announcement checkboxes beside the core run options.
The `Casual` preset is the low-restriction baseline: grouped mode, unsynced party members allowed, no gear restriction, no enforced level gap, economy access allowed (including auction/mail/trade/banks), mounts/flying/flight paths allowed, heirlooms/enchants/consumables/repeated dungeons allowed, and instanced PvP disallowed. In grouped runs that disable unsynced party members, gaining XP, leveling, or entering dungeons/instances with unsynced, not-in-run, failed, or conflicting real party members can create a local violation. A failed member of your same Softcore run can still block progress when failed-member blocking is enabled; failed state from a different unsynced run is treated as diagnostic context when unsynced party play is allowed.
The `Chef's Special` preset is the addon creator's personal preferred run profile: grouped play with synced party members required by default, white/gray gear limits, trade and bank allowed while auction/mailbox/warband/guild banks stay disallowed, mounts and flight paths allowed (but not flying mounts), and enchants/consumables/repeated dungeons enabled. It has its own max-level achievement, **Chef's Table**, only when the run starts at level 10 or lower and finishes without rule amendments.
The `Ironman` preset follows the common WoW Challenges shape, allows flight paths, and keeps unsynced party play disabled as part of its stricter solo profile. `Iron Vigil` is the stricter Ironman variant with no flight paths, unsynced party play disabled, and cinematic camera enforced from run start. The enforced cinematic camera uses shoulder offset, dynamic pitch, closer zoom, and head movement, keeps the zoom limit consistent even while targeting enemies or interacting with NPCs, and does not focus the camera on hostile targets when they are selected. Preset achievements use the actual starting rule signature, not just the button that was clicked, and require starting at level 10 or lower with no rule amendments. White/gray-only progression is split so `White Knuckles` requires no self-crafted exemption, while `Self-Forged` tracks white/gray-only runs that keep the self-crafted exemption enabled from start to max level.
Rule-specific max-level achievements also require starting at level 10 or lower. Changing or violating one tracked rule only disqualifies that rule's achievement; unrelated rule achievements can still be earned if their restrictions stayed active from run start through max level. **Closed Circle** follows the rule-specific achievement pattern for runs that keep `Allow Unsynced Party Members` disabled from start through max level. **Party Survivor** means the run started in group mode; it does not require synced-only party play unless your selected rules do.

## HUD

The HUD is a compact glance view shown during active runs.

- Toggle visibility with `/sc hud`.
- Starting a new run always shows the HUD by default.
- The HUD also appears for pending governance states, such as run proposals before a run starts.
- Lamp colors: green (valid/synced), blue (syncing/settling), yellow (warning/conflict/blocked/review needed), orange (party member failed, local character still valid), red (local failed), gray (no run/pending).
- Solo rule edits apply locally without a HUD settling state; Settling is reserved for grouped proposal/amendment flow timing.
- The text is intentionally short and single-line, including limbo and blocker states such as Details, Review, Waiting, Settling, Syncing, Invite, Run Sync, No Addon, Offline, Raid Local, Version, Rules, Run ID, Not In Run, and Level Gap.
- Clicking the HUD opens the most relevant main tab (typically Overview, Violations, or Charter).

## Slash Commands

Use `/sc` for help.

Common commands:

| Command | What it does |
|---|---|
| `/sc menu` | Open the main menu |
| `/sc status` | Show current run status |
| `/sc rules` | Open Charter and rules |
| `/sc violations` | Open Violations |
| `/sc log` | Open Log |
| `/sc sync` | Request fresh party sync state |
| `/sc bug` | Open a bounded copyable bug-report export |
| `/sc reset` | Explain the destructive reset confirmation |

Use `/sc commands` for useful support and testing commands without exposing every internal endpoint.

Useful support commands:

| Command | What it does |
|---|---|
| `/sc export` | Open the full run CSV for spreadsheets |
| `/sc participants` | Print current participants |
| `/sc conflicts` | Print active party conflicts |
| `/sc gear` | Print equipped gear rule status |
| `/sc dungeons` | Print dungeon tracking state |
| `/sc sound on\|off\|test [event]` | Toggle Softcore UI sounds or play a test cue |
| `/sc announce off\|chat\|party\|guild` | Configure optional death announcements; combine targets with spaces |
| `/sc hud` | Toggle the HUD |
| `/sc minimap` | Toggle the minimap button |
| `/sc proposal` | Show the current pending proposal |
| `/sc accept` | Accept the current pending proposal |
| `/sc decline` | Decline the current pending proposal |
| `/sc propose-add Player-Realm` | Invite a party member into the current run |
| `/sc reset confirm end run` | Stop/reset the local active run |
| `/sc retire` | Retire this character from the active run |
| `/sc syncdebug` or `/sc sd` | Print sync diagnostics |
| `/sc debugclear <test>` or `/sc dc <test>` | Clear the in-memory debug trace and test counters before a test pass |
| `/sc debuglog`, `/sc dl`, `/sc bug`, or `/sc report` | Open a bounded copyable bug-report export |
| `/sc run chat` | Print run integrity summary |
| `/sc status chat` | Print status in chat |
| `/sc rules chat` | Print rules in chat |
| `/sc log chat` | Print recent log rows in chat |
| `/sc export chat` | Print the CSV run summary to chat |
| `/sc debuglog chat` | Print the bounded bug-report export to chat |

## Starting Runs

Solo runs start immediately from the Charter tab.

Grouped starts create a Charter-tab proposal:

1. The proposer configures rules and clicks Start Run.
2. Party members review the rules in the Charter tab.
3. Every current party member must accept.
4. The proposer confirms the run.
5. Accepted members start the same run ID and rules.

Declining cancels the proposal for everyone. Pending proposals expire after 30 minutes.

Softcore uses restrained UI sound cues for important moments: run start/completion, achievements, local deaths or violations, incoming governance that needs review, accepted/confirmed proposals, applied rule amendments, cancelled governance, and violation clears. Use `/sc sound off` to mute Softcore-specific cues or `/sc sound test list` to inspect the available test events.

## Existing Runs And Party Sync

Softcore syncs over Blizzard addon messages using the `SOFTCORE` prefix. It supports normal parties only; raid groups are treated as local-only and show a raid-unsupported note instead of syncing or displaying a 40-player roster.

Status heartbeats are sent every 10 seconds as a safety net, while user-driven changes send compact high-priority updates immediately. Proposals and rule amendments wake the Charter tab with a tiny notice first, then fetch the larger rule details before acceptance is enabled; acceptance and confirmation use explicit proposal controls, not status heartbeats alone. Proposal details, cancels, accepts, declines, and amendment responses are scoped to the original proposer/voters so unrelated party members cannot hijack or cancel a governance flow. If details are delayed, the Charter tab offers retry/decline/cancel controls instead of leaving the flow stuck. Party audit logs are treated as delayed bulk traffic so they do not slow proposal/rule controls. Reloading or rejoining may briefly show Unsynced until addon messages arrive. Use `/sc sync` or **Party Sync** in the Charter tab if the display looks stale.

Party state is display and compatibility data. Remote state should not reset, fail, or overwrite the local character's run. When your run allows unsynced party members, Softcore keeps mismatch data available for optional Party Sync without treating different run IDs, different rules, not-in-run members, non-addon party members, or failed characters from other unsynced runs as passive party blockers.

Contributor- and agent-oriented notes (module map, queue/stale-send behavior, what `/sc dc` resets) live in [`AGENTS.md`](AGENTS.md) under **Sync implementation map**. Anyone changing sync, UI, or commands should follow **Rolling documentation updates** there in the same commit.

UI layout and visual design guidance lives in [`DESIGN.md`](DESIGN.md). Use it when changing the Overview, Charter, HUD-adjacent menu behavior, or shared UI helpers.

Softcore sync is built around current WoW addon-message limits:

- The `SOFTCORE` prefix is registered after login/reload and must fit the 16-byte prefix limit.
- Addon message bodies are limited to 255 bytes and are delivered through `CHAT_MSG_ADDON`.
- `C_ChatInfo.SendAddonMessage` success means the client enqueued the message, not that peers have received it.
- Blizzard applies a per-prefix throttle; Softcore paces outbound messages through its send queue, prioritizes proposal/control/fresh-state traffic, coalesces disposable queued status updates, delays low-priority party audit logs, and chunks larger detail/full-state payloads. Chunk receive buffers expire without applying partial state, with larger chunk sets allowed more time under throttling.
- Common sync payload keys and message types are compacted on the wire while the Lua code keeps readable field names.
- Proposal and control retries must remain paced. Do not bypass the send queue for chunked messages.
- Rule serialization must preserve booleans exactly. `false` is a real rule value, not an empty string.
- Every enforced rule that affects local behavior must be part of the canonical ruleset sync/hash order. Enchants and camera rules (`firstPersonOnly`, `actionCam`) are included so a synced run cannot silently enforce them on one client but not another.

If a party converts to a raid, Softcore stops party sync, clears remote roster display, and expires pending group proposals/amendments instead of applying them late. The local run remains active and locally tracked.

## Dungeon Handling

Softcore treats instance entry as an audit event, not as a protected gate. Manual entrances, Group Finder dungeon instances, follower dungeons, raids, scenarios, and instanced PvP are recorded in the local run ledger and shown by `/sc dungeons`.

Follower dungeons are allowed by default. Follower NPCs are not treated as unsynced party members; only real player party members can create synced-run compatibility issues.

Group Finder dungeons and manual dungeon groups are allowed when `Allow Unsynced Party Members` is enabled. If that rule is disabled and the group includes unsynced, unconfirmed, run-mismatched, rules-mismatched, or addon-version-mismatched real players, Softcore records that as an instance-with-unsynced-players rule outcome according to the active rules. This affects the ledger and party status, but it does not directly fail or reset the local character unless the accepted rules explicitly make that outcome fatal.

Raid groups remain local-only. Raid and scenario entries are logged as audit context, but they do not count as repeated dungeons. Repeated dungeon entries are tracked by instance name and governed by the repeated-dungeon rule. Softcore remembers the current instance visit across `/reload`, so reloading inside the same dungeon should not count as a repeat; leaving and re-entering still does.

## Graceful World Mechanics

Pet battles are allowed by default and do not create a violation. They are still written to the stored audit log for exports but are hidden in the Log tab and `/sc log` as non-ruleset noise.

Quest vehicles, vehicle UI, override action bars, taxis, and forced movement are allowed by default. While those states are active, Softcore suppresses mount/flying rule outcomes so normal quest mechanics and forced flights do not create false violations. Player-selected flight paths are still detected through the taxi-node action when that rule is enabled. Druid land Travel/Mount Form and Worgen Running Wild follow the ground mount rule; Druid Flight Form and Dracthyr Soar follow the flying mount rule when the client reports flying or the known Soar aura.

Consumable restrictions are recorded after the client confirms the item spell succeeded when that spell data is available, so failed clicks, cooldown attempts, and unusable-context attempts should not create accidental violations. Bag, action-bar, and direct item-use paths are watched where the Retail client exposes stable hooks.

Summons, portals, quest teleports, Chromie Time, Timewalking, level scaling, and similar world systems are treated as normal game context unless a future rule explicitly governs them.

## Separate Runs

If two players started separate runs, matching rules are not enough by themselves because each run has a different run ID.

Use **Party Sync** in the Charter tab when:

- both characters have active runs
- rules match
- the players explicitly want to align to one shared run ID

Party Sync routes this case to a sync proposal for active run members. Accepting a sync proposal changes the accepting player's run ID to the proposer run ID. It does not wipe local deaths, violations, logs, or character progress.

If rules differ, Party Sync sends a rule amendment notice to active run members first, then receivers request the full current rules for review. Receivers compute and review only the values that differ from their own rules before accepting or declining. If the full-rules detail response already matches the receiver, Softcore acknowledges it without showing a stuck review. Allowing unsynced party members does not force this alignment; players with different runs or rules can keep playing together normally and click Party Sync only when they want to share a Softcore run. After an accepted stage settles, fresh sync responses wake the original clicker's Party Sync plan so it automatically continues to the next needed stage without waiting for the heartbeat.

Party Sync handles mixed parties in one staged plan: align active-run rules, align active-run IDs, then invite party members who are not in the run. While a proposal/amendment is pending or a rule change just settled, Party Sync waits or requests fresh state instead of starting another governance action. Stale party rows use targeted full-state requests where possible; retry timers remain as a fallback for reloads, throttling, or lost chunks. Party members who never respond to Softcore addon messages must install/enable the addon or leave the party before they can be included.

## Inviting Party Members

An active grouped player can use **Party Sync** in the Charter tab to invite party members into the current run when they are not already in it.

Accepted invitees join the existing run ID after proposal confirmation. Existing participants keep their progress and logs.

Targeted invites are also available with `/sc propose-add Player-Realm`.

## Rule Amendments

Active run rules are locked by default. Use **Modify Rules** in the Charter tab to create a draft. In grouped runs, **Modify Rules** and **Party Sync** share the same action slot: Party Sync is shown while the party has sync work or blockers, and Modify Rules returns once the party is synced.

- Solo: Apply Changes applies immediately and logs the old/new values.
- Grouped: Propose to Party creates a Charter-tab amendment proposal.
- Members review the normal Charter-tab rule groups with changed rules highlighted, then accept or decline from the bottom controls.
- All accept: proposer applies and broadcasts the amendment.
- Any decline: amendment is cancelled.

Pending amendments expire after 30 minutes. Late amendment messages are ignored after expiry.

## Violations And Failures

Death is permanent for the character.

Non-death disallowed actions generally create violations. Examples include disallowed bank/auction access, sending mail or taking inbox contents, accepting a trade or trade-window enchant, movement rules, equipped gear rules, permanently enchanted gear when enchants are disallowed, and gaining XP or leveling while grouped with a party member who is invalid for the current run. Opening a mailbox or trade window alone is allowed so accidental clicks or another player initiating trade cannot force violations. Repeated access-window and party-progress events are throttled so UI reopen or XP tick spam does not flood the ledger.

Clearing a violation marks it cleared, records who cleared it and when, and preserves the audit trail. Death and fatal/character-fail violations are not clearable. If a live access window, equipped-item rule, or active movement rule is still being broken when its violation is cleared, Softcore immediately rechecks that state and creates a fresh active violation as needed.

Remote violations may be displayed and shared as audit records for the same synced run, but they do not directly mutate local character validity.

Optional death announcements are for your own character only and default to off. Use `/sc announce chat party`, `/sc announce guild`, or the Charter-tab checkboxes if you want Softcore to announce your own deaths; incoming announcements never change your local run state.

PvP safety checks are advisory only. During an active run, Softcore warns locally and records a local log entry when War Mode/player PvP flagging is detected; these warnings do not fail the run, add violations, or sync to party members.

Use `/sc export` to open a comma-delimited CSV summary for spreadsheets. It is derived from the current local ledger: character, run ID/status, observed active time, death/violation/conflict counts, rules hash, participants, and the full stored audit log. The export is a convenience summary, not external verification.

For bug reports, use `/sc bug` or `/sc dl` after the problem happens. The copyable CSV is intentionally bounded for chat/email: it includes current character/run/rules/sync state, pending proposal/amendment state, participants, peers, conflicts, sync counters, the newest audit rows, the newest violations, and the capped debug trace. In multiplayer tests, send this export from every involved client after starting the test with `/sc dc <test name>`. Include any BugSack/Lua error text separately because Blizzard UI errors are not part of Softcore's SavedVariables ledger.

## Completion Awards

When an active valid run reaches max level after starting below max level, Softcore marks the local run completed, stops active tracking for that run, records a **Run Completed** audit row, plays achievement/completion feedback, and opens a clean parchment-style award screen with concise run statistics. The latest completion award is stored per character and can be reopened from the Achievements tab's **Completion Award** section or from the completed Overview state.

## Persistence And Safety

Run data is stored per character in `SoftcoreCharDB`. This protects alts and replacement characters from inheriting another character's active run.

Softcore preserves the current run across `/reload`, logout, and party leave/rejoin. The addon does not start a new run or reset progress unless the local user starts, accepts, resets, retires, fails, or changes something through the UI/commands.

The Overview and `/sc run chat` show addon-observed active time for the current run. This is informational context for the ledger, not tamper-proof verification; time while logged out or between reload sessions is not counted.

Boundary behavior:

- Incomplete chunked sync messages are discarded after a timeout; larger chunk sets receive more time under addon-message throttling.
- Sync sequence checks are scoped by sender session, so a party member reinstalling, clearing saved variables, or reloading with a reset counter should not stay permanently ignored.
- Stale proposals expire after 30 minutes.
- Stale rule amendments expire after 30 minutes.
- Simultaneous incoming proposals are declined if another proposal is already pending.
- Remote status heartbeats update peer display/conflict data, but they do not accept/confirm proposals or add run participants unless normal late-join rules allow it.
- Remote violation-clear messages can only clear imported shared violations from the peer that owns the violation, not local authoritative violations; heartbeat snapshots do not reactivate already-cleared shared rows.
- Remote deaths, failures, mismatches, or resets do not fail or reset the local character.

## Backend Hardening TODOs

- [x] Make sync stale-message protection tolerate peer sequence resets.
- [x] Keep raids explicitly local-only and expire pending group governance when a party converts to raid.
- [x] Audit remote status participant writes so same-run display remains useful without bypassing proposal, invite, late-join, or leader-approval rules.
- [ ] Add in-game party test passes for disconnect/reload, non-addon members, members joining/leaving during pending proposals, and rule amendment expiry.

## CurseForge Publish Checklist

Use this as the last-mile checklist before uploading a public file.

Release readiness:

- [ ] Run a syntax pass against all TOC-loaded Lua files.
- [ ] Verify the Retail interface number in-game with `/dump select(4, GetBuildInfo())` and update `## Interface` in `Softcore.toc` if needed.
- [ ] Confirm `## Version` in `Softcore.toc` and `SC.version` in `Core.lua` match the release version.
- [ ] Add or confirm the project license selected for CurseForge, and keep a local `LICENSE` file when possible.
- [ ] Prepare CurseForge page copy: short summary, full description, categories, logo, supported Retail version, release type, and changelog.
- [ ] For the first public upload, prefer `Beta` unless every multiplayer checklist below has passed cleanly.

Package contents:

- [ ] Build a clean zip with the top-level folder named `Softcore`.
- [ ] Include `Softcore.toc`, all Lua files loaded by the TOC, `Assets/*.tga`, `README.md`, changelog/release notes, and license.
- [ ] Exclude `.git`, `.claude`, `.cursor`, `.vscode`, `AGENTS.md`, `DESIGN.md`, editor files, local test files, and unused stubs such as empty files not loaded by the TOC.
- [ ] Install from the exact zip into a clean `Interface/AddOns` folder and confirm the addon appears as `Softcore`.

Single-client smoke test:

- [x] Log in with only Softcore plus normal debugging addons enabled.
- [x] Confirm no BugSack errors on login, `/reload`, opening the menu, and switching all tabs.
- [x] Run `/sc`, `/sc commands`, `/sc status`, `/sc rules`, `/sc log`, `/sc violations`, `/sc gear`, `/sc dungeons`, `/sc sound test list`, `/sc export`, and `/sc bug`.
- [x] Start a solo run, reload, and confirm run state, HUD, minimap button, logs, rules, and active time remain sane.
- [ ] Trigger or inspect representative rule checks where practical: gear, mailbox/bank/auction/trade access, mount/flying/flight-path rules, dungeon tracking, and violation clear.
- [ ] Verify inactive/no-run states do not nil-error after reset with `/sc reset confirm end run`.

Two-client party test setup:

- [ ] Computer A: `Cathe-Thrall`, usually party leader/proposer.
- [ ] Computer B: `Hordrien-Thrall`, usually party member/receiver/accepter.
- [ ] Start each test with `/reload` on both clients, then `/sc dc <test name>` on both clients.
- [ ] Use `/sc reset confirm end run` on both clients when a clean inactive state is required.
- [ ] After each sync-heavy action, wait 10-30 seconds for addon-message queue settling.
- [ ] After each pass, collect `/sc syncdebug` and `/sc bug` from both clients if anything looks wrong.

Two-client multiplayer checklist:

- [ ] Fresh grouped run proposal: A proposes, B reviews in Charter, B accepts, A confirms, both start the same run ID and rules hash.
- [ ] Party Sync for separate matching active runs: A routes through run-sync proposal, B accepts, both settle to the same run ID without wiping local history.
- [ ] Party Sync for mismatched active rules: A proposes amendment, B sees highlighted diffs, B accepts, both settle to the same rules hash with one meaningful amendment log row per changed rule.
- [ ] Invite into active run: A has active grouped run, B is not in run, Party Sync routes to invite, B accepts, both show compatible participant rows.
- [ ] Disconnect/reload: reload B during pending and settled states; verify stale rows recover through heartbeat/resync and no local run is reset.
- [ ] Non-addon member: add a player without Softcore or with addon disabled; verify Party Sync blocks inclusion after grace period and HUD/Charter show a clear blocker.
- [ ] Join/leave during pending proposal: party member leaves or joins while a proposal is pending; verify no late apply, no silent local mutation, and no audit spam.
- [ ] Proposal expiry: leave a proposal pending past 30 minutes or simulate the expiry path; late accept/confirm should be ignored.
- [ ] Rule amendment expiry: leave an amendment pending past 30 minutes or simulate the expiry path; late accept/apply should be ignored.
- [ ] Raid conversion: convert party to raid during or after governance; Softcore becomes local-only, clears remote roster display, and expires pending group governance without resetting local runs.
- [ ] Remote safety: remote death, reset, violation, rules mismatch, run mismatch, stale message, or violation clear never fails, resets, overwrites, or clears local authoritative state.
- [ ] Final pass checks on both clients: run ID, ruleset hash, pending proposal/amendment state, participants, party status, HUD lamp/text, active violations, conflicts, `/sc log`, `/sc syncdebug`, and no BugSack errors.

## What Softcore Tracks

- Character name, realm, class, level, and zone
- Active run ID, start time, addon-observed active time, start level, rules, and party status
- Per-character max-level completion award snapshot
- Local deaths and violations
- Active and cleared violations
- Participants and participant states
- Rule amendments
- Party proposals, sync proposals, and run invites
- Party conflicts such as run mismatch, rules mismatch, version mismatch, unsynced members, and level-gap blockers
- Dungeon repeat state
- Equipped gear quality, heirloom, and permanent enchant checks
- Economy/storage/movement/access rule events, including flight path use
- Local PvP advisory warnings for War Mode and player PvP flagging
- Audit log entries and shared same-run audit events

## Testing Checklist

Useful in-game checks:

- `/reload`
- `/sc commands`
- `/sc status`
- `/sc rules`
- `/sc log`
- `/sc violations`
- `/sc participants`
- `/sc conflicts`
- `/sc gear`
- `/sc dungeons`
- `/sc sync`
- `/sc bug`

Look for:

- no BugSack errors
- no UI overlap
- inactive/no-run states handled safely
- active runs preserved after `/reload`
- party leave/rejoin settling after sync heartbeat
- remote events not resetting local progress
- proposals and amendments expiring instead of applying late
