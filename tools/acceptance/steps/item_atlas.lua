local number_utils = require("src.foundation.number")
local item_atlas = require("src.ui.coord.item_atlas")
local item_atlas_nodes = require("src.ui.schema.item_atlas")
local view_command = require("src.ui.input.dispatch.view_command")
local base_intents = require("src.ui.input.canvas_route.base")
local base_nodes = require("src.ui.schema.base")

local item_atlas_steps = {}

local function _make_catalog(n)
  local t = {}
  for i = 1, n do
    t[i] = { id = "item_" .. i, name = "道具" .. i, description = "描述" .. i }
  end
  return t
end

local function _seed_image_refs(state)
  for _, item in ipairs(item_atlas.catalog or {}) do
    state.ui_refs.images[tostring(item.id)] = "tex_" .. tostring(item.id)
  end
end

local function _ensure_atlas_state(world)
  if not world.atlas_state then
    local visibility = {}
    local labels = {}
    world.atlas_state = {
      ui = {
        set_visible = function(_, name, visible)
          visibility[name] = visible == true
        end,
        set_label = function(_, name, text)
          labels[name] = text
        end,
      },
      ui_refs = { images = {} },
    }
    world.atlas_visibility = visibility
    world.atlas_labels = labels
    if not world.atlas_catalog_injected then
      item_atlas.reset_for_tests()
    end
    _seed_image_refs(world.atlas_state)
  end
  return world.atlas_state
end

local SLOTS_PER_PAGE = 8

local function _atlas(world)
  if not world.atlas_state then return nil end
  return world.atlas_state.ui.item_atlas
end

local function _resolve_slot_item(world, slot)
  local a = _atlas(world)
  local idx = (a.page_index - 1) * SLOTS_PER_PAGE + slot
  return item_atlas.catalog[idx], a
end

