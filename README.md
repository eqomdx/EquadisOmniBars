# Equadis' OmniBars

**An all-in-one interface package for World of Warcraft: Vanilla (1.12.x).**

<https://github.com/eqomdx/EquadisOmniBars>

One addon instead of eight. Unit frames, nameplates, aura bars, a damage meter, a
threat meter and a class-aware combat HUD — sharing a single settings panel, a
single media library, a single profile system, and one consistent look.

> **Version 0.5.7 — in development.**
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
| Distance readout, ranged swing timer, druid secondary mana | **done** |
| Combat log parser | next |
| Damage meter | planned |
| Threat meter | planned |
| Unit frames | planned |
| Nameplates | planned |
| Aura bars | planned |

The framework is deliberately ahead of the features: modules declare their own
settings, their own class gating and their own panel rows, so each item above is
an addition rather than a rewrite.

## The idea: one layout, every character

Most HUD addons give every bar its own position. That means a warrior's rage bar
and a rogue's energy bar are two unrelated settings, and configuring an alt means
starting over.

In OmniBars the **rectangle** and **what is drawn in it** are separate things.
Position, size, texture, border and background belong to the bar and are shared
by every character on the profile. Color and behavior belong to the module,
because those are the things that *should* differ — energy yellow, rage red,
health green.

So the resource bar is one rectangle. A rogue fills it with energy, a warrior with
rage, a priest with mana: same place, same size, different color. A druid
shifting form does not move it either — only the color and the ticker change.

### The bars

Listed in the settings panel in this order, and stacked on screen the same way.
Drag them into whatever order you actually want.

| Bar | Shows |
|---|---|
| Health | Your health |
| Resource | Energy / rage / mana / focus, whichever the class uses |
| Main Hand | Main hand swing timer |
| Off Hand | Off hand swing timer |
| Ranged | Auto shot timer |
| Ranged Distance Check | Can you hit your target from here |
| Secondary Resource | A druid's mana while shifted |
| Extras | Class specific — combo points for a rogue or druid |

Each bar has a **Show Bar** switch, on by default. Bars your class cannot use are
not listed at all: a warrior has no Extras and no Secondary Resource. And a bar
with nothing to say hides itself whatever that switch says — no off hand
equipped, nothing ranged equipped — so an empty off hand leaves no gap in the
art, just space.

That space is not closed up automatically, because bar positions are shared and
closing a gap for one character would move another's. **Restack Occupied Bars**
on the Bars page does it on demand.

## Modules today

**Resource** — every power type from one bar. Energy and focus anchor their
ticker to the observed regeneration pulse and hold the phase when capped, so the
spark is in the right place the moment you spend. Mana has no pulse to observe,
so it infers the cycle from the last change: spending opens a five second rule
window, optionally shaded on the bar as a shrinking region. Rage does not tick,
but it leaks — an optional marker shows where it will have decayed to a few
seconds from now, at a rate measured from your own server rather than assumed.

**Combo Points** — five segments, one color each, inactive points dimmed to a
configurable opacity.

**Swing Timers** — main hand, off hand and ranged, with remaining time and weapon
speed. Fill or deplete, flip, swap the text sides, 0–2 decimals. Because vanilla's
combat log does not say which hand swung, a landed swing is attributed to
whichever hand has been ready *longest* — which is what lets the pair recover on
its own after a stun or a run out of range.

**Health** — green by default, any color, optionally your class color, which
overrides the swatch rather than replacing it. A **Color By Remaining Health**
checkbox marks where a continuous green-to-red gradient will go; it says outright
that it does nothing yet.

**Ranged Distance Check** — can you hit your target from here. **One bar, always
full**, and its color is the whole answer. All five colors are yours to set:

| State | Default |
|---|---|
| In range | green |
| Too close — inside a bow's dead zone | orange |
| Too far | red |
| No line of sight — something is in the way | violet, and off by default |
| No target | dark grey `#1f1f1f` — a placeholder, so you can see the bar is there |

The question is about **your equipped ranged weapon**, not some generic distance.
It reads your ranged slot, works out whether that is a bow, a gun, a crossbow, a
wand or a thrown weapon, and looks up the range of the auto-attack *you* fire with
it — so a wand has no dead zone, and a hunter's gun reaches further than a
warrior's, because Auto Shot and Shoot Gun are different spells with different
ranges.

How precisely it can answer depends on your client. With **Nampower** it uses the
game's own range check, including the real minimum range. **SuperWoW** adds exact
yardage for friendly units. Exact hostile yardage comes from Nampower when it
exposes `GetUnitDistance`, or from **UnitXP_SP3**. Without an exact source,
hostile targets still get the correct range state but not a numeric yardage. With
none of these extensions it falls back to your ranged attack's own action button,
found on your bars automatically, and failing that to the game's coarse
interaction distances.

