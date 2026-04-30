# Softcore UI Design Guide

This guide captures the design principles used for the Overview and Charter tab refactors. Use it when changing `MasterUI.lua`, adding new menu surfaces, or deciding whether a new UI element belongs in the main menu.

## Product Posture

Softcore is a compact WoW addon UI, not a web dashboard. The menu should feel native, readable, and calm while still having enough polish to make the run feel alive.

Prefer:

- small, useful panels over decorative content
- clear information hierarchy over explanatory copy
- modular helpers and layout constants over hand-tuned coordinates
- consistent spacing, widths, and row heights
- native-WoW styled borders, muted parchment/dark backgrounds, and restrained color accents

Avoid:

- bloat text that restates obvious labels
- debug/internal details in the primary view
- adding controls to Overview when Charter owns the action flow
- more stat boxes just because empty space exists
- separate proposal popups
- one-off coordinates that make future additions drift out of alignment

## Layout Principles

Use layout tables for repeatable sections. `RUN_LAYOUT` and `OVERVIEW_LAYOUT` are the model:

- define content width, gaps, row heights, section heights, and insets in one place
- derive column widths and right-column offsets from content width and gap
- center major content with computed offsets such as `CenteredOffset(PANEL_WIDTH, contentWidth)`
- compute repeated element widths from count and gap rather than hard-coding each box
- give parent frames and row containers explicit dimensions so child anchors are stable

When adding a section:

- choose a fixed content width for the tab surface
- compute x/y positions from previous section height plus a named gap
- keep repeated rows on a stable row height
- make hidden/empty states preserve intentional structure unless the section should truly collapse
- update helper functions rather than patching each caller independently

## Component Patterns

### Cards And Badges

Use compact framed elements for individual values, row badges, and repeated items. Keep them simple:

- title + hero value for stat cards
- no secondary detail line unless it changes player decisions
- one color meaning per component when possible
- color the value and border together for quick scanning

Small badges should be created through a helper, then refreshed through a tone setter. This keeps class, status, count, and future badges aligned.

### Rows

Rows should read left to right by concept:

1. identity
2. flavor/context
3. state/validation
4. count or small numeric summary

Keep logically separate ideas visually separated. For example, class is flavor/context, while status and total violations are validation, so class should not sit between two validation cells.

### Text

Use text only when it pays rent:

- labels for compact information groups
- short names for events, statuses, and actions
- one-line empty states
- row values that are not obvious from layout alone

Do not add prose explanations to primary surfaces. If a workflow needs explanation, prefer state, highlight, disabled buttons, or HUD wording.

## Overview Tab

Overview is for quick state comprehension. It should answer:

- What run am I in?
- Am I valid?
- How long has this run been observed?
- Are there deaths, violations, conflicts, or party issues?
- What just happened?
- Who is in the run/party snapshot?

Current Overview structure:

1. Hero header with preset/custom run label, run ID, player/party status pills, and level/start level.
2. Four stat cards: Deaths, Violations, Time, Integrity.
3. Recent Activity panel with the latest meaningful filtered log events.
4. Party Ledger with up to five members.

Overview section panels such as Recent Activity and Party Ledger should share one header language: same title font, inset, divider placement, and muted framed backdrop. The body layout can differ by content density.

### Overview Stat Cards

Keep these minimal:

- title
- large value
- color tone

Avoid reintroducing detail text such as rules hash, "none active," or started time inside the cards. Those made the cards noisy and uneven.

### Recent Activity

Recent Activity is a lightweight context strip, not a second Log tab.

Rules:

- show only a small number of meaningful events
- reuse the Log tab filtering so low-value rows stay hidden
- preserve item links with `SetCompactText` rather than raw truncation
- show time, event kind, character when space allows, and a compact message
- use a condensed version of the Log tab row language: subtle alternating rows, a left color accent, compact columns, and hover tooltips for full text
- do not add actions here

## Violations And Log Tabs

Violations and Log are dense audit surfaces, so they should share the same scalable list language:

