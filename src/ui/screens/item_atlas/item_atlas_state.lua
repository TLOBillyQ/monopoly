-- 图鉴屏的面板态与目录/翻页纯逻辑:catalog 单一持有者。
-- 门面(../item_atlas.lua)只做行为编排与注册,测试目录注入也走这里。
local _default_catalog = require("src.config.content.item_atlas")
local number_utils = require("src.foundation.number")
local item_atlas_nodes = require("src.ui.schema.item_atlas")

local atlas_state = {}

local PAGE_SIZE = item_atlas_nodes.page_size
local _catalog = _default_catalog

function atlas_state.ensure(state)
  assert(state ~= nil, "missing state")
  local ui = assert(state.ui, "missing state.ui")
  ui.item_atlas = ui.item_atlas or {
    open = false,
    page_index = 1,
    selected_item_id = nil,
  }
  return ui.item_atlas
end

function atlas_state.clamp_page(page_index)
  local page = number_utils.to_integer(page_index)
  if page == nil then
    return 1
  end
  return number_utils.clamp(page, 1, number_utils.page_count(#_catalog, PAGE_SIZE))
end

function atlas_state.item_at(atlas, slot_index)
  local slot = number_utils.to_integer(slot_index) or 1
  return _catalog[(atlas.page_index - 1) * PAGE_SIZE + slot]
end

function atlas_state.catalog()
  return _catalog
end

function atlas_state.set_catalog(catalog)
  _catalog = catalog or _default_catalog
  return _catalog
end

return atlas_state

--[[ mutate4lua-manifest
version=4
projectHash=47eb35be0225b9e4
scope.0.id=chunk:src/ui/screens/item_atlas/item_atlas_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=9edc366fd7b56870
scope.1.id=function:atlas_state.ensure
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=21
scope.1.semanticHash=d801c9ed66c47684
scope.2.id=function:atlas_state.clamp_page
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=29
scope.2.semanticHash=f7b2fea0bf24d5db
scope.3.id=function:atlas_state.item_at
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=34
scope.3.semanticHash=659abe4c7c82db24
scope.4.id=function:atlas_state.catalog
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=38
scope.4.semanticHash=1136505bd37c301e
scope.5.id=function:atlas_state.set_catalog
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=43
scope.5.semanticHash=b0df8632502e77dd
]]
