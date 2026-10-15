# ewe.companion — map for agents

The entry point for any agent working on the island: the shell plugin
`ewe.companion`, the QML half of the ewe companion. The daemon, the CLI,
the knowledge pack and every test live in the sibling repo
[`ewe-companion`](../ewe-companion); its
[`AGENTS.md`](../ewe-companion/AGENTS.md) is the main map (the rules, how
the pieces talk, where each change goes) and comes first. This file covers
what is particular to the QML.

- Recipes that touch both halves: `../ewe-companion/docs/EXTENDING.md`.
- Seeing your change: `../ewe-companion/docs/TESTING.md`, the island
  harness `../ewe-companion/tests/island.sh`.
- The plugin API (manifest, kinds, `Shell`, the public components, `Theme`,
  `Globals`): `../ewe/docs/PLUGINS.md`.

## What this is

A notch of the bar's own material hanging from the top bar's centre. It is
out while something runs (an agent at work or waiting, a card, a line to
say, a question in flight, game mode) and gone otherwise; Super+A or a click
opens the home panel. Version **0.2.0**, Plugin API 3, not bundled with ewe
yet (P7). User-facing description and honest limits: `README.md`. 0.3.0
(2026-10-15, P2.9) adds rows under answers and the `browser` and
`safe_unlock` do actions.

## Files

```
manifest.json          id ewe.companion · apiVersion 3 · kinds service + overlay · Super+A → toggle ·
                       requires the ewe-companion package · settings (provider, model, base_url,
                       screen, show_usage, peek_seconds)
qmldir                 the plugin-local singleton CompanionState
CompanionState.qml     the one truth the service and the notch share: connected, presence, pending
                       cards, sessions, glance, usage, chat status, game mode, the peek, dropOpen,
                       messages (the last 40), thinking; send() and the helpers that build each
                       outbound message (answer, jump, run, undo, setKey, runProposal, ask)
Service.qml            (service) the daemon's socket: reconnect with backoff, start the daemon when
                       nobody answers; onLine() mirrors daemon messages into CompanionState; env (with
                       wayland) and settings out; perform() runs `do` actions (dnd, open, launch, term,
                       screenshot, browse, browser, safe_unlock); findApp()/startApp() for launching;
                       the browser's command line (bcli: one process, 25 s at most); the blur rule;
                       IPC ewe.companion
Drop.qml               (overlay) one Top-layer window per screen: sizing, the reveal, the input mask,
                       the focus grab, the Shape (ground + rule with fillets), the notch with its
                       head (Indicator), the scrolling body (cards, sections, messages) and the
                       pinned dock (Chat)
Indicator.qml          the notch's one line: state dot + word, count, activity or peek, usage bars
cards/PermissionCard.qml   Allow · Deny · Always for … · Answer in terminal, with the command/diff preview
cards/QuestionCard.qml     AskUserQuestion: single, multi, several questions; Send; Answer in terminal
cards/NoteCard.qml         something to read, two actions and Later (P3's notifications; debug today)
sections/Agents.qml        live sessions, their last steps, files changed; a click jumps to the terminal
sections/Glance.qml        a disk past 85 %, waiting updates, a low battery; nothing otherwise
sections/NowPlaying.qml    the track that plays, with controls (the Music plugin's player pick)
sections/Actions.qml       quick actions: Do not disturb, game mode, screenshot, Settings, Komble, lock
sections/Messages.qml      the conversation: answers, Undo, Open buttons, proposed commands (Run /
                           In terminal), their output, and rows (a ListWell of ListRows: a click
                           does the first action, small icon buttons the others; `copy` actions
                           stay in the island: wl-copy)
sections/Chat.qml          the line you type in, the provider hint, the API key field
sections/SectionLabel.qml  the overline above a section
README.md              what it does, settings, honest limits
```

## How state flows

```
daemon ──line──▶ Service.onLine ──▶ CompanionState (properties) ──▶ Drop.qml, Indicator, cards, sections
daemon ◀──line── Service.write ◀── CompanionState.outbound(msg) ◀── st.send(…) ◀── a click
```

- **Nothing draws from the socket directly.** The service writes
  `CompanionState`; everything else binds to it. A new daemon message gets a
  `case` in `Service.onLine` and a property in `CompanionState`.
- **Every click goes out through a `CompanionState` helper** (`answer`,
  `run`, `undo`, `runProposal` …), which calls `send()`. The service writes
  it to the socket.
