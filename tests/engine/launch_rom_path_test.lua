package.path = "./?.lua;./?/init.lua;" .. package.path

-- --rom=<path> / POKEPORT_ROM: a frontend hands over the ROM file the player
-- clicked instead of a game name (docs/guides/romm.md).  LaunchOptions
-- carries the path; RomIdentify maps the file to a version by SHA-1 without
-- importing it, so main.lua can boot a cache that is already there.

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")
love.data = love.data or {}

local LaunchOptions = require("src.core.LaunchOptions")
local RomIdentify = require("src.import.RomIdentify")
local GameVersion = require("src.core.GameVersion")

local savedGetenv = os.getenv
local env = {}
os.getenv = function(name)
  if env[name] ~= nil then return env[name] end
  return savedGetenv(name)
end

-- LaunchOptions: the path rides the resolved request.
do
  local resolved = LaunchOptions.resolveRequest({ "--rom=/roms/gb/red.gb" }, {})
  eq(resolved.rom, "/roms/gb/red.gb", "--rom= carries the path")
  eq(resolved.game, nil, "a bare --rom names no game; main.lua identifies it")

  resolved = LaunchOptions.resolveRequest({ "--rom=C:\\Games\\Pokemon Yellow.gbc", "--slot=2" }, {})
  eq(resolved.rom, "C:\\Games\\Pokemon Yellow.gbc", "Windows paths with spaces survive")
  eq(resolved.slot, "2", "--slot still applies alongside --rom")

  resolved = LaunchOptions.resolveRequest({ "--rom=  " }, {})
  eq(resolved.rom, nil, "a blank --rom is no path at all")

  env.POKEPORT_ROM = "/env/blue.gb"
  resolved = LaunchOptions.resolveRequest({}, {})
  eq(resolved.rom, "/env/blue.gb", "POKEPORT_ROM fills in for hosts that only pass env")
  resolved = LaunchOptions.resolveRequest({ "--rom=/cli/red.gb" }, {})
  eq(resolved.rom, "/cli/red.gb", "the command line wins over the environment")
  env.POKEPORT_ROM = nil

  resolved = LaunchOptions.resolveRequest({ "--rom=/roms/red.gb", "--game=blue" }, {})
  eq(resolved.game, "blue", "an explicit --game is kept next to --rom")
  eq(resolved.rom, "/roms/red.gb", "and the path is still reported")

  resolved = LaunchOptions.resolveRequest({}, {})
  eq(resolved.rom, nil, "no flag, no env: no path")
end

-- RomIdentify: size gate, SHA-1 map, archive refusal, read errors.
local MiB = 1024 * 1024
local function bytes(n) return string.rep("\0", n) end
local function hashFor(sha1)
  return function() return sha1 end
end

do
  local red = GameVersion.VERSIONS.red.sha1
  local version, why = RomIdentify.version(bytes(1 * MiB), "red.gb", { sha1 = hashFor(red) })
  eq(version, "red", "a 1 MiB ROM with Red's SHA-1 is Red")
  eq(why, nil, "no reason on success")

  local crystal11 = "f2f52230b536214ef7c9924f483392993e226cfb"
  version = RomIdentify.version(bytes(2 * MiB), "crystal.gbc", { sha1 = hashFor(crystal11) })
  eq(version, "crystal", "every accepted revision of a game maps to its version")

  local emerald = GameVersion.VERSIONS.emerald.sha1
  version = RomIdentify.version(bytes(16 * MiB), "emerald.gba", { sha1 = hashFor(emerald) })
  eq(version, "emerald", "16 MiB GBA carts are accepted")

  version, why = RomIdentify.version(bytes(1 * MiB), "hack.gb", { sha1 = hashFor(("0"):rep(40)) })
  eq(version, nil, "an unknown SHA-1 is refused")
  check(type(why) == "string" and why:find("unsupported ROM", 1, true) ~= nil,
    "and the reason names the problem: " .. tostring(why))

  version, why = RomIdentify.version(bytes(512 * 1024), "trimmed.gb", { sha1 = hashFor(red) })
  eq(version, nil, "a trimmed ROM never reaches the hash")
  check(type(why) == "string" and why:find("0.50 MiB", 1, true) ~= nil,
    "the size reason quotes the file's size: " .. tostring(why))

  version, why = RomIdentify.version(nil, "missing.gb", { sha1 = hashFor(red) })
  eq(version, nil, "no data is refused")
  check(type(why) == "string", "with a reason")
end

do
  local red = GameVersion.VERSIONS.red.sha1
  local reads = {}
  local function read(path)
    reads[#reads + 1] = path
    if path == "/roms/red.gb" then return bytes(1 * MiB) end
    return nil, "No such file or directory"
  end

  local version, why = RomIdentify.pathVersion("/roms/red.gb", { read = read, sha1 = hashFor(red) })
  eq(version, "red", "a readable path resolves through the same map")
  eq(why, nil, "no reason on success")
  eq(reads[1], "/roms/red.gb", "the path is read as given")

  version, why = RomIdentify.pathVersion("/roms/gone.gb", { read = read, sha1 = hashFor(red) })
  eq(version, nil, "an unreadable path is refused")
  check(type(why) == "string" and why:find("/roms/gone.gb", 1, true) ~= nil
    and why:find("No such file", 1, true) ~= nil,
    "the reason names the path and the OS error: " .. tostring(why))

  version, why = RomIdentify.pathVersion(nil, { read = read })
  eq(version, nil, "nil path is refused")
  version, why = RomIdentify.pathVersion("", { read = read })
  eq(version, nil, "empty path is refused")
  eq(#reads, 2, "neither reached the file read")
end

os.getenv = savedGetenv
T.finish("ROM path launch (--rom)")
