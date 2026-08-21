--[[ Equadis' Classic Overhaul :: the subsystems that are not written yet

  **Empty, and that is the point of keeping the file.**

  The Modules page was the roadmap: a subsystem appeared on it from the day it
  was planned rather than the day it worked, so there was one place to look for
  what this addon intended to be. Four lived here -- unit frames, nameplates,
  action bars and the chat port -- and every one of them has moved out to a file
  of its own.

  The rule they left by is the one worth keeping written down:

      A subsystem stays here until it has behaviour. The moment it does, it
      moves to a file of its own, exactly as the threat meter did.

  It worked in both directions. Unit frames and nameplates carried their full
  settings here for months before anything drew, transcribed from the addons
  being ported rather than invented -- so the ports filled them in instead of
  renegotiating them. Action bars arrived with no settings at all, because
  nothing had been decided, and a page of guesses would have been worse than a
  blank one: somebody sets a guess, it does nothing, and the day it starts
  working it does something they did not intend.

  The file stays for the next one, and there are two of them here now:
  waypoints and the map.
]]--

local OB = EquadisClassicOverhaul

--[[ **Waypoints**: an arrow that points at a coordinate, and a list of the ones
     you are keeping.

     TomTom for Turtle is the obvious source and **it carries no licence at
     all** -- no LICENSE file, and no mention of one in any source file, the TOC
     or the README. That is not the same as being GPL-3, and it is stricter
     rather than looser: with no grant there is no permission to copy it, so
     this addon going GPL-3 does not help. It needs the upstream grant found,
     the author asked, or the list written from scratch.

     pfQuest is already installed and already draws arrows, which is worth
     knowing before deciding: the useful half here may be one place to keep a
     list rather than a second arrow. ]]--
OB.RegisterModule({
    id = "waypoints",
    name = "Waypoints",
    feature = true,
    development = true,
    defaultEnabled = false,
    renders = "none",

    description = "Not written yet. A coordinate you can point at, an arrow that"
            .. " keeps pointing, and a list of the ones worth keeping.\n\nThe"
            .. " intended source is TomTom for Turtle, which states no licence"
            .. " at all -- not the same as GPL-3, and stricter rather than"
            .. " looser. That has to be settled first. This tab is here so the"
            .. " roadmap has one place to look.",
})

--[[ **The map**, which has one setting already and it is on the wrong page.

     Zone level ranges live under Quality Of Life, because that is where they
     arrived. They belong here and will move when there is something to move them
     into -- with a migration, because the two keys are already saved in
     profiles.

     What is missing is everything else that was asked for: the map's scale, how
     far it zooms, its border, and a clock that can be moved, resized and told
     whether to read your machine or the server. ]]--
OB.RegisterModule({
    id = "map",
    name = "Map",
    feature = true,
    development = true,
    defaultEnabled = false,
    renders = "none",

    description = "Not written yet. Scale, zoom and border for the world map,"
            .. " and a clock and zone name you can move, resize and re-font."
            .. "\n\nZone level ranges already work and are on the Quality Of"
            .. " Life page for now -- they move here when this one is built.",
})
