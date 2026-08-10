# Equadis' OmniBars

**An all-in-one interface package for World of Warcraft: Vanilla (1.12.x).**

<https://github.com/eqomdx/EquadisOmniBars>

One addon instead of eight. Unit frames, nameplates, aura bars, a damage meter, a
threat meter and a class-aware combat HUD — sharing a single settings panel, a
single media library, a single profile system, and one consistent look.

> **Version 0.2.0 — in development.**
> The combat HUD is implemented and working, including the range readout, the
> ranged swing timer and a druid's secondary mana. The meters, unit frames and
> nameplates on the roadmap below are not written yet. Expect the saved-variables
> format to change between early versions (migrations are provided, but keep a
> backup of your `WTF` folder if you care about your layout).

## Why

The usual vanilla UI is a pile of addons that do not know about each other. Six
different bar textures, six settings panels, six ideas of what "thin border"
means, and six separate places to configure the same font. Each one is fine; the
result is not.

OmniBars is one addon with one media list, one options panel, one profile store,
and modules that can each be switched off if you prefer someone else's.

Nothing here ever refuses to load next to another addon. Conflicts get a line in
chat, not a hard block.

## Status

| Area | State |
|---|---|
| Core framework — config, profiles, media, options generator, module registry | **done** |
| Combat HUD — resource, combo points, swing timers, health | **done** |
| Range readout, ranged swing timer, druid secondary mana | **done** |
| Combat log parser | next |
| Damage meter | planned |
| Threat meter | planned |
| Unit frames | planned |
| Nameplates | planned |
| Aura bars | planned |

The framework is deliberately ahead of the features: modules declare their own
settings, their own class gating and their own panel rows, so each item above is
an addition rather than a rewrite.

## The idea: slots, not bars

Most HUD addons give every bar its own position. That means a warrior's rage bar
and a rogue's energy bar are two unrelated settings, and configuring an alt means
starting over.

OmniBars separates the rectangle from what is drawn in it.

- A **slot** owns geometry and style: position, size, texture, border,
  background, text size. It never knows what it contains.
- A **module** owns behaviour and colour: energy ticks, combo points, swing
  attribution, health.
- An **assignment** maps a slot to a module, per class.

So the resource slot is one rectangle shared by every character on the profile. A
rogue fills it with energy, a warrior with rage, a priest with mana — same place,
same size, different colour. A hunter puts the range readout in the slot a rogue
uses for combo points, because that is simply a different assignment.

A druid never even changes assignment: the resource slot always holds the one
power module, and shifting form only swaps which colour and ticker it uses. The
bar does not move.

### Slots

| Slot | Default occupant |
|---|---|
| `points` | Combo points (rogue, druid) · range readout (hunter) |
| `swingB` | Off hand swing |
| `swingA` | Main hand swing |
| `resource` | Energy / rage / mana / focus, whichever the class uses |
| `health` | Health |
| `aux` | Range readout, or a druid's secondary mana. Hidden by default |

An empty slot draws nothing and leaves a gap rather than closing it up — closing
up would move the other bars, and then two characters with different occupancy
would no longer line up. **Restack Occupied Slots** does it on demand instead.

## Modules today

**Resource** — every power type from one bar. Energy and focus anchor their
ticker to the observed regeneration pulse and hold the phase when capped, so the
spark is in the right place the moment you spend. Mana has no pulse to observe,
so it infers the cycle from the last change: spending opens a five second rule
window, optionally shaded on the bar as a shrinking region. Rage does not tick,
but it leaks — an optional marker shows where it will have decayed to a few
seconds from now, at a rate measured from your own server rather than assumed.

**Combo Points** — five segments, one colour each, inactive points dimmed to a
configurable opacity.

**Swing Timers** — main hand, off hand and ranged, with remaining time and weapon
speed. Fill or deplete, flip, swap the text sides, 0–2 decimals. Because vanilla's
combat log does not say which hand swung, a landed swing is attributed to
whichever hand has been ready *longest* — which is what lets the pair recover on
its own after a stun or a run out of range.

**Health** — green by default, any colour, optionally your class colour, with an
optional recolour below a threshold.