function item_atlas_steps.handlers()
  return {
    -- ── catalog injection ─────────────────────────────────────────────────────
    ["道具目录共有<p2>种道具"] = function(world, example)
      local n = number_utils.to_integer(example.p2)
      if n == nil then return nil, "invalid item count: " .. tostring(example.p2) end
      item_atlas.configure_catalog_for_tests(_make_catalog(n))
      world.atlas_catalog_injected = true
      return true
    end,

    -- ── open / close ──────────────────────────────────────────────────────────
    ["玩家打开道具图鉴"] = function(world)
      _ensure_atlas_state(world)
      item_atlas.open(world.atlas_state, world.ui_role_id or 1)
      return true
    end,

    ["玩家关闭道具图鉴"] = function(world)
      _ensure_atlas_state(world)
      item_atlas.close(world.atlas_state)
      return true
    end,

    ["道具图鉴屏幕已开启"] = function(world)
      local a = _atlas(world)
      if not (a and a.open) then
        return nil, "item atlas is not open"
      end
      return true
    end,

    ["道具图鉴屏幕已关闭"] = function(world)
      local a = _atlas(world)
      if a and a.open then
        return nil, "item atlas is still open"
      end
      return true
    end,

    -- ── slot count assertion ──────────────────────────────────────────────────
    ["当前页面展示<p3>个道具槽位"] = function(world, example)
      local expected = number_utils.to_integer(example.p3)
      if expected == nil then return nil, "invalid slot count: " .. tostring(example.p3) end
      local count = 0
      for i = 1, SLOTS_PER_PAGE do
        if _resolve_slot_item(world, i) then count = count + 1 end
      end
      if count ~= expected then
        return nil, "expected " .. tostring(expected) .. " slots, got " .. tostring(count)
      end
      return true
    end,

    -- ── select slot ───────────────────────────────────────────────────────────
    ["玩家选中第<p4>格道具"] = function(world, example)
      local slot = number_utils.to_integer(example.p4)
      if slot == nil then return nil, "invalid slot: " .. tostring(example.p4) end
      item_atlas.handle_action(world.atlas_state, { type = "select", slot_index = slot }, world.ui_role_id or 1)
      return true
    end,

    ["当前选中道具为第<p4>格对应道具"] = function(world, example)
      local slot = number_utils.to_integer(example.p4)
      if slot == nil then return nil, "invalid slot: " .. tostring(example.p4) end
      local item, a = _resolve_slot_item(world, slot)
      if not item then return nil, "no item at slot " .. tostring(slot) end
      if a.selected_item_id ~= item.id then
        return nil, "selected item mismatch: expected " .. tostring(item.id) .. ", got " .. tostring(a.selected_item_id)
      end
      return true
    end,

    ["当前选中道具ID为<p5>"] = function(world, example)
      local expected_id = tostring(example.p5 or "")
      local a = _atlas(world)
      if a.selected_item_id ~= expected_id then
        return nil, "selected item id mismatch: expected " .. expected_id
          .. ", got " .. tostring(a.selected_item_id)
      end
      return true
    end,

    -- ── enlarged card ─────────────────────────────────────────────────────────
    ["放大卡牌已展示"] = function(world)
      local a = _atlas(world)
      if not (a and a.selected_item_id ~= nil) then
        return nil, "enlarged card is not visible (no item selected)"
      end
      return true
    end,

    ["放大卡牌已隐藏"] = function(world)
      local a = _atlas(world)
      if a and a.selected_item_id ~= nil then
        return nil, "enlarged card is still visible (item selected: " .. tostring(a.selected_item_id) .. ")"
      end
      return true
    end,

    ["放大卡牌显示第<p4>格道具的名称"] = function(world, example)
      local slot = number_utils.to_integer(example.p4)
      if slot == nil then return nil, "invalid slot: " .. tostring(example.p4) end
      local item, a = _resolve_slot_item(world, slot)
      if not item then return nil, "no item at slot " .. tostring(slot) end
      if a.selected_item_id ~= item.id then
        return nil, "selected item mismatch: expected " .. tostring(item.id) .. ", got " .. tostring(a.selected_item_id)
      end
      if not item.name then return nil, "item has no name" end
      return true
    end,

    ["放大卡牌显示第<p4>格道具的描述"] = function(world, example)
      local slot = number_utils.to_integer(example.p4)
      if slot == nil then return nil, "invalid slot: " .. tostring(example.p4) end
      local item, a = _resolve_slot_item(world, slot)
      if not item then return nil, "no item at slot " .. tostring(slot) end
      if a.selected_item_id ~= item.id then
        return nil, "selected item mismatch: expected " .. tostring(item.id) .. ", got " .. tostring(a.selected_item_id)
      end
      if not item.description then return nil, "item has no description" end
      return true
    end,

    ["玩家点击空白区域关闭放大卡牌"] = function(world)
      item_atlas.handle_action(world.atlas_state, "dismiss", world.ui_role_id or 1)
      return true
    end,

    -- ── enlarged-card companion node visibility ───────────────────────────────
    ["图鉴关闭提示已展示"] = function(world)
      if world.atlas_visibility[item_atlas_nodes.close_hint_label] ~= true then
        return nil, "图鉴_点击关闭提示 should be visible"
      end
      return true
    end,

    ["图鉴关闭提示已隐藏"] = function(world)
      if world.atlas_visibility[item_atlas_nodes.close_hint_label] == true then
        return nil, "图鉴_点击关闭提示 should be hidden"
      end
      return true
    end,

    ["图鉴空白关闭层已展示"] = function(world)
      if world.atlas_visibility[item_atlas_nodes.close_blank] ~= true then
        return nil, "图鉴_点击空白关闭 should be visible"
      end
      return true
    end,

    ["图鉴空白关闭层已隐藏"] = function(world)
      if world.atlas_visibility[item_atlas_nodes.close_blank] == true then
        return nil, "图鉴_点击空白关闭 should be hidden"
      end
      return true
    end,

    ["图鉴静态文本未被改写"] = function(world)
      -- 节点名以 Data/UIManagerNodes.lua 为准: 底框_1 带下划线，底框2 不带
      local guarded = { "图鉴_图鉴文本", "图鉴_图鉴底框_1", "图鉴_图鉴底框2" }
      for _, node in ipairs(guarded) do
        if world.atlas_labels[node] ~= nil then
          return nil, node .. " 文字被改写为: " .. tostring(world.atlas_labels[node])
        end
      end
      return true
    end,

    -- ── prev/next arrow visibility (参考黑市 controls) ────────────────────────
    ["图鉴上一页箭头已展示"] = function(world)
      if world.atlas_visibility[item_atlas_nodes.page_prev] ~= true then
        return nil, "图鉴_上一页 should be visible"
      end
      return true
    end,

    ["图鉴上一页箭头已隐藏"] = function(world)
      if world.atlas_visibility[item_atlas_nodes.page_prev] == true then
        return nil, "图鉴_上一页 should be hidden"
      end
      return true
    end,

    ["图鉴下一页箭头已展示"] = function(world)
      if world.atlas_visibility[item_atlas_nodes.page_next] ~= true then
        return nil, "图鉴_下一页 should be visible"
      end
      return true
    end,

    ["图鉴下一页箭头已隐藏"] = function(world)
      if world.atlas_visibility[item_atlas_nodes.page_next] == true then
        return nil, "图鉴_下一页 should be hidden"
      end
      return true
    end,

    ["无道具被选中"] = function(world)
      local a = _atlas(world)
      if a and a.selected_item_id ~= nil then
        return nil, "expected no item selected, got " .. tostring(a.selected_item_id)
      end
      return true
    end,

    ["图鉴总页数为<p6>"] = function(world, example)
      local expected = number_utils.to_integer(example.p6)
      if expected == nil then return nil, "invalid total pages: " .. tostring(example.p6) end
      local catalog_size = #item_atlas.catalog
      local actual = math.max(1, math.floor((catalog_size + SLOTS_PER_PAGE - 1) / SLOTS_PER_PAGE))
      if actual ~= expected then
        return nil, "total pages mismatch: expected " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    -- ── pagination ────────────────────────────────────────────────────────────
    ["玩家翻到图鉴上一页"] = function(world)
      item_atlas.handle_action(world.atlas_state, "prev", world.ui_role_id or 1)
      return true
    end,

    ["玩家翻到图鉴下一页"] = function(world)
      item_atlas.handle_action(world.atlas_state, "next", world.ui_role_id or 1)
      return true
    end,

    ["当前图鉴页码为1"] = function(world)
      local atlas = _atlas(world)
      if atlas.page_index ~= 1 then
        return nil, "expected page 1, got " .. tostring(atlas.page_index)
      end
      return true
    end,

    ["当前图鉴页码为<p7>"] = function(world, example)
      local expected = number_utils.to_integer(example.p7)
      if expected == nil then return nil, "invalid page: " .. tostring(example.p7) end
      local atlas = _atlas(world)
      if atlas.page_index ~= expected then
        return nil, "expected page " .. tostring(expected) .. ", got " .. tostring(atlas.page_index)
      end
      return true
    end,

    -- ── render-layer card visibility (类比 skin shop 卡片渲染数) ─────────────
    ["图鉴卡片渲染数为<p8>个"] = function(world, example)
      local expected = number_utils.to_integer(example.p8)
      if expected == nil then return nil, "invalid render count: " .. tostring(example.p8) end
      local count = 0
      for slot = 1, SLOTS_PER_PAGE do
        if world.atlas_visibility[item_atlas_nodes.card_images[slot]] == true then
          count = count + 1
        end
      end
      if count ~= expected then
        return nil, "expected " .. tostring(expected) .. " visible cards, got " .. tostring(count)
      end
      return true
    end,

    -- ── 基础屏入口：模拟点击 -> 意图 -> dispatch -> 图鉴开启 ─────────────────
    ["触发基础屏图鉴按钮"] = function(world)
      _ensure_atlas_state(world)
      for _, spec in ipairs(base_intents.build(world.atlas_state)) do
        if spec.name == base_nodes.gallery_button then
          local intent = spec.build_intent()
          intent.actor_role_id = world.ui_role_id or 1
          view_command.dispatch(world.atlas_state, intent)
          return true
        end
      end
      return nil, "base canvas 未注册 gallery_button 路由"
    end,
  }
end

return item_atlas_steps
