-- Identify which game a ROM file on disk is, without importing it.
--
-- `--rom=<path>` (docs/guides/launch-options.md) hands the launcher a file
-- rather than a game name: a frontend such as RomM Desktop, ES-DE or
-- Playnite only knows which file the player clicked.  main.lua needs the
-- version before anything else happens, because the answer decides between
-- "boot the cache that is already there" and "import first, then boot".
-- RomImporter:startData does the same SHA-1 lookup, but only as the first
-- step of an import that wipes that version's cache, so this is the
-- read-only half of it: read, unwrap an archive, check the size, hash, map.
--
-- Pure apart from the file read and love.data.hash, both injectable through
-- `opts` so the engine test tier covers it without a window.

local GameVersion = require("src.core.GameVersion")

local RomIdentify = {}

local MiB = 1024 * 1024
-- Gen 1 / Gen 2 / Gen 3 cart sizes (the same set RomImporter accepts).
RomIdentify.ACCEPTED_BYTES = { [1 * MiB] = true, [2 * MiB] = true, [16 * MiB] = true }
-- A ROM archive only ever holds one small cart; anything bigger is refused
-- before it is read into a Lua string.  Matches RomArchive.MAX_ARCHIVE_BYTES.
RomIdentify.MAX_BYTES = 64 * MiB

local function sha1(data)
  local digest = love.data.hash("sha1", data)
  if type(digest) == "userdata" and digest.getString then
    digest = digest:getString()
  end
  return love.data.encode("string", "hex", digest)
end

local function isRomFilename(name)
  return type(name) == "string" and name:lower():match("%.gb[ac]?$") ~= nil
end

local function readNative(path)
  local file, openError = require("src.core.SaveData").openNative(path, "rb")
  if not file then return nil, openError end
  local size = file:seek("end")
  if type(size) == "number" and size > RomIdentify.MAX_BYTES then
    file:close()
    return nil, ("file is %.1f MiB; a ROM or ROM archive is at most %d MiB")
      :format(size / MiB, RomIdentify.MAX_BYTES / MiB)
  end
  file:seek("set", 0)
  local data = file:read("*a")
  file:close()
  if type(data) ~= "string" then return nil, "could not read the file" end
  return data
end

-- Resolve ROM bytes (raw or inside a .zip/.7z) to a version id.
-- Returns version, nil on success; nil, reason otherwise.
function RomIdentify.version(data, displayName, opts)
  opts = opts or {}
  if type(data) ~= "string" then return nil, "the file could not be read" end
  local hash = opts.sha1 or sha1
  local RomArchive = require("src.import.RomArchive")
  local kind = RomArchive.kind(data)
  if kind then
    if #data > RomArchive.MAX_ARCHIVE_BYTES then
      return nil, ("that .%s is %.1f MiB; a ROM archive only has to hold one small cart")
        :format(kind, #data / MiB)
    end
    local bytes, entry = RomArchive.unwrap(data, displayName, {
      fs = opts.fs,
      isRomName = isRomFilename,
      acceptedSize = function(n) return RomIdentify.ACCEPTED_BYTES[n] == true end,
      prefer = function(candidate) return GameVersion.forSha1(hash(candidate)) ~= nil end,
    })
    if not bytes then return nil, entry end
    data = bytes
  end
  if not RomIdentify.ACCEPTED_BYTES[#data] then
    return nil, ("expected a 1 MiB, 2 MiB or 16 MiB ROM; this file is %.2f MiB")
      :format(#data / MiB)
  end
  local digest = hash(data)
  local version = GameVersion.forSha1(digest)
  if not version then
    return nil, ("unsupported ROM (SHA-1 %s); only clean US dumps are accepted")
      :format(tostring(digest))
  end
  return version
end

-- Same, for a path outside LOVE's virtual filesystem (a frontend's cache or
-- library folder).  `opts.read(path) -> data | nil, err` replaces the native
-- read in tests.
function RomIdentify.pathVersion(path, opts)
  opts = opts or {}
  if type(path) ~= "string" or path == "" then return nil, "no ROM path given" end
  local data, readError = (opts.read or readNative)(path)
  if not data then
    return nil, ("could not read %s: %s"):format(path, tostring(readError))
  end
  return RomIdentify.version(data, path:match("[^/\\]+$") or path, opts)
end

return RomIdentify
