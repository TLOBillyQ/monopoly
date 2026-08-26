-- Project acceptance step aggregator (monopoly#192).
--
-- The generated acceptance specs call
-- `require("packages.acceptance.steps").handlers()` to obtain the dispatch
-- table for `packages.acceptance.runtime`. That table is the engine's built-in
-- (corpus-independent) handlers merged with whatever the consuming project
-- contributes.
--
-- A consuming project's handlers live at the repo-root path
-- `features/steps/init.lua`. The template skeleton has no `features/`, so the
-- consumer binding is simply skipped there. The repo root is derived from this
-- file's own path (this file is `tools/packages/acceptance/steps.lua`) rather
-- than the current working directory, so it holds wherever the runner is
-- launched from.

local dsl = require("packages.acceptance.step_dsl")
local builtin = require("packages.acceptance.builtin_steps")

local steps = {}

local function _repo_root()
  local src_path = debug.getinfo(1, "S").source or "@tools/packages/acceptance/steps.lua"
  local normalized = tostring(src_path):gsub("^@", ""):gsub("\\", "/")
  local tools_dir = normalized:match("^(.*)/packages/acceptance/steps%.lua$")
  if tools_dir == nil then
    return "."
  end
  return tools_dir:match("^(.*)/tools$") or "."
end

-- Load the consuming project's handlers from features/steps/init.lua. Two return
-- shapes are accepted: a handlers table, or a module exposing `.handlers()`.
local function _consumer_handlers()
  local path = _repo_root() .. "/features/steps/init.lua"
  local probe = io.open(path, "r")
  if probe == nil then
    return nil
  end
  probe:close()

  local loaded = dofile(path)
  if type(loaded) == "table" and type(loaded.handlers) == "function" then
    return loaded.handlers()
  end
  return loaded
end

function steps.handlers()
  local h = builtin.handlers()
  local consumer = _consumer_handlers()
  if consumer ~= nil then
    dsl.merge(h, consumer, "features/steps/init.lua")
  end
  return h
end

return steps
