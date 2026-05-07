# Softcore

Softcore is a Retail World of Warcraft addon for hardcore-style leveling accountability with friends.

It keeps a per-character run ledger with deaths, rule violations, party compatibility, audit history, achievements, and current run status. It is not server-side enforcement. The goal is to make the group's agreement visible while keeping each character's validity under that player's control.

## Install

1. Place the `Softcore` folder in `World of Warcraft/_retail_/Interface/AddOns/`.
2. Enable `Softcore` on the character-select addon screen.
3. Log in or run `/reload`.
4. Use `/sc` to confirm the addon loaded.

## What You Get

- A compact main menu for starting runs, reviewing rules, checking status, clearing allowed violations, reading logs, and tracking achievements.
- A HUD for quick local or party status.
- A minimap button for opening the main menu.
- Party proposals, run sync proposals, party invites, and rule amendments inside the Charter tab, without extra popup windows.
- Advisory item tooltip warnings for wearable gear, enchants, heirlooms, consumables, and other item restrictions.
- CSV export for the local run ledger and a bounded bug-report export for testing or support.

## Main Menu

Open the menu with `/sc menu`, the minimap button, or by clicking the HUD.

| Tab | Purpose |
|---|---|
| Overview | Current run label, local status, party status, deaths, violations, active time, recent meaningful activity, and a compact party ledger. |
| Charter | Start runs, choose presets, review active rules, use Party Sync, modify rules, and respond to proposals or amendments. |
| Violations | Active issues with compact rows, counts, tooltips, and one-click Clear where allowed. |
| Log | Newest-first audit history with low-value rows filtered from display; CSV export always remains available. |
| Achievements | Account-level milestones, rule and class achievements, max-level progress, and earned completion awards. |

The Overview run label comes from the current rule signature. Exact known profiles show their run names; anything else is shown as **Custom Run**.

## Run Presets

Softcore includes four visible presets:

| Preset | Shape |
|---|---|
| Casual | Low-restriction grouped baseline. Unsynced party play, economy access, mounts, flying, flight paths, consumables, heirlooms, enchants, and repeated dungeons are allowed; instanced PvP is blocked. |
| Chef's Special | Creator-preferred profile. Synced party members are required by default, white/gray gear limits are enabled, bank is allowed, trade/auction/mailbox/warband/guild banks are blocked, flying mounts are blocked, and enchants stay enabled. |
| Bronzeman | Stricter solo-leaning challenge profile, with flight paths allowed and unsynced party play disabled. |
| Bronze Vigil | A harder Bronzeman variant with no flight paths, cinematic camera, and Explorer Mode enforced. |

There are also hidden custom rule profiles that can still be recognized by the run-label system when their exact rules match. Head Chef's Special is recognized as Chef's Special with Explorer Mode enabled. Any edited or unmatched ruleset becomes **Custom Run**.

## Starting Runs

Solo runs start immediately from the Charter tab.

Grouped starts use a Charter-tab proposal:

1. The proposer configures rules and clicks Start Run.
2. Party members review the proposal in Charter.
3. Every current party member accepts or someone declines.
4. The proposer confirms after everyone accepts.
5. Accepted members start the same run ID and rules.

Pending proposals expire after 30 minutes. Declining cancels the proposal for everyone.

## Party Sync

Softcore syncs with Blizzard addon messages using the `SOFTCORE` prefix on party or instance-chat channels. Normal parties are supported; raid groups are treated as local-only because the UI is designed for party scale.

Use **Party Sync** in the Charter tab, or `/sc sync`, when the party display looks stale or when players want to align active runs. In a party, the Charter Party Sync button can stay visible (sometimes disabled) during an open proposal so the tooltip still explains what to do next.

Party Sync can:

- refresh stale party status
- align separate active runs with the same rules into one run ID after explicit acceptance
- propose rule amendments when active run rules differ
- invite party members who are not yet in the run

