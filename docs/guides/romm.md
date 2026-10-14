# RomM

[RomM](https://romm.app) is a self-hosted ROM library that runs in a Docker
container and plays games in the browser through EmulatorJS. This app can be
one of the "emulators" RomM launches, with two things to know up front.

## What RomM can and cannot do with this app

**In-browser play from the RomM web UI is not possible.** RomM's browser
player only runs EmulatorJS libretro cores and Ruffle; it has no slot for a
LÖVE game, and the RomM container itself has no display, so the app cannot
run *inside* the container either. Nothing in this repo can change that; it
would need a RomM feature.

**Launching from the RomM library on a desktop works today**, through
[RomM Desktop](https://github.com/rommapp/desktop): an Electron shell that
shows your server's own web UI and, when you press Play, downloads the ROM
to a local cache (or launches it in place from a local library folder) and
starts a locally installed emulator with the file. This app accepts that file
with [`--rom=`](launch-options.md#launching-from-a-rom-file), works out which
game it is by SHA-1, imports it on first launch, and boots straight in
afterwards. The ROM is read once per launch and is never uploaded anywhere;
the generated game data lives in the app's normal data folder, so RomM's
cache eviction does not cost you a re-import of anything but the ROM read.

Everything else about the app is unchanged: saves, options, mods and the
launcher all behave as they do when you start it by hand.

## Set up RomM Desktop

1. Install RomM Desktop on the machine you play on and point it at your
   server. Your RomM server's frontend must include the native play route
   (RomM 5.x with a recent frontend; see the RomM Desktop README).
2. Install this app on the same machine as usual, and note the executable
   path:
   - Linux AppImage: wherever you keep it, e.g. `~/Apps/gen1recomp.AppImage`
     (run `chmod +x` on it once)
   - Linux Flatpak: `/usr/bin/flatpak` with
     `["run", "com.theboisclub.gen1recomp", "--rom={rom}"]` as the args
   - Windows: e.g. `C:\Games\gen1recomp\gen1recomp.exe`
   - macOS: `/Applications/gen1recomp.app/Contents/MacOS/love`
3. Edit RomM Desktop's `desktop-config.json`:
   - Linux: `~/.config/romm-desktop/desktop-config.json`
   - macOS: `~/Library/Application Support/romm-desktop/desktop-config.json`
   - Windows: `%APPDATA%\romm-desktop\desktop-config.json`

   Add one `emulators` row per RomM platform you want this app to handle.
   RomM's slugs for the three families are `gb`, `gbc` and `gba`:

   ```json
   {
     "emulators": [
       { "platformSlug": "gb",  "label": "G1R Deluxe", "command": "/home/you/Apps/gen1recomp.AppImage", "args": ["--rom={rom}"] },
       { "platformSlug": "gbc", "label": "G1R Deluxe", "command": "/home/you/Apps/gen1recomp.AppImage", "args": ["--rom={rom}"] },
       { "platformSlug": "gba", "label": "G1R Deluxe", "command": "/home/you/Apps/gen1recomp.AppImage", "args": ["--rom={rom}"] }
     ]
   }
   ```

   RomM Desktop substitutes `{rom}` inside the argument, which is what this
   app needs: LÖVE treats a bare argument as a game folder, so `"--rom",
   "{rom}"` as two entries would not work. Keep the `--rom={rom}` spelling.
   The shell re-reads the file when it changes, so no restart is needed.
4. In RomM Desktop, open a Game Boy, Game Boy Color or Game Boy Advance game
   and press Play. The first launch of each game imports it (a few seconds);
   later launches boot directly.

A row you write beats RomM Desktop's autodetected RetroArch for that
platform, so every `gb`/`gbc`/`gba` title in your library will open in this
app. Only the eleven supported US ROMs are accepted (see the SHA-1 table in
the main README); any other cart on those platforms opens the launcher with
an "unsupported ROM" message instead of booting. If you keep other Game Boy
games in RomM, leave the platform on RetroArch and make a per-game
[desktop shortcut](launch-options.md) for the Pokemon titles instead, or use
RomM collections to keep them apart.

## Saves

This app keeps its own save slots per game in its data folder; it does not
read or write the `.sav` RomM Desktop manages, so RomM's save and savestate
sync does not cover it. Use the app's own save sync (the launcher's linked
devices) or [portable mode](portable-mode.md) if you move between machines.
The `{saves}` / `{savefile}` tokens are therefore not needed in the config.

## Other frontends

The same `--rom={rom}` idea works for any launcher with a per-platform
command: ES-DE, Playnite, LaunchBox, Pegasus, Lutris, Batocera's custom
emulator entries. Each has its own placeholder for the ROM path; use it in
place of `{rom}`, always glued to `--rom=` in one argument.
