-- External games: launcher entries that play through another build.
--
-- Polished Crystal is a Crystal ROM hack with a text format, sound engine,
-- script commands and data layouts of its own.  Running it needs the Gen 2
-- engine the Gen2Recomped build carries, not this repo's.  Porting that engine
-- here would mean re-deriving every one of those findings against a different
-- codebase, and risking the eleven games that work today, for a tile that
-- would look exactly the same.  So the tile is here and the engine is there:
-- this launcher owns the entry (artwork, status, where the app and ROM live,
-- the SHA-1 check) and Play hands the ROM to the other build, which imports
-- it on its first launch and boots it directly afterwards.
--
-- Nothing in here touches the import or game code.  An external game is NOT a
-- GameVersion: it has no cache, no save slots and no manifest, so every loop
-- over GameVersion.VERSIONS keeps ignoring it.  It exists in exactly three
-- places: this registry, the launcher's game picker (LauncherView.gameTabs)
-- and the panel the picker opens (LauncherView buildExternalPanel).
--
-- Desktop only: the bridge spawns a process, which the console and mobile
-- builds cannot do.  On those the entry is not listed at all.
--
-- Pure apart from the hosts it is handed: every OS, file and environment
-- read is injectable through `opts`, so the engine test tier covers the
-- decisions without a window.

local ExternalGames = {}

local MiB = 1024 * 1024
ExternalGames.MAX_ROM_BYTES = 64 * MiB