Remote party state is display and compatibility data. It must not reset, fail, overwrite, or silently mutate your local character. Local run state changes only from local deaths, local violations, and local user actions such as accepting a proposal, applying a rule amendment, starting, resetting, stopping, or retiring a run.

## Rules And Violations

Death is permanent for the character.

Most non-death rule breaks create violations instead of directly failing the run. Examples include disallowed bank or auction access, sending mail or taking mail, accepting a trade when trade is restricted, using restricted movement, equipping restricted wearable gear, equipping permanently enchanted gear when enchants are disallowed, and gaining XP with an invalid party member when the active rules block that party state.

Opening a mailbox or trade window alone is allowed so accidental clicks or another player initiating trade cannot force a violation.

Clearing a violation preserves the audit trail and logs the clear event. Death and fatal/character-fail violations are not clearable. Live-state checks, such as equipped gear or active movement forms, are rechecked after clearing so unresolved behavior can create a fresh active violation.

Explorer Mode is an immersion rule. While active, Softcore hides Blizzard quest guidance such as quest objective blobs, super-tracked arrows, auto quest watch, and the minimap display, then restores the prior settings when the rule no longer applies. Third-party quest helpers may still draw their own arrows or pins.

## Achievements And Completion

Achievements are grouped by level milestones, max-level runs, preset challenges, class mastery, and rule families for access, travel, gear/items, and party/instance restrictions. Inside each group, in-progress achievements sort by highest percent progress first; completed achievements move to the bottom of that group. Harder preset variants can satisfy their base preset achievement where appropriate: Head Chef's Special counts for Chef's Table, and Bronze Vigil counts for Bronzeman.

Max-level completion uses the same discovered run label shown on Overview. When an active valid run completes, Softcore records the completion, plays restrained feedback, and opens a parchment-style award with concise run statistics. The latest completion award is stored per character and can be reopened from the Achievements tab.

## HUD And Sounds

The HUD is a small status strip for the active run, party state, and pending governance. It also appears for proposal or amendment review before a run is active. Click it to open the most relevant menu tab.

HUD text is intentionally short, using labels such as `Review`, `Waiting`, `Settling`, `Syncing`, `Invite`, `Run Sync`, `No Addon`, `Offline`, `Raid Local`, `Version`, `Rules`, `Run ID`, `Not In Run`, and `Level Gap`.

Explorer Mode hides the minimap display during active runs while preserving surrounding Blizzard controls such as the addon compartment, location, clock, and calendar when possible. Softcore remains available through the HUD, addon compartment, and a small Explorer tray button.

Softcore UI sounds are restrained and limited to important moments such as run start/completion, achievements, local deaths or violations, incoming review, accepted or applied governance, cancellations, and violation clears. Use `/sc sound off` to mute them or `/sc sound test list` to inspect available cues.

## Slash Commands

Use `/sc` for everyday help and `/sc commands` for the fuller support list.

Common commands:

| Command | What it does |
|---|---|
| `/sc menu` | Open the main menu. |
| `/sc status` | Show current run status. |
| `/sc rules` | Open Charter and rules. |
| `/sc violations` | Open Violations. |
| `/sc log` | Open Log. |
| `/sc sync` | Request fresh party sync state. |
| `/sc bug` | Open a bounded copyable bug-report export. |
| `/sc reset` | Explain the destructive reset confirmation. |

Useful support commands:

