package.path = "./?.lua;./?/init.lua;" .. package.path

-- External games (docs/guides/polished-crystal.md): a launcher entry that
-- plays through another build.  The registry, the stored paths, the ROM
-- check, the spawn command per host and the picker grouping are all pure,
-- so they are proven here without a window.

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local ExternalGames = require("src.import.ExternalGames")
local MiB = 1024 * 1024

-- registry
do
  local list = ExternalGames.list()
  eq(#list, 1, "one external game is registered")
  local pc = ExternalGames.get("polishedcrystal")
  check(pc ~= nil and pc == list[1], "Polished Crystal is it")
  eq(pc.generation, 2, "it sits with Gen 2")
  eq(pc.after, "crystal", "right after Crystal")
  eq(pc.rom.sha1["6930b48af5844d373e3c9130f26d6dd1084cf4ed"], "3.2.3",
    "the accepted build is the v3.2.3 release ROM")
  eq(ExternalGames.get("crystal"), nil, "a GameVersion id is not an external game")
  eq(ExternalGames.get(nil), nil, "nil is not either")
end

-- availability
do
  check(ExternalGames.available({ os = "Linux", canSpawn = true }), "Linux desktop can run the bridge")
  check(ExternalGames.available({ os = "Windows", canSpawn = true }), "Windows too")
  check(ExternalGames.available({ os = "OS X", canSpawn = true }), "and macOS")
  check(not ExternalGames.available({ os = "Android", canSpawn = true }), "phones cannot")
  check(not ExternalGames.available({ os = "Linux", canSpawn = false }),
    "a desktop that cannot spawn (console builds) cannot either")
end

-- settings on the options table
do
  local opts = {}
  eq(ExternalGames.settings(opts, "polishedcrystal").app, nil, "nothing stored yet")
  check(ExternalGames.setSetting(opts, "polishedcrystal", "app", "  /Apps/Gen2Recomped.AppImage "),
    "an app path is stored")
  check(ExternalGames.setSetting(opts, "polishedcrystal", "rom", "/roms/pc.gbc"), "a ROM path too")
  local s = ExternalGames.settings(opts, "polishedcrystal")
  eq(s.app, "/Apps/Gen2Recomped.AppImage", "the app path is trimmed")
  eq(s.rom, "/roms/pc.gbc", "the ROM path is kept")
  check(not ExternalGames.setSetting(opts, "polishedcrystal", "cheat", "x"), "unknown keys are refused")
  ExternalGames.setSetting(opts, "polishedcrystal", "rom", "")
  eq(ExternalGames.settings(opts, "polishedcrystal").rom, nil, "a blank clears the path")
  eq(ExternalGames.settings(nil, "polishedcrystal").app, nil, "no options table, no paths")
end

-- the ROM check
local pc = ExternalGames.get("polishedcrystal")
local function bytes(n) return string.rep("\0", n) end
local function hashFor(sha1) return function() return sha1 end end
do
  local good = "6930b48af5844d373e3c9130f26d6dd1084cf4ed"
  local read = function(path)
    if path == "/roms/pc.gbc" then return bytes(2 * MiB) end
    if path == "/roms/other.gbc" then return bytes(2 * MiB) end
    return nil, "No such file or directory"
  end
  local label, why = ExternalGames.verifyRom(pc, "/roms/pc.gbc", { read = read, sha1 = hashFor(good) })
  eq(label, "3.2.3", "the release ROM verifies to its build label")
  eq(why, nil, "with no complaint")

  label, why = ExternalGames.verifyRom(pc, "/roms/other.gbc", { read = read, sha1 = hashFor(("a"):rep(40)) })
  eq(label, nil, "another build is refused")
  check(type(why) == "string" and why:find("not a supported build", 1, true) ~= nil
    and why:find("v3.2.3", 1, true) ~= nil,
    "and the reason says which build to get: " .. tostring(why))

  label, why = ExternalGames.verifyRom(pc, "/roms/gone.gbc", { read = read, sha1 = hashFor(good) })
  eq(label, nil, "a missing file is refused")
  check(type(why) == "string" and why:find("gone.gbc", 1, true) ~= nil,
    "naming the file: " .. tostring(why))

  label, why = ExternalGames.verifyRom(pc, nil, { read = read })
  eq(label, nil, "no path is refused")
  check(type(why) == "string", "with a reason")
end

-- readiness ties the two together
do
  local good = "6930b48af5844d373e3c9130f26d6dd1084cf4ed"
  local io = {
    read = function() return bytes(2 * MiB) end,
    sha1 = hashFor(good),
    exists = function(p) return p == "/Apps/g2r" or p == "/Applications/Gen2Recomped.app/Contents/Info.plist" end,
  }
  local ready, which, text = ExternalGames.readiness(pc, { app = nil, rom = nil }, io)
  eq(ready, false, "nothing chosen is not ready")
  eq(which, "app", "and the app comes first")
  check(type(text) == "string" and text:find("Gen2Recomped", 1, true) ~= nil, "naming the app: " .. tostring(text))

  ready, which = ExternalGames.readiness(pc, { app = "/Apps/missing", rom = "/r.gbc" }, io)
  eq(ready, false, "an app path that is gone is not ready")
  eq(which, "app", "and it is the app's fault")

  ready, which = ExternalGames.readiness(pc, { app = "/Apps/g2r", rom = nil }, io)
  eq(ready, false, "app without ROM is not ready")
  eq(which, "rom", "and it is the ROM's turn")

  ready, which = ExternalGames.readiness(pc, { app = "/Apps/g2r", rom = "/r.gbc" }, io)
  eq(ready, true, "both present and verified is ready")
  eq(which, "3.2.3", "and reports the build")

  ready = ExternalGames.readiness(pc, { app = "/Applications/Gen2Recomped.app", rom = "/r.gbc" }, io)
  eq(ready, true, "a macOS .app bundle counts as present through its Info.plist")
end

-- the spawn command per host
do
  local settings = { app = "C:\\Games\\Gen2Recomped\\Gen2Recomped.exe", rom = "D:\\roms\\pc.gbc" }
  local spec = ExternalGames.command(pc, settings, "Windows")
  eq(spec.exe, settings.app, "Windows runs the exe itself")
  eq(#spec.args, 0, "with no arguments")
  eq(spec.cwd, "C:\\Games\\Gen2Recomped", "from its own folder")
  eq(spec.env[1][1], "POKEPORT_VERSION", "the game goes in the environment")
  eq(spec.env[1][2], "polishedcrystal", "as the other build's version id")
  eq(spec.env[2][1], "POKEPORT_IMPORT_ROM", "with the ROM path")
  eq(spec.env[2][2], settings.rom, "verbatim")

  spec = ExternalGames.command(pc, { app = "/home/me/Apps/g2r.AppImage", rom = "/roms/pc.gbc" }, "Linux")
  eq(spec.exe, "/home/me/Apps/g2r.AppImage", "Linux runs the AppImage")
  eq(spec.cwd, "/home/me/Apps", "from its folder")

  spec = ExternalGames.command(pc, { app = "/Applications/Gen2Recomped.app", rom = "/roms/pc.gbc" }, "OS X")
  eq(spec.exe, "/usr/bin/open", "a macOS bundle goes through open")
  eq(spec.args[1], "-n", "as a new instance")
  eq(spec.args[2], "/Applications/Gen2Recomped.app", "of that bundle")
  eq(spec.args[3], "--env", "with the environment passed through open")
  eq(spec.args[4], "POKEPORT_VERSION=polishedcrystal", "the game")
  eq(spec.args[6], "POKEPORT_IMPORT_ROM=/roms/pc.gbc", "and the ROM")
  eq(#spec.env, 0, "and nothing left for the spawner to set")

  spec = ExternalGames.command(pc, { app = "/Applications/love", rom = "/roms/pc.gbc" }, "OS X")
  eq(spec.exe, "/Applications/love", "a bare macOS executable runs directly")
  eq(#spec.env, 2, "with the environment set by the spawner")

  local none, why = ExternalGames.command(pc, { app = nil, rom = "/r" }, "Linux")
  eq(none, nil, "no app, no command")
  check(type(why) == "string" and why:find("Gen2Recomped", 1, true) ~= nil, "and it says what to choose")
  none, why = ExternalGames.command(pc, { app = "/a", rom = nil }, "Linux")
  eq(none, nil, "no ROM, no command")
  check(type(why) == "string" and why:find("ROM", 1, true) ~= nil, "and it says so")
end

-- picker grouping and splicing
do
  local list = {
    { id = "red", gen = 1 }, { id = "blue", gen = 1 }, { id = "yellow", gen = 1 },
    { id = "gold", gen = 2 }, { id = "silver", gen = 2 }, { id = "crystal", gen = 2 },
    { id = "firered", gen = 3 }, { id = "emerald", gen = 3 },
  }
  local ext = { { id = "polishedcrystal", gen = 2, after = "crystal", external = true } }
  local spliced = ExternalGames.splice(list, ext)
  eq(#spliced, 9, "the external entry is added")
  eq(spliced[7].id, "polishedcrystal", "right after Crystal")
  eq(spliced[8].id, "firered", "before Gen 3")
  eq(#list, 8, "without touching the input list")

  local groups = ExternalGames.groupByGeneration(spliced)
  eq(#groups, 3, "three generations")
  eq(groups[1].gen, 1, "Gen 1 first")
  eq(#groups[1].items, 3, "with its three games")
  eq(groups[2].gen, 2, "Gen 2 second")
  eq(#groups[2].items, 4, "Crystal's shelf holds Polished too")
  eq(groups[2].items[4].id, "polishedcrystal", "at the end of it")
  eq(#groups[3].items, 2, "Gen 3 third")
  eq(ExternalGames.GENERATION_LABELS[2], "GEN 2 - GAME BOY COLOR", "and each shelf has a header")

  local hidden = { { id = "red", gen = 1 }, { id = "gold", gen = 2 }, { id = "firered", gen = 3 } }
  spliced = ExternalGames.splice(hidden, ext)
  eq(spliced[3].id, "polishedcrystal", "with Crystal hidden it closes out Gen 2 instead")
  eq(spliced[4].id, "firered", "still ahead of Gen 3")

  spliced = ExternalGames.splice({ { id = "firered", gen = 3 } }, ext)
  eq(spliced[1].id, "polishedcrystal", "with no Gen 1 or 2 at all it leads")
end

T.finish("external games (Polished Crystal bridge)")