-- The registry.  `after` is the GameVersion id the entry follows in the
-- picker so it sits with its generation; `env` is what the other build reads
-- (its main.lua: POKEPORT_VERSION picks the game, POKEPORT_IMPORT_ROM makes it
-- import that file when the game is not cached yet and boot it either way).
ExternalGames.GAMES = {
  polishedcrystal = {
    id = "polishedcrystal",
    label = "Polished Crystal",
    displayName = "Pokemon Polished Crystal",
    letter = "P",
    generation = 2,
    after = "crystal",
    beta = true,
    app = {
      name = "Gen2Recomped",
      url = "https://github.com/scotthowson/Gen2Recomped-howson/releases/latest",
      version = "polishedcrystal",
    },
    rom = {
      -- The patched ROM the v3.2.3 release produces (the build the other
      -- repo's symbol table and manifest were read from).  Any other build
      -- has different addresses, so it is refused rather than half-working.
      sha1 = { ["6930b48af5844d373e3c9130f26d6dd1084cf4ed"] = "3.2.3" },
      url = "https://github.com/Rangi42/polishedcrystal/releases/tag/v3.2.3",
      extensions = { "gbc", "gb" },
      hint = "Apply the v3.2.3 patch to a clean US Crystal dump and choose the patched .gbc.",
    },
  },
}

ExternalGames.ORDER = { "polishedcrystal" }

function ExternalGames.get(id)
  return type(id) == "string" and ExternalGames.GAMES[id] or nil
end

function ExternalGames.list()
  local out = {}
  for _, id in ipairs(ExternalGames.ORDER) do out[#out + 1] = ExternalGames.GAMES[id] end
  return out
end

-- Whether this host can run the bridge at all: a desktop that can spawn a
-- process.  Consoles, phones and the UWP build cannot, and must not list it.
function ExternalGames.available(opts)
  opts = opts or {}
  local osName = opts.os
  if osName == nil and type(love) == "table" and love.system and love.system.getOS then
    osName = love.system.getOS()
  end
  if osName ~= "Windows" and osName ~= "Linux" and osName ~= "OS X" then return false end
  local canSpawn = opts.canSpawn
  if canSpawn == nil then
    local ok, Platform = pcall(require, "src.core.Platform")
    canSpawn = ok and Platform.canSpawnProcess() or false
  end
  return canSpawn == true
end

-- ------------------------------------------------------------- settings
-- Stored in options.lua under externalGames[id] = { app = path, rom = path }.
-- `opts` is the loaded options table; callers persist it the usual way.

local function trim(value)
  if type(value) ~= "string" then return nil end
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value ~= "" and value or nil
end

function ExternalGames.settings(options, id)
  if type(options) ~= "table" then return {} end
  local all = type(options.externalGames) == "table" and options.externalGames or nil
  local entry = all and type(all[id]) == "table" and all[id] or nil
  return { app = trim(entry and entry.app), rom = trim(entry and entry.rom) }
end

function ExternalGames.setSetting(options, id, key, value)
  if type(options) ~= "table" or (key ~= "app" and key ~= "rom") then return false end
  if type(options.externalGames) ~= "table" then options.externalGames = {} end
  local entry = options.externalGames[id]
  if type(entry) ~= "table" then entry = {} options.externalGames[id] = entry end
  entry[key] = trim(value)
  return true
end

-- ------------------------------------------------------------- the ROM
local function sha1(data)
  local digest = love.data.hash("sha1", data)
  if type(digest) == "userdata" and digest.getString then digest = digest:getString() end
  return love.data.encode("string", "hex", digest)
end

local function readNative(path)
  local file, openError = require("src.core.SaveData").openNative(path, "rb")
  if not file then return nil, openError end
  local size = file:seek("end")
  if type(size) == "number" and size > ExternalGames.MAX_ROM_BYTES then
    file:close()
    return nil, ("file is %.1f MiB; that is not a Game Boy ROM"):format(size / MiB)
  end
  file:seek("set", 0)
  local data = file:read("*a")
  file:close()
  if type(data) ~= "string" then return nil, "could not read the file" end
  return data
end

-- Check a ROM file against the entry's accepted builds.
-- Returns label (the build it is), nil on success; nil, reason otherwise.
function ExternalGames.verifyRom(entry, path, opts)
  opts = opts or {}
  if type(entry) ~= "table" or type(entry.rom) ~= "table" then return nil, "no such game" end
  if type(path) ~= "string" or path == "" then return nil, "no ROM chosen" end
  local data, readError = (opts.read or readNative)(path)
  if not data then
    return nil, ("could not read %s: %s"):format(path:match("[^/\\]+$") or path, tostring(readError))
  end
  local digest = (opts.sha1 or sha1)(data)
  local label = entry.rom.sha1[digest]
  if not label then
    return nil, ("not a supported build (SHA-1 %s); %s"):format(tostring(digest),
      entry.rom.hint or "choose the release build")
  end
  return label
end

-- ------------------------------------------------------------- the app
local function isAppBundle(path)
  return type(path) == "string" and path:lower():match("%.app/?$") ~= nil
end

-- Does the chosen app path exist?  A macOS .app is a directory, so the
-- check is for the bundle's executable folder rather than the path itself.
function ExternalGames.appPresent(path, opts)
  opts = opts or {}
  if type(path) ~= "string" or path == "" then return false end
  local probe = opts.exists
  if not probe then
    probe = function(p)
      local f = io.open(p, "rb")
      if f then f:close() return true end
      return false
    end
  end
  if isAppBundle(path) then
    return probe(path:gsub("/?$", "") .. "/Contents/Info.plist")
  end
  return probe(path)
end

-- The environment the other build reads, as a list of { name, value }.
function ExternalGames.environment(entry, settings)
  return {
    { "POKEPORT_VERSION", entry.app.version },
    { "POKEPORT_IMPORT_ROM", settings.rom },
  }
end

-- What to run, by host.  Returns a table the spawner understands:
--   { exe = path, args = {...}, env = {{name, value}, ...}, cwd = dir }
-- A macOS .app bundle goes through `open`, which is the only thing that
-- launches a bundle the way a double-click does (LSEnvironment aside, its
-- --env flag is how the two variables reach the app).
function ExternalGames.command(entry, settings, osName)
  if type(entry) ~= "table" or type(settings) ~= "table" then return nil, "no such game" end
  if not settings.app then return nil, "choose the " .. entry.app.name .. " app first" end
  if not settings.rom then return nil, "choose the ROM first" end
  local env = ExternalGames.environment(entry, settings)
  if osName == "OS X" and isAppBundle(settings.app) then
    local args = { "-n", settings.app }
    for _, pair in ipairs(env) do
      args[#args + 1] = "--env"
      args[#args + 1] = pair[1] .. "=" .. pair[2]
    end
    return { exe = "/usr/bin/open", args = args, env = {}, cwd = nil }
  end
  local dir = settings.app:match("^(.*)[\\/][^\\/]*$")
  return { exe = settings.app, args = {}, env = env, cwd = dir ~= "" and dir or nil }
end

-- Ready to press Play?  Returns true, label or false, reason.
function ExternalGames.readiness(entry, settings, opts)
  opts = opts or {}
  if not settings.app then return false, "app", "Choose where " .. entry.app.name .. " is installed." end
  if not ExternalGames.appPresent(settings.app, opts) then
    return false, "app", entry.app.name .. " is no longer at that path. Choose it again."
  end
  if not settings.rom then return false, "rom", "Choose your Polished Crystal ROM." end
  local label, why = ExternalGames.verifyRom(entry, settings.rom, opts)
  if not label then return false, "rom", why end
  return true, label
end

-- Group picker entries by generation, in list order, for the game modal.
-- Each entry needs a numeric `gen`.  Returns { { gen = n, items = {...} }, ... }.
function ExternalGames.groupByGeneration(entries)
  local groups, byGen = {}, {}
  for _, entry in ipairs(entries) do
    local gen = tonumber(entry.gen) or 1
    local group = byGen[gen]
    if not group then
      group = { gen = gen, items = {} }
      byGen[gen] = group
      groups[#groups + 1] = group
    end
    group.items[#group.items + 1] = entry
  end
  table.sort(groups, function(a, b) return a.gen < b.gen end)
  return groups
end

ExternalGames.GENERATION_LABELS = {
  [1] = "GEN 1 - GAME BOY",
  [2] = "GEN 2 - GAME BOY COLOR",
  [3] = "GEN 3 - GAME BOY ADVANCE",
}

-- Splice the external entries into a picker list after their `after` game
-- (or at the end of their generation when that game is hidden).
function ExternalGames.splice(list, externals)
  local out = {}
  for _, item in ipairs(list) do out[#out + 1] = item end
  for _, ext in ipairs(externals) do
    local at = nil
    for i, item in ipairs(out) do
      if item.id == ext.after then at = i break end
    end
    if not at then
      for i = #out, 1, -1 do
        if (tonumber(out[i].gen) or 1) <= ext.gen then at = i break end
      end
    end
    table.insert(out, (at or 0) + 1, ext)
  end
  return out
end

return ExternalGames