- **`state` is a full snapshot** after every change, so the island never
  patches lists by hand except for `card.close` (removed at once, to feel
  instant).
- **The daemon outlives the shell.** On reconnect the island gets `welcome`
  and a fresh `state`, and re-sends `env` and `settings`. Never keep
  anything here that only the daemon can make true again.

## The rules for this QML

The house rules hold (`../ewe-companion/AGENTS.md`); these bite most here:

- **Tokens only (rule 8).** Colours, sizes, radii, spacing, durations and
  easing come from `Theme` (`Theme.spaceMd`, `Theme.r(Theme.radiusRounded)`,
  `Theme.grow(Theme.panelSm)`, `Theme.durBase`, `Theme.ease`, `Theme.ic*`
  icons). A geometric constant (a pill's `radius: width / 2`) is fine with a
  comment saying so. Text goes through the shell's text components
  (`TextCaption`, `TextBody`); controls through `QsButton`,
  `QsIconButton`, `QsField`, `QsFieldInput`.
- **Public API only.** `Shell`, `Globals`, `Theme`, `Log` and the public
  components (ewe's `docs/PLUGINS.md`). Reaching into the shell's internals
  breaks when the shell moves; the API is versioned (`apiVersion`).
- **It decides nothing (C1).** No default action, no timeout that answers,
  no keyboard shortcut that allows. A card's only answers are clicks.
- **Fail back (C2).** Each card's Loader sends the ack (`card.shown`) when
  the card loads. If it cannot load, the daemon gets no ack in 800 ms and
  the agent asks in its terminal: do not "fix" that by acking early.
- **No focus steal (C6).** A card that drops by itself takes no keyboard.
  The keyboard is Exclusive only while the home panel is open by hand.
- **One size.** The compact notch is one width whatever it says; nothing
  changes size on hover. Text elides inside the space it has.
- **Idle costs nothing.** No running timers or animations while nothing
  changes; a timer starts on an event and stops.
- **No secrets in settings (rule 2).** API keys are typed into the chat's key
  field and go to the keyring through the daemon; `manifest.json` settings
  sync with `ewe.conf`.
- **The reserved id.** `ewe.` ids load only from a payload (ewe's
  `plugins/` + `bundle.json`), never as a hand-made plugin; the harness and
  the owner's symlink both go through that.

## The window, and why it is built this way

`Drop.qml`'s header explains each choice; in short:

- **It never resizes while anything shows.** Hyprland stretches a layer
  surface's old buffer to its new size until the next frame: that was the
  blink on opening. So the window takes its full size (`fullH`) while still
  empty (`sized`), the notch comes out only once it has (`out`, or
  `revealTimer` if the compositor never gives the full height), and it
  shrinks to 1 px only after the notch has gone in (`shrinkTimer`).
- **The input mask is the notch alone** (`hit`), so the tall transparent
  window never eats clicks meant for what is under it.
- **Click outside closes it** through `HyprlandFocusGrab`, started a beat
  (`grabTimer`) after the keyboard turns Exclusive: Hyprland ends every grab
  when an exclusive layer takes the keyboard.
- **The material is one `Shape`** with the curve renderer: the ground and the
  bar's rule as `ShapePath`s, fillets into the bar included, so the joint is
  smooth at any scale. The fill starts one rule-width above the bar's edge
  to hide the hairline. The shell's `InvertedCorner` paints nothing (its arc
  runs the long way round): do not reach for it.
- **Blur** comes from a runtime layer rule for `quickshell:companion`
  (`Service.applyBlur`), re-added after every `configreloaded`, only when
  Glass blur is on.
- **The open notch stops at 60 % of the screen** (`maxOpenH`). The cards,
  sections and messages scroll in `scroller`; the chat line is pinned in
  `dock`. New messages scroll into view (`followEnd`, `scrollToEnd`); a new
  card or opening by hand goes to the top.
- **Only the main notch holds cards** (`win.main`, the screen
  `CompanionState.screenName` names), so each card is acked once.

## Adding things

- **A home section:** `sections/<Name>.qml`, then one line in `Drop.qml`'s
  body `Column` with `width: body.width` and a `visible:` that is true only
  when there is something live to show.
- **A quick action:** an entry in `sections/Actions.qml` `buttons` (`ic`,
  `label`, `on`, `cmd`, `args`). It runs a catalog command through the
  daemon, so the command must exist there first (EXTENDING.md recipe 1).
- **A card kind:** `cards/<Kind>Card.qml` with `property var card`, a
  `Component` for it in `Drop.qml`, and its branch in the card Loader's
  `sourceComponent`. Answers through `CompanionState.answer(id, action,
  answers)`.
- **A `do` action:** a `case` in `Service.perform()`, always ending in
  `root.done(id, ok, error, data)` (the daemon waits 3 s otherwise). Close the
  notch first when the action puts something on screen. Plus the daemon side
  and PROTOCOL (EXTENDING.md recipe 2).
- **A daemon message:** a `case` in `Service.onLine` writing a
  `CompanionState` property (EXTENDING.md recipe 10).
- **An IPC function:** in `Service.qml`'s `IpcHandler` (target
  `ewe.companion`). IPC verbs are public API: add, never rename. Update the
  README's IPC line.