Turn the No Target color's opacity down to zero if you would rather the bar
vanish when you have nothing selected.

**Check Line Of Sight** is off by default and needs nothing installed, but you
should know how it works before turning it on. Vanilla will not let an addon
*ask* whether something is in the way — there is no such API — so the only signal
is the client's own refusal: try to shoot, get *Target not in line of sight*, and
the bar turns violet for a couple of seconds. It cannot tell you in advance, and
it cannot notice the obstruction clearing, so it goes quiet on its own rather
than guessing.

In practice that is less of a gap than it sounds: while you are actually
shooting, the client retries and the refusal keeps arriving, so the bar stays
violet for as long as the wall is there. The gap is standing still and not
attacking.

Making it *continuous* needs a native query, because no vanilla API can be asked
this. OmniBars will use either `IsUnitInSight(unitToken)` — a Nampower build
extended the way `native/` extends it for distance — or **UnitXP_SP3**, whichever
is present. With one of those the bar turns the moment you step behind a pillar.

**Fallback Maximum Range** and **Fallback Dead Zone** are the range to assume
when nothing can supply the real one: a relic in the ranged slot (paladin,
shaman, druid), or a client without Nampower *and* an unrecognized weapon. On
most installs they never come into play.

Classes with a relic in the ranged slot have no ranged attack at all, so the bar
becomes a plain distance readout using that fallback range.

**Druid Mana** — how much mana you still have in bear or cat form. Vanilla stops
reporting it the moment you shift, so it is simulated from the shift onwards:
spirit regeneration, mana-per-5 from your gear, the shapeshift cost, Innervate
and the five second rule. If you log in already shifted there is no baseline to
work from, so the bar stays hidden rather than showing a confident wrong number.

Every module can be switched off independently on the **Modules** page.

## Profiles

One account-wide store. Every character starts on `Default`, which is why they
all line up: move a bar on one and it moves for all of them. Create as many
named profiles as you like and bind characters to them individually.

An existing `RogueBarsConfig` is imported into `Default` the first time OmniBars
loads, once. RogueBars' own saved variables are never modified.

## Commands

```
/eqob                          open the panel            (also /ob, /omnibars)
/eqob help                     every option, every scope
/eqob scale 120                a general option
/eqob bar resource h 20        a bar's geometry
/eqob power ticker nofull      a module's setting
/eqob profile use Raiding      use|new|copy|delete
/eqob restack                  re-stack the occupied bars
/eqob test                     preview every bar without a target
/eqob selftest                 check the addon against your client
/eqob rangedebug               every value behind the distance readout
/eqob reset                    this profile   ( reset all for every profile )
```

`/eqob rangedebug` is for when the Distance bar disagrees with your eyes. Target
something, run it, and it prints every raw client answer behind the reading —
which extensions replied and with what, what each of the four backends says about
*that* unit, and the state and yardage that came out. It also names the target
type, so a run against a friendly NPC and a run against an enemy player can be
compared line for line.

`/eqob selftest` is the one to run first if something looks wrong. It verifies
that every API each module needs exists on your client, that the bars were built
with a size and a position, that the values they draw from are sane, which range
backend you ended up on, and that the settings panel built completely — then
reports pass or fail per section. It changes nothing.

The panel and the prompt are generated from the same table, so anything you can
click you can type, and neither can drift out of step with the other.

## Moving things

Drag any bar. Right-click one for a nudge overlay with 1px arrows. Or type exact
coordinates on the Bars page.

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

SuperWoW and UnitXP_SP3 are optional. SuperWoW's `UnitPosition` supplies exact
friendly-unit coordinates; it does **not** expose hostile-unit coordinates, and
passing the unit's GUID instead of its token does not get round it — both
confirmed in game, not assumed. OmniBars also supports
`GetUnitDistance(unitToken)` from a Nampower build that exposes its existing
object-manager positions. UnitXP_SP3 remains a compatible exact hostile-distance
source.

So an **exact yard count on a hostile target needs one of those two native
extensions**. Nampower alone gets the color right on every target type — it
answers the range question for mobs perfectly well — but it has no number to
give, and there is no Lua-only substitute. The yards label is simply blank
there, and OmniBars says so once rather than leaving you watching an empty
label. The yards label is always
one exact current distance such as `23y`. The equipped attack's complete usable
range is shown separately as `[8-30y]`; both labels can be hidden or swapped
between the left and right sides. Stock Nampower 4.6.2 still provides the hostile
range state, but not the exact-yard label.

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
