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

- `Overview`: local run status, party status, participant snapshot, run ID, elapsed time, deaths, and active violation count (no Overview resync control; use `/sc resync` or Run tab Party Sync)
- `Run`: start a run, review locked active rules, stop/reset a run, use Party Sync for resync/invite/run-alignment routing, and modify rules
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
- party: `PARTY`

Raid groups are intentionally unsupported because the UI is designed for party-scale accountability, not raid-scale rosters. When a party converts to raid, Softcore should become local-only: stop party sync, avoid raid roster display, and expire pending group proposals/amendments rather than applying them late.

Status heartbeats are sent periodically. Full rules/proposals may be chunked. Incomplete chunk buffers expire and should never mutate run state.

WoW addon-message API constraints are gospel for this project:

- Register the `SOFTCORE` prefix on every login/reload before expecting `CHAT_MSG_ADDON` delivery. Prefix registration does not persist through `/reload`.
- Prefixes are limited to 16 bytes. Message bodies are limited to 255 bytes and cannot contain null bytes.
- `C_ChatInfo.SendAddonMessage` returning success only means the client accepted the message for enqueueing; it does not guarantee immediate delivery.
- Addon messages are throttled per prefix. Treat the practical default as 10 message allowance and about 1 message recovered per second, but assume Blizzard can change those numbers server-side.
- Large payloads must be chunked and sent through the Softcore send queue. Do not burst-send all chunks or repeated proposals directly.
- Repeated proposal/control sends must be paced. A missing chunk must leave receiver state unchanged.
- Preserve boolean values during serialization. Do not use `value or ""` when stringifying payload fields because `false` is meaningful for rules.
- Use `PARTY` and `INSTANCE_CHAT` only. Do not use raid sync as a fallback; raids are local-only for Softcore.

### Sync implementation map (current architecture)

There is no separate HTTP or server “backend.” All multiplayer behavior is **two or more WoW clients** exchanging **addon channel messages** (`SOFTCORE` prefix on `PARTY` or `INSTANCE_CHAT`). Authoritative run state still lives in **per-character SavedVariables** (`SoftcoreCharDB` / `SoftcoreDB` in code). Sync code should be read as **transport + peer display + proposal transport**, not as a remote source of truth for local validity.

**Where to look in code**

- `Sync.lua`: prefix registration, inbound `CHAT_MSG_ADDON`, **chunk reassembly** (per-sender buffers that **expire** without applying partial state), **outbound send queue** (token-budget pacing, priority insertion, send failure retries), **stale send drops** for obsolete queued items, and serialization/chunking to the 255-byte body limit.
- `Core.lua`: slash commands; **`/sc dc`** (`ClearDebugTrace`) clears the capped in-memory **debug trace** and resets **test-oriented `db.sync` counters** (stale send drops, last stale drop metadata, send failure count/last error, expired chunk buffer count/last expiry). **`/sc dl`** builds the CSV-style export that includes those fields.
- `Events.lua`: game events that drive periodic **STATUS** heartbeats and other local hooks.
- `ProposalUI.lua` / `MasterUI.lua`: Run-tab proposal UX; user actions enqueue outbound payloads through `Sync` rather than calling `SendAddonMessage` directly.

**Outbound path**

Structured payloads are queued (with a **priority** ordering so control/violation traffic can preempt bulky traffic), split into chunks when needed, then sent via `C_ChatInfo.SendAddonMessage` (or legacy equivalent). Pacing and resend **attempt limits** live as constants near the top of `Sync.lua` (for example proposal resend spacing vs control-message retry behavior). Treat Blizzard throttling as real: never bypass the queue for large or repeated sends.

**Inbound path**

Each received segment is either a standalone message or part of a **chunk sequence**. Reassembly uses a buffer key (sender + chunk id); **incomplete buffers expire** and must not mutate run state. Fully reassembled payloads dispatch to type-specific handlers (proposals, status, party log import, amendments, etc.).

**Stale send drops (`SYNC_DROP_STALE_SEND`)**

When the queue is about to send an item, `Sync.lua` may drop it if it is no longer meaningful. For example, a queued **`PROPOSAL`** is stale once that proposal is no longer `PENDING`. A queued **`PROPOSAL_ACCEPT`** is stale only if the proposal reached a **terminal** state such as **`CANCELLED`**, **`DECLINED`**, or **`EXPIRED`** (not merely because the acceptor has already moved to **`CONFIRMED`** locally). Drops increment **`db.sync.staleSendDrops`** and optional trace rows; **`/sc dc`** resets those counters for clean test exports.