- **A setting:** `manifest.json` `settings`, read from `root.settings` /
  `drop.settings`; the README's settings table. If the daemon needs it,
  `sendSettings()` and the protocol's `settings` message.

## Traps already hit

- **A row's hover hint would move its buttons.** ListRow's `kind` caption
  sits right of the trailing buttons, so changing it on hover shifts them
  under the pointer. Rows keep `kind` fixed (the first action's label); the
  icon buttons carry only `Accessible.name`.
- **`do browser` runs only `ewe-browser`, `do safe_unlock` only
  `ewe-safe`** (checked by the binary's name): the daemon names the binary
  (tests point it at fakes), the island runs nothing else.

- **A Qt `Column` (and `Row`) skips zero-width children.** An empty
  `TextCaption` has width 0, so its slot collapsed and appeared only when a
  hover gave it text: the notch grew on hover. Give such items an explicit
  width (`width: parent.width`).
- **Hover order:** entering the new item comes before leaving the old one.
  A shared "hovered" value cleared on exit wipes what the new item just set;
  clear only your own value.
- **A plugin property may not be called `right`** (`Item.right` is FINAL;
  the overlay failed to load), and `state` shadows `Item.state`.
- **Layer windows blink when they grow** (above): never bind a window's
  height to its content.
- **Focus grabs die when an exclusive layer takes the keyboard** (above).
- **Settings 0.18 ignores `--page`**: `Shell.openSettings(page)` opens
  Appearance; the daemon's reply names the page to pick.
- **The headless harness has no pointer.** Hover and click bugs never show
  without the virtual mouse (`tests/island.sh hover`).
- **Bugs that only show at the owner's 1.8 scale** (pixelated curves, off
  by one rows): test with `tests/island.sh up --scale 1.8`.

## Checking a change

```sh
cd ../ewe-companion
tests/island.sh up --scale 1.8        # builds the daemon, copies this plugin into a scratch payload
tests/island.sh ipc open              # the home panel
tests/island.sh shot home             # read the PNG
# edit QML here, then:
tests/island.sh sync                  # copy again, restart the nested shell
tests/island.sh down
```

Light mode (`--light`), Glass (`--glass`), cards (`ctl debug card
permission|question|note`), typing (`type --enter "…"`) and hover (`hover
STEPS`) are in `../ewe-companion/docs/TESTING.md`. Check both schemes when
colours are involved. Agents: prefix every call with
`ISLAND_WORK=<scratchpad>/island` (shell variables do not survive between
tool calls).

The harness's daemon acts on the real machine: never click the Lock quick
action there (it locks the owner's screen), and never test volume,
brightness, media or game mode from the notch.

On the owner's desktop the plugin is a symlink
(`~/.local/share/ewe/plugins/ewe.companion` → this repo), so a change is live
after `systemctl --user restart ewe.service`. That restarts their whole
shell: only when they asked to try it, and say so first.

## Keeping things true

In the same change: the README (what the user sees, settings, IPC, honest
limits), `manifest.json`'s `version` (semver; a new release of the plugin
bumps it), and on the companion side PROTOCOL.md, PLAN §20/§25 and the
vault (see the table at the end of `../ewe-companion/AGENTS.md`). There is
no CI here: the harness and your eyes on the screenshots are the check.

## Git

Commit or push only when the owner asks; branch off `main` first. A
feature that also changes the daemon merges in the same wave as
`ewe-companion` (one PR each, merge commits).
