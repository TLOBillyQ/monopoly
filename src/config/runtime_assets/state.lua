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

function M.asset_context(root_state)
  if type(root_state) ~= "table" then
    return nil
  end
  if type(root_state.runtime_asset_context) == "table" then
    return root_state.runtime_asset_context
  end
  if type(root_state.ui_refs) == "table" then
    return { refs = root_state.ui_refs }
  end
  return nil
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

--[[ mutate4lua-manifest
version=2
projectHash=3dbc348a3421ffe6
scope.0.id=chunk:src/config/runtime_assets/state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=64
scope.0.semanticHash=0b38178fde06f6c3
scope.1.id=function:_default_startup_item_ids:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=14
scope.1.semanticHash=155206213c112706
scope.2.id=function:M.refs:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=26
scope.2.semanticHash=7b14f343ad55e33f
scope.3.id=function:M.images:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=30
scope.3.semanticHash=4548df6d65d8ce17
scope.4.id=function:M.skins:32
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=34
scope.4.semanticHash=13c1908577b564cd
scope.5.id=function:M.constants:36
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=38
scope.5.semanticHash=b95c5d3c2ce5dcf5
scope.6.id=function:M.startup_item_ids:40
scope.6.kind=function
scope.6.startLine=40
scope.6.endLine=42
scope.6.semanticHash=6b0876afcb53eea1
scope.7.id=function:M.compat_refs:44
scope.7.kind=function
scope.7.startLine=44
scope.7.endLine=46
scope.7.semanticHash=d3fd2b7dd3a70cec
scope.8.id=function:M.configure_for_tests:48
scope.8.kind=function
scope.8.startLine=48
scope.8.endLine=54
scope.8.semanticHash=017df65c5b5f85cb
scope.9.id=function:M.reset_for_tests:56
scope.9.kind=function
scope.9.startLine=56
scope.9.endLine=61
scope.9.semanticHash=a566bf1ebb804d81
]]