**Documentation vs code**

Keep this section as a **map** (transport, modules, invariants). For exact thresholds, message-type lists, and handler behavior, **trust the code** and search `Sync.lua` first; update this subsection when the model changes, not every tweak.

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
- Separate active runs can align only through explicit Party Sync routing to a run sync proposal.
- Active players can invite party members through Party Sync routing to a party invite proposal.
- Ruleset mismatches can route through Party Sync to a rule amendment proposal using the local player's differing rule values.
- Party Sync may also route stale/unsynced display state to a full-state resync without mutating local run state.
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

Current multiplayer test setup:

- Computer A: this/main computer, VSCode/Codex computer, character `Cathe-Thrall`, usually party leader/proposer.
- Computer B: second computer, character `Hordrien-Thrall`, usually party member/receiver/accepter.
- Unless the user says otherwise, assume multiplayer tests involve a normal party with A proposing and B accepting. Do not assume raid behavior is being tested unless explicitly stated.

After any feature, bug fix, or sync/UI behavior change, give the user exact A/B test instructions. Include:

- what to run on A and B before the test, usually `/reload`, `/sc dc <test name>`, and sometimes `/sc reset` if a fresh run is needed
- what action to perform on A
- what action to perform on B
- expected UI/HUD/menu state on both computers
- expected lifecycle events or audit/debug entries on both computers
- when to wait for sync settling, usually 10-30 seconds because addon messages are queued/throttled
- what commands to run after the test, especially `/sc syncdebug` and `/sc debuglog`
- what exports or lines the user should paste back into chat for diagnosis

Prefer test scripts that cover lifecycle and whole-app state, not just the specific button changed. For proposal/sync changes, always verify run ID, ruleset hash, pending proposal state, participant rows, party status, HUD lamp, active violations, conflicts, and absence of unexpected audit spam.

Useful commands:

- `/reload`
- `/sc status`
- `/sc rules`
- `/sc log`
- `/sc violations`
- `/sc participants`
- `/sc conflicts`
- `/sc debuglog`
- `/sc dl`
- `/sc debugclear`
- `/sc dc`
- `/sc syncdebug`
- `/sc sd`
- `/sc gear`
- `/sc dungeons`
- `/sc resync`

`/sc dc` clears the in-memory debug trace and resets test-oriented sync counters such as stale send drops, send failures, and expired chunk buffers. Use it at the start of every A/B test so pasted exports describe only that test pass.

Check for:

- no BugSack errors
- no UI overlap
- no nil errors when no run exists
- active run persistence after `/reload`
- party leave/rejoin settling after heartbeat or resync
- local character state not affected by remote deaths, resets, mismatches, or stale messages
- proposals/amendments expiring instead of applying late
- commands handling inactive states safely

## Rolling documentation updates

There is no separate doc bot or CI job. **Rolling updates are a required part of feature work:** keep `AGENTS.md` and `README.md` aligned with reality in the **same commit** as the code (or split only if the user explicitly wants a doc-only follow-up).

When you change behavior or structure, patch the **smallest relevant sections**—do not duplicate long explanations that belong in code.

| If you change… | Update (at minimum) |
|----------------|---------------------|
| `Sync.lua` or addon messaging (queue, chunking, throttling, message types, stale drops, counters, channel choice) | **Sync Model** and **Sync implementation map**; if user-facing, **README** party sync bullets |
| Proposals, amendments, invites, expiry, Run-tab flows | **Proposal And Amendment Boundaries**; **Current Product Shape**; **README** starting runs / Run tab |
| New or removed menu tab, HUD behavior, minimap | **Current Product Shape**; **README** UI sections |
| New or removed slash commands or debug export fields | **README** command table; **Testing Expectations** useful commands |
| SavedVariables layout, per-character scope, migration | **Persistence Model** |
| Individual-first boundaries, what remote sync may/may not do | **Core Safety Principle** and **Incoming sync** lists |

Skip doc edits only for **pure refactors** with no observable behavior and no architecture clarification. When in doubt, add one or two sentences to **Sync implementation map** or the relevant list rather than leaving the next chat guessing.

## Commit Discipline

After each working feature or bug fix, summarize changed files and commit.

If the work changed architecture, sync, persistence, UI surfaces, or player-visible commands, **include the documentation updates above in the same commit**.

Use concise commit messages such as:

- `Fix proposal flow`
- `Harden sync edge cases`
- `Improve party run UI`
- `Fix gear validation`
