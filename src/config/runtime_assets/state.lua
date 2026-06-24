local default_refs = require("src.config.content.runtime_refs")
local default_skins = require("src.config.content.skins")
local default_constants = require("src.config.gameplay.runtime_constants")

local M = {}

local active_refs = default_refs
local active_skins = default_skins
local active_constants = default_constants
local active_startup_item_ids

local function _default_startup_item_ids()
  return { 3001, 3002, 3003, 3004, 3005 }
end

active_startup_item_ids = _default_startup_item_ids()

function M.refs(opts)
  if type(opts) == "table" and type(opts.refs) == "table" then
    return opts.refs
  end
  if type(opts) == "table" and type(opts.images) == "table" then
    return opts
  end
  return active_refs
end

function M.images(opts)
  return M.refs(opts).images or {}
end

function M.skins()
  return active_skins
end

function M.constants()
  return active_constants
end

function M.startup_item_ids()
  return active_startup_item_ids
end

function M.compat_refs()
  return active_refs
end

function M.configure_for_tests(opts)
  opts = opts or {}
  active_refs = opts.refs or default_refs
  active_skins = opts.skins or default_skins
  active_constants = opts.constants or default_constants
  active_startup_item_ids = opts.startup_item_ids or _default_startup_item_ids()
end

function M.reset_for_tests()
  active_refs = default_refs
  active_skins = default_skins
  active_constants = default_constants
  active_startup_item_ids = _default_startup_item_ids()
end

return M
