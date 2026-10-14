# Launch options

By default the app opens the launcher so you can pick a game. Launch options
skip it and start one game directly, which is what you want for a one-click
entry: a desktop shortcut per game, a Steam entry, or a handheld frontend.

| Option | Effect |
| --- | --- |
| `--game=red` | boot Red, skipping the launcher (`blue`, `yellow`, `gold`, `silver` and `crystal` too, or just `r` / `b` / `y` / `g` / `s` / `c`) |
| `--cart=id` | boot the installed custom cart with that id |
| `--slot=2` | load that save slot; takes a slot number or a slot id |
| `--launcher` | open the launcher anyway, so you can edit a shortcut you already made |
| `--rom=/path/to/game.gb` | boot whichever game that file is, importing it first if it never was; for frontends that only know the file (see [Launching from a ROM file](#launching-from-a-rom-file)) |
| `--no-sync` | skip the save sync a linked device otherwise runs before the game boots (`POKEPORT_LAUNCH_SYNC=0`) |
| `--update` | check for a release first, and restart once into it if one is ready (`POKEPORT_LAUNCH_UPDATE=1`; `-update` works too) |
| `--update-mods` | run the MODS tab's Update all (mods and custom carts) without the confirm, then boot; stays on the launcher if an update fails (`POKEPORT_LAUNCH_UPDATE_MODS=1`; `--updatemods` works too) |

If this device is linked for save sync, a shortcut syncs before it boots so
CONTINUE never loads a save another device has already moved past. The screen
shows what it is doing and any button skips straight into the game; a sync
conflict opens the launcher so you can pick a copy rather than booting over
one.

## Launching from a ROM file

Most frontends do not know this app's game names; they know which file the
player clicked. `--rom=` takes that file instead of `--game=`:

```sh
gen1recomp --rom=/roms/gbc/Pokemon\ Crystal.gbc
POKEPORT_ROM=/roms/gb/red.gb gen1recomp     # for hosts that only pass env
```

The file is read and matched by SHA-1 against the accepted ROM table, so the
name does not matter and a `.zip` / `.7z` holding one ROM works where the
platform build opens archives. What happens next depends on that game:

- Already imported: it boots straight in, exactly as `--game=<that game>`
  would, so `--slot=`, `--no-sync`, `--update` and `--update-mods` apply.
- Not imported yet: the import runs with its usual progress screen (a few
  seconds), then the game boots. The generated cache lands in the normal app
  data folder, so the next launch of the same file skips the import.
- Not a supported ROM, or unreadable: the launcher opens and shows why.

`--game=` still wins when both are given, and `--launcher` still opens the
launcher. Only the `--rom=path` spelling works: LÖVE treats a bare argument as
a game folder, so `--rom path` never reaches the app.

This is the hook for [RomM Desktop](romm.md), ES-DE, Playnite, LaunchBox,
Pegasus and any other launcher with a per-platform emulator command.

## URL launch (Android and iOS)

Android and iOS accept the same launch request as a URL:

```text
gen1recomp++://launch?game=red
```

| URL | Effect |
| --- | --- |
| `gen1recomp++://launch?game=red` | boot Red directly |
| `gen1recomp++://launch?game=red&cart=my_cart` | boot the installed custom cart `my_cart` |
| `gen1recomp++://launch?game=red&slot=2` | boot Red and select save slot 2 |
| `gen1recomp++://launch?game=red&launcher=1` | open the launcher on Red instead |
| `gen1recomp++://launch?game=red&sync=0` | skip save sync |
| `gen1recomp++://launch?game=red&update=1` | check for an update before booting |
| `gen1recomp++://launch?game=red&update_mods=1` | update mods and carts before booting |

The `game` value accepts the same full names and aliases as `--game`. Boolean
parameters accept `1`/`0`, `true`/`false`, `yes`/`no`, and `on`/`off`.
Percent-encode values that contain characters reserved by URLs; the app
decodes query values before applying them. `cart` is the installed cart id
shown in the Custom Carts screen. Unknown parameters are ignored, and an
invalid game or cart falls back to the launcher.

To test a link on Android, use the installed application package:

```sh
adb shell am start -a android.intent.action.VIEW \
  -d 'gen1recomp++://launch?game=red' \
  com.theboisclub.pokemonred
```

To test a link in the iOS Simulator:

```sh
xcrun simctl openurl booted 'gen1recomp++://launch?game=red'
```

On a physical iPhone or iPad, open the URL from another app that can hand off
custom URLs, such as Notes, Messages, or Safari.
