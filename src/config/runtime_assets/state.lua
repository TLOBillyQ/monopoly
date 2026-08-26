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

function M.asset_context(root_state)
  if type(root_state) ~= "table" then
    return nil
  end
  local context = root_state.runtime_asset_context
  if type(context) ~= "table" then
    return nil
  end
  -- 空表(init_ui_assets 的占位)须归一为 nil:落到 refs() 时空表与 nil 一样
  -- 回落默认 refs,但 market _asset_opts 一类的包装缝会把空表当空 images,
  -- 吞掉默认查找(黑市道具图因此不加载)。
  if next(context) == nil then
    return nil
  end
  return context
end

-- startup_item_ids 单独成助手:短路 or 保证 opts 显式给值时不再求值
-- 默认构建(与 configure_for_tests 其余字段的 or 语义一致)。
local function _pick_startup_item_ids(opts)
  return opts.startup_item_ids or _default_startup_item_ids()
end

function M.configure_for_tests(opts)
  opts = opts or {}
  active_refs = opts.refs or default_refs
  active_skins = opts.skins or default_skins
  active_constants = opts.constants or default_constants
  active_startup_item_ids = _pick_startup_item_ids(opts)
end

function M.reset_for_tests()
  active_refs = default_refs
  active_skins = default_skins
  active_constants = default_constants
  active_startup_item_ids = _default_startup_item_ids()
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=077e40361e2fb2ea
scope.0.id=chunk:src/config/runtime_assets/state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=83
scope.0.semanticHash=34bbfc2b4fc55496
scope.1.id=function:_default_startup_item_ids
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=14
scope.1.semanticHash=e53681018d7554c0
scope.2.id=function:M.refs
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=26
scope.2.semanticHash=03c05cdd064642ae
scope.3.id=function:M.images
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=30
scope.3.semanticHash=946f58d3d1fc3837
scope.4.id=function:M.skins
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=34
scope.4.semanticHash=1136505bd37c301e
scope.5.id=function:M.constants
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=38
scope.5.semanticHash=1136505bd37c301e
scope.6.id=function:M.startup_item_ids
scope.6.kind=function
scope.6.startLine=40
scope.6.endLine=42
scope.6.semanticHash=1136505bd37c301e
scope.7.id=function:M.asset_context
scope.7.kind=function
scope.7.startLine=44
scope.7.endLine=59
scope.7.semanticHash=ab467e51987acf56
scope.8.id=function:_pick_startup_item_ids
scope.8.kind=function
scope.8.startLine=63
scope.8.endLine=65
scope.8.semanticHash=81941e008f67eb7e
scope.9.id=function:M.configure_for_tests
scope.9.kind=function
scope.9.startLine=67
scope.9.endLine=73
scope.9.semanticHash=c2d3d8b6991df657
scope.10.id=function:M.reset_for_tests
scope.10.kind=function
scope.10.startLine=75
scope.10.endLine=80
scope.10.semanticHash=0a3aa45a2f8adb69
]]