**Range** — how far away your target is, drawn by whichever of three backends
your client can actually support. With SuperWoW's `UnitXP` it is a real distance:
a continuous bar with the dead zone marked and the yardage on it. Without one it
falls back to four bands from `CheckInteractDistance`, exactly one lit — a
position readout rather than a fill, which is what keeps it legible at 8 pixels
tall. In between, it can watch one action bar slot and use the game's own range
check for that ability, which for a hunter's Auto Shot beats every heuristic.
Press **Capture Next Action** and then the button you want it to follow.

**Druid Mana** — how much mana you still have in bear or cat form. Vanilla stops
reporting it the moment you shift, so it is simulated from the shift onwards:
spirit regeneration, mana-per-5 from your gear, the shapeshift cost, Innervate
and the five second rule. If you log in already shifted there is no baseline to
work from, so the bar stays hidden rather than showing a confident wrong number.

Every module can be switched off independently on the **Modules** page.

## Profiles

One account-wide store. Every character starts on `Default`, which is why they
all line up: move a slot on one and it moves for all of them. Create as many
named profiles as you like and bind characters to them individually.

An existing `RogueBarsConfig` is imported into `Default` the first time OmniBars
loads, once. RogueBars' own saved variables are never modified.

## Commands

```
/eqob                          open the panel            (also /ob, /omnibars)
/eqob help                     every option, every scope
/eqob scale 120                a general option
/eqob slot resource h 20       a slot's geometry
/eqob power ticker nofull      a module's setting
/eqob assign points range      put a module in a slot
/eqob profile use Raiding      use|new|copy|delete
/eqob restack                  re-stack the occupied slots
/eqob test                     preview every bar without a target
/eqob selftest                 check the addon against your client
/eqob reset                    this profile   ( reset all for every profile )
```

`/eqob selftest` is the one to run first if something looks wrong. It verifies
that every API each module needs exists on your client, that the bars were built
with a size and a position, that the values they draw from are sane, which range
backend you ended up on, and that the settings panel built completely — then
reports pass or fail per section. It changes nothing.

The panel and the prompt are generated from the same table, so anything you can
click you can type, and neither can drift out of step with the other.

## Moving things

Drag any bar. Right-click one for a nudge overlay with 1px arrows. Or type exact
coordinates on the Slots page.

**Move Bars Together** (on by default) drags the whole cluster and keeps the
spacing. Turn it off to place bars individually; **Allow Bar Overlap** governs
whether they may then stack, and border art counts as part of a bar.

## Installation

1. Download the latest version
2. Unpack the zip
3. Rename the folder to **`EquadisOmniBars`** — the name must match exactly, or
   the bundled textures and fonts will not load
4. Copy it into `Wow-Directory\Interface\AddOns`
5. Restart WoW

## Compatibility

Vanilla 1.12 client APIs only, Lua 5.0, no libraries, no dependencies, no
localisation requirements.

SuperWoW is optional. If its `UnitXP` is present the range readout uses it and
becomes a real distance; if not, everything still works and the readout falls
back to bands. Nothing in the addon requires a client mod.

If RogueBars is enabled at the same time you will see two sets of bars, because
OmniBars supersedes it. It says so once in chat rather than refusing to load.

## Development

`tests/` holds a stub of the 1.12 client and a suite that boots the real addon
against it — nine classes, event dispatch, rendering maths, ticker phase, swing
attribution, range backend selection, collision, profiles, migrations, the
options panel and every slash command. The TOC does not list `tests/`, so the
game never loads it.

```
luajit tests/run.lua
```

That half proves the addon is internally consistent. It cannot prove the client
agrees — a stub that shares a wrong assumption passes happily, which is exactly
how a settings panel that could not open once shipped past a green suite.
`/eqob selftest` is the other half, and asks the questions only the real client
can answer.

Any Lua 5.1-compatible interpreter works; LuaJIT is the closest easily available
match to the client's 5.0. For a syntax-only check, `luac -p *.lua`.

## Credits

Built on the architecture of Equadis' Rogue Bars, which it supersedes, and drawing
on patterns from ShaguDPS (namespace, dirty-flag dispatch, combat log parsing),
Equadis' Threat Meter (config loader, declarative options, widget factory) and
Equadis' UnitFrames (the mana tick heuristic).

The druid secondary mana estimate is ported from DruidManaLib-1.0 by Aviana,
rewritten standalone so it no longer needs Ace2.

MIT licensed.