- use a fixed pool of virtualized rows rather than creating one frame per stored entry
- keep a short summary line above the list and low-priority count/export context in the footer
- show newest-first rows with a colored left accent, compact primary metadata, and a second-line detail/message
- preserve full row text in hover tooltips when the visible row is compacted
- cap the Log tab's in-menu display to the newest 1000 displayable entries for responsiveness while keeping CSV/debug exports complete
- keep the Log tab export button always available in the footer; do not add an export action to Violations

### Party Ledger

The ledger is a five-member surface because normal party scale is the product boundary.

Always include the local character when an active run exists, even while solo.

Each row should include:

- character name
- current level and start level when known
- class-colored badge when class data is available
- status pill
- total violation count

The left accent bar follows run/member status. If the member is valid/active but has violations, split the bar between status green and warning yellow to communicate both facts without overriding the row state.

Avoid:

- mode text like "Solo" or "Party" in the header
- run ID/rules hash in each row
- extra debug/sync timestamps
- status and violation cells separated by unrelated flavor cells

## Charter Tab

Charter is the setup, rules, governance, proposal, sync, and amendment surface. It replaced the visible "Run" label because the tab is the run agreement, not merely run status.

Charter should:

- keep rule controls in native-WoW styled rule groups
- use a consistent two-column grid
- keep presets compact and uniform
- show proposal/amendment review in the normal rule layout
- use footer controls for accept/decline/cancel/apply actions
- avoid top detail banners for proposal state

### Rule Sections

Use `CreateRunSection`, `RUN_LAYOUT:SectionHeight`, `RUN_LAYOUT:CreateRow`, and the placement helpers. Do not hand-place controls when an existing row helper can do it.

Sections should have:

- a short title
- divider
- fixed content rows
- stable controls that can be shown/hidden without changing unrelated layout

### Presets

Preset buttons should be uniform in width and height. If a preset label does not fit, choose a short label rather than giving that one button a custom size.

Current preset intent:

- Casual: low-restriction grouped baseline
- Chef's Special: creator-preferred profile
- Ironman: common WoW Challenges shape
- Iron Vigil: stricter Ironman with no flight paths and cinematic camera enforced

Preset rules must stay aligned with:

- canonical/default rules
- editable diff order
- sync/hash order
- achievement eligibility
- documentation

### Governance Flows

Proposal and amendment flows belong in Charter:

- group run proposals
- run sync proposals
- party invite proposals
- rule amendment review
- detail loading/retry/decline/cancel states

Do not create separate proposal popups. Do not put governance controls in Overview.

## Color And Status

Colors should communicate state, not decorate randomly.

Use:

- green for valid/active/clean
- yellow/gold for warning, violations, conflicts, and review needs
- red for failed/fatal local state
- blue for time/sync-ish context
- class colors only for class identity badges
- muted tan/brown for background, separators, and low-priority text

When two facts matter, prefer a compact combined signal over replacing one fact with another. Example: valid member with violations uses a split green/yellow accent bar.

## Adding New UI Elements

Before adding an element, ask:

1. Does it help the player make sense of current run state faster?
2. Is this information already clearer in Charter, Violations, Log, Achievements, HUD, or slash output?
3. Can it be expressed in one row, one badge, or one compact panel?
4. Will it still look good with no run, solo run, five party members, pending governance, and raid-local mode?
5. Can it be built from existing helpers or a reusable new helper?

If the answer is weak, leave the space empty. Empty space is better than a busy addon.

## Implementation Checklist

For UI changes:

- inspect existing helpers first
- use named layout constants
- use computed placement for repeated components
- keep parent frames explicitly sized
- update refresh code and empty states together
- run `luac -p` across addon Lua files
- test in WoW with `/reload`
- verify no BugSack errors
- verify active run persistence after `/reload`
- update `README.md`, `AGENTS.md`, and this guide when the visible structure or design model changes

For multiplayer-facing UI:

- include A/B test instructions
- verify local state is not mutated by remote display state
- check proposal/amendment settling states
- wait 10-30 seconds for addon-message throttling
- inspect `/sc syncdebug` and `/sc debuglog` if display state is stale
