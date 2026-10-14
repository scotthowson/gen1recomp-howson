# Polished Crystal

[Polished Crystal](https://github.com/Rangi42/polishedcrystal) is a Crystal
ROM hack with an engine of its own: a different text format, sound engine,
script commands and data layouts. This launcher lists it under Gen 2 next to
Crystal, but it does not run it in this engine. Pressing Play starts it in
the [Gen2Recomped](https://github.com/scotthowson/Gen2Recomped-howson) build,
which carries the engine that was rebuilt around that hack. The entry is in
beta and desktop only (Windows, Linux, macOS).

Nothing about the other eleven games changes. The Polished Crystal panel has
no save slots, no cache and no import of its own; the other build owns those.

## Setup

1. Install the Gen2Recomped build somewhere permanent. Any of its desktop
   downloads works: the Windows `.exe`, the Linux AppImage, or the macOS
   `.app`.
2. Build the ROM. Download the **v3.2.3** release from the
   [Polished Crystal releases page](https://github.com/Rangi42/polishedcrystal/releases/tag/v3.2.3)
   and apply its patch to a clean US Pokemon Crystal dump. Keep the patched
   `.gbc` somewhere permanent too. Only the 3.2.3 build is accepted:

   | Build | SHA-1 |
   | --- | --- |
   | Polished Crystal 3.2.3 | `6930b48af5844d373e3c9130f26d6dd1084cf4ed` |

   Other builds have different addresses, so the launcher refuses them with
   the SHA-1 it saw rather than handing over a ROM that would half work.
3. Open the launcher, press the game dropdown and pick **Polished Crystal**
   under *GEN 2 - GAME BOY COLOR*.
4. Press **Choose app** and select the Gen2Recomped executable (the `.app`
   itself on macOS).
5. Press **Choose ROM** and select the patched `.gbc`, or drop the file onto
   the window while the panel is open. The panel shows *Verified 3.2.3
   build* when the hash matches.
6. Press **Play**. The first launch imports the ROM inside Gen2Recomped,
   which takes a few seconds; every later launch boots straight in.

Both paths are remembered in `options.lua` under `externalGames`, so this is
a one-time setup. If you move either file, the panel says so and asks you to
choose it again.

## What Play does

The launcher starts the other build with two environment variables it already
understands, `POKEPORT_VERSION=polishedcrystal` and `POKEPORT_IMPORT_ROM`
pointing at your file, then returns to its own window. No shell window opens
on Windows, and the ROM is read only by the other build. Saves, options and
mods for Polished Crystal live with Gen2Recomped, so save sync and the save
editor here do not see them.

## Why a bridge and not a port

The two builds share an ancestor but their Gen 2 engines have diverged a long
way. The Polished Crystal support over there is woven through its extractor,
script VM, text decoder and sound engine. Re-deriving all of that against this
repo's Gen 2 code is weeks of work and the kind of change that puts the games
that work today at risk, for a tile that would look identical. If the port
ever happens, the tile, the generation grouping and the hash check all carry
over; only what Play does would change.