| Command | What it does |
|---|---|
| `/sc export` | Open the full local run CSV. |
| `/sc participants` | Print current participants. |
| `/sc conflicts` | Print active party conflicts. |
| `/sc gear` | Print equipped gear rule status. |
| `/sc dungeons` | Print dungeon tracking state. |
| `/sc hud` | Toggle the HUD. |
| `/sc minimap` | Toggle the minimap button. |
| `/sc announce off\|chat\|party\|guild` | Configure optional announcements for your own character's deaths. |
| `/sc sound on\|off\|test [event]` | Toggle or test Softcore UI sounds. |
| `/sc camera status\|next\|soft\|cinematic\|dramatic\|off` | Test local camera profiles without changing run rules. |
| `/sc proposal` | Show the current pending proposal. |
| `/sc accept` | Accept the current pending proposal. |
| `/sc decline` | Decline the current pending proposal. |
| `/sc propose-add Player-Realm` | Invite a party member into the current run. |
| `/sc reset confirm end run` | Stop/reset the local active run. |
| `/sc retire` | Retire this character from the active run. |
| `/sc syncdebug` or `/sc sd` | Print sync diagnostics. |
| `/sc debugclear <test>` or `/sc dc <test>` | Clear the in-memory debug trace and test counters before a test pass. |
| `/sc debuglog`, `/sc dl`, `/sc bug`, or `/sc report` | Open the bounded bug-report export. |

Most menu commands also support `chat` output, such as `/sc status chat`, `/sc rules chat`, `/sc log chat`, `/sc export chat`, and `/sc debuglog chat`.

## Exports And Bug Reports

`/sc export` opens a comma-delimited CSV summary for the local run. It includes run status, observed active time, death and violation counts, rules hash, participants, and the stored audit log.

`/sc bug`, `/sc dl`, and `/sc report` open a bounded diagnostic export intended for bug reports. It includes current run/rules/sync state, pending governance, peers, conflicts, sync counters, newest audit rows, newest violations, and the capped debug trace.

For multiplayer testing, run `/sc dc <test name>` on every client before the test, reproduce the issue, then collect `/sc syncdebug` and `/sc bug` from every involved client. Include BugSack or Lua error text separately.

## Persistence And Safety

Active run data is stored per character in `SoftcoreCharDB`. Alts, rerolls, and replacement characters do not inherit another character's active run.

Softcore preserves the current run across `/reload`, logout, and party leave/rejoin. It does not start a new run, reset progress, accept proposals, or apply amendments from status heartbeats alone.

Important boundaries:

- Remote deaths, failures, mismatches, stale messages, resets, and violation clears do not mutate local authoritative state.
- Incomplete chunked sync messages expire without applying partial state.
- Shared audit rows are accepted only as sender-owned rows, and targeted Party Sync join responses must come from the peer/request being joined.
- Proposals and amendments expire after 30 minutes.
- Raid conversion makes Softcore local-only and expires pending group governance.
- Remote violation clears can only clear imported shared violations owned by that peer, not local authoritative violations.

## What Softcore Tracks

- Character, realm, class, level, and zone.
- Run ID, start time, observed active time, start level, rules, status, and party state.
- Deaths, violations, cleared violations, and audit log entries.
- Participants, peer display state, conflicts, proposals, invites, and rule amendments.
- Dungeon repeat state and relevant instance entries.
- Gear quality, heirloom, permanent enchant, consumable, economy, storage, movement, Explorer Mode, and access rule events.
- Local PvP advisory warnings for War Mode and player PvP flagging.
- Per-character max-level completion award snapshots.

## Project Notes

Contributor-facing implementation details live in:

- [`AGENTS.md`](AGENTS.md): product constraints, sync model, persistence rules, safety boundaries, testing expectations, and documentation-update rules.
- [`DESIGN.md`](DESIGN.md): current UI design system and layout guidance.

Anyone changing sync, UI, commands, persistence, proposals, achievements, or release behavior should update the smallest relevant README and AGENTS sections in the same commit.

## Testing

Useful in-game commands:

`/reload`, `/sc commands`, `/sc status`, `/sc rules`, `/sc log`, `/sc violations`, `/sc participants`, `/sc conflicts`, `/sc gear`, `/sc dungeons`, `/sc sync`, `/sc syncdebug`, `/sc bug`

General checks:

- no BugSack errors
- no UI overlap
- inactive/no-run states handled safely
- active runs preserved after `/reload`
- party leave/rejoin settles after heartbeat or resync
- remote events do not reset or invalidate local progress
- proposals and amendments expire instead of applying late

Two-client multiplayer baseline:

1. Computer A: `Cathe-Thrall`, usually party leader/proposer.
2. Computer B: `Hordrien-Thrall`, usually party member/receiver/accepter.
3. Start each pass with `/reload`, then `/sc dc <test name>` on both clients.
4. Use `/sc reset confirm end run` on both clients when a clean inactive state is required.
5. After sync-heavy actions, wait 10-30 seconds for addon-message queue settling.
6. Collect `/sc syncdebug` and `/sc bug` from both clients when diagnosing.

Release-oriented multiplayer passes:

- Fresh grouped run proposal: A proposes, B accepts, A confirms, both share run ID and rules hash.
- Party Sync for matching active runs: align run ID without wiping local history.
- Party Sync for mismatched active rules: review highlighted diffs, accept amendment, settle to one rules hash, and log meaningful rule changes.
- Active-run invite: invite a not-in-run party member without changing existing participant history.
- Disconnect/reload recovery: stale rows recover through heartbeat/resync without local reset.
- Non-addon member: Party Sync blocks inclusion after grace period with clear HUD/Charter state.
- Join/leave during pending governance: no late apply, no silent mutation, and no audit spam.
- Proposal and amendment expiry: late accept/confirm/apply messages are ignored.
- Raid conversion: local-only mode, cleared remote roster display, expired group governance, and preserved local run.
- Remote safety: remote death, reset, failure, mismatch, stale message, or violation clear never mutates local authoritative validity, rules, logs, deaths, or violations.

## CurseForge Publish Checklist

Release readiness:

- [x] Syntax-check all TOC-loaded Lua files.
- [x] Verify the Retail interface number in-game with `/dump select(4, GetBuildInfo())` and update `Softcore.toc` if needed.
- [x] Confirm `## Version` in `Softcore.toc` and `SC.version` in `Core.lua` match.
- [x] Confirm the project license and keep a local `LICENSE` file when possible.
- [x] Prepare CurseForge summary, description, categories, logo, supported Retail version, release type, and changelog.
- [x] Prefer a first public `Beta` file unless the full multiplayer checklist has passed cleanly.

Package contents:

- [ ] Zip a top-level `Softcore` folder containing `Softcore/Softcore.toc`.
- [x] Include TOC-loaded Lua files, `Assets/*.tga`, `README.md`, changelog/release notes, and license.
- [x] Exclude `.git`, `.claude`, `.cursor`, `.vscode`, `AGENTS.md`, `DESIGN.md`, editor files, local test files, and unused empty stubs.
- [ ] Install and smoke-test the exact zip from a clean `Interface/AddOns` folder.

Single-client smoke:

- [x] Login, `/reload`, open menu, switch all tabs, HUD, and minimap button.
- [x] Run `/sc`, `/sc commands`, `/sc status`, `/sc rules`, `/sc log`, `/sc violations`, `/sc gear`, `/sc dungeons`, `/sc sound test list`, `/sc export`, and `/sc bug`.
- [x] Start a solo run, reload, and confirm run state, HUD, minimap button, logs, rules, and active time remain sane.
- [x] Trigger or inspect representative rule checks: gear, mailbox/bank/auction/trade access, mount/flying/flight-path rules, dungeon tracking, and violation clear.
- [x] Verify inactive/no-run states do not nil-error after `/sc reset confirm end run`.

Required multiplayer release passes:

- [ ] Fresh grouped run proposal.
- [ ] Party Sync for separate matching active runs.
- [ ] Party Sync for mismatched active rules.
- [ ] Invite into active run.
- [ ] Disconnect/reload recovery.
- [ ] Non-addon member blocker.
- [ ] Join/leave during pending proposal.
- [ ] Proposal expiry.
- [ ] Rule amendment expiry.
- [ ] Raid conversion.
- [ ] Remote safety.
