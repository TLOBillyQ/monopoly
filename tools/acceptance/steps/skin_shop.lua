local number_utils = require("src.foundation.number")
local skin_panel = require("src.ui.coord.skin_panel")
local skin_nodes = require("src.ui.schema.skin")
local view_command = require("src.ui.input.dispatch.view_command")
local base_intents = require("src.ui.input.canvas_route.base")
local base_nodes = require("src.ui.schema.base")

local skin_shop_steps = {}

local function _make_catalog(n)
  local t = {}
  for i = 1, n do
    t[i] = {
      product_id = "skin_" .. i,
      name = "皮肤" .. i,
      unlock = "purchase",
      currency = "金豆",
      price = 100,
    }
  end
  return t
end

local function _seed_image_refs(state)
  for _, skin in ipairs(skin_panel.catalog or {}) do
    state.ui_refs.images[tostring(skin.product_id)] = "tex_" .. tostring(skin.product_id)
  end
end

local function _ensure_skin_state(world)
  if not world.skin_state then
    local visibility = {}
    local labels = {}
    world.skin_state = {
      ui = {
        set_visible = function(_, name, visible)
          visibility[name] = visible == true
        end,
        set_label = function(_, name, text)
          labels[name] = text
        end,
        set_button = function(_, _, _) end,
        set_touch_enabled = function(_, _, _) end,
      },
      ui_refs = { images = {} },
    }
    world.skin_visibility = visibility
    world.skin_labels = labels
    if not world.skin_catalog_injected then
      skin_panel.reset_for_tests()
    end
    _seed_image_refs(world.skin_state)
  end
  return world.skin_state
end

local SLOTS_PER_PAGE = 6

local function _panel(world)
  if not world.skin_state then return nil end
  return world.skin_state.ui.skin_panel
end

local function _role_key(world)
  return tostring(world.ui_role_id or 1)
end

local function _skin_at_slot(world, slot)
  local panel = _panel(world)
  local idx = (panel.page_index - 1) * SLOTS_PER_PAGE + slot
  return skin_panel.catalog[idx]
end

function skin_shop_steps.handlers()
  return {
    -- ── shared across v102 features ──────────────────────────────────────────
    ["玩家角色ID为<p1>"] = function(world, example)
      local role_id = number_utils.to_integer(example.p1)
      if role_id == nil then
        return nil, "invalid role_id: " .. tostring(example.p1)
      end
      if world.driver then
        local player = world.driver.game.players[role_id]
        if not player then
          return nil, "no player at role_id " .. tostring(role_id)
        end
        -- only human player slots (P1/P2) are valid scenario actors
        if role_id < 1 or role_id > 2 then
          return nil, "role_id must be 1 or 2 in feature scenarios, got " .. tostring(role_id)
        end
        world.market_player = player
      end
      world.ui_role_id = role_id
      return true
    end,

    -- ── skin_shop catalog injection ───────────────────────────────────────────
    ["皮肤目录共有<p2>款皮肤"] = function(world, example)
      local n = number_utils.to_integer(example.p2)
      if n == nil then return nil, "invalid skin count: " .. tostring(example.p2) end
      skin_panel.configure_catalog_for_tests(_make_catalog(n))
      world.skin_catalog_injected = true
      return true
    end,

    -- ── open / close ─────────────────────────────────────────────────────────
    ["玩家打开皮肤商店"] = function(world)
      _ensure_skin_state(world)
      skin_panel.open(world.skin_state, world.ui_role_id or 1)
      return true
    end,

    ["玩家关闭皮肤商店"] = function(world)
      _ensure_skin_state(world)
      skin_panel.close(world.skin_state)
      return true
    end,

    ["皮肤商店屏幕已开启"] = function(world)
      local p = _panel(world)
      if not (p and p.open) then
        return nil, "skin panel is not open"
      end
      return true
    end,

    ["皮肤商店屏幕已关闭"] = function(world)
      local p = _panel(world)
      if p and p.open then
        return nil, "skin panel is still open"
      end
      return true
    end,

    -- ── slot count assertion ──────────────────────────────────────────────────
    ["当前页面展示<p3>个皮肤槽位"] = function(world, example)
      local expected = number_utils.to_integer(example.p3)
      if expected == nil then return nil, "invalid slot count: " .. tostring(example.p3) end
      local count = 0
      for i = 1, SLOTS_PER_PAGE do
        if _skin_at_slot(world, i) then count = count + 1 end
      end
      if count ~= expected then
        return nil, "expected " .. tostring(expected) .. " slots, got " .. tostring(count)
      end
      return true
    end,

    -- ── unlock / equip ────────────────────────────────────────────────────────
    ["槽位<p4>的皮肤尚未解锁"] = function(world, example)
      local slot = number_utils.to_integer(example.p4)
      if slot == nil then return nil, "invalid slot: " .. tostring(example.p4) end
      local skin = _skin_at_slot(world, slot)
      if not skin then return nil, "no skin at slot " .. tostring(slot) end
      local key = _role_key(world)
      local panel = _panel(world)
      if panel.owned_by_role[key] and panel.owned_by_role[key][skin.product_id] then
        return nil, "skin at slot " .. tostring(slot) .. " is already owned by role " .. key
      end
      return true
    end,

    ["玩家购买槽位<p4>的皮肤"] = function(world, example)
      local slot = number_utils.to_integer(example.p4)
      if slot == nil then return nil, "invalid slot: " .. tostring(example.p4) end
      skin_panel.unlock(world.skin_state, world.ui_role_id or 1, "buy", slot)
      return true
    end,

    -- Dual-role: Given = precondition (pre-unlock), Then = assertion
    ["槽位<p4>的皮肤已归玩家持有"] = function(world, example, step)
      local slot = number_utils.to_integer(example.p4)
      if slot == nil then return nil, "invalid slot: " .. tostring(example.p4) end
      local skin = _skin_at_slot(world, slot)
      if not skin then return nil, "no skin at slot " .. tostring(slot) end
      local key = _role_key(world)
      local panel = _panel(world)
      local is_then = step and step.keyword == "Then"
      if not is_then then
        skin_panel.unlock(world.skin_state, world.ui_role_id or 1, "given", slot)
      end
      if not (panel.owned_by_role[key] and panel.owned_by_role[key][skin.product_id]) then
        return nil, "skin at slot " .. tostring(slot) .. " is not owned by role " .. key
      end
      return true
    end,

    ["玩家穿上槽位<p4>的皮肤"] = function(world, example)
      local slot = number_utils.to_integer(example.p4)
      if slot == nil then return nil, "invalid slot: " .. tostring(example.p4) end
      skin_panel.equip(world.skin_state, world.ui_role_id or 1, slot)
      return true
    end,

    ["槽位<p4>的皮肤已装备成功"] = function(world, example)
      local slot = number_utils.to_integer(example.p4)
      if slot == nil then return nil, "invalid slot: " .. tostring(example.p4) end
      local skin = _skin_at_slot(world, slot)
      if not skin then return nil, "no skin at slot " .. tostring(slot) end
      local key = _role_key(world)
      local panel = _panel(world)
      if panel.selected_by_role[key] ~= skin.product_id then
        return nil, "slot " .. tostring(slot) .. " skin not equipped; selected=" .. tostring(panel.selected_by_role[key])
      end
      return true
    end,

    ["皮肤未成功装备"] = function(world)
      local key = _role_key(world)
      local panel = _panel(world)
      if panel.selected_by_role[key] ~= nil then
        return nil, "skin was equipped unexpectedly: " .. tostring(panel.selected_by_role[key])
      end
      return true
    end,

    -- ── gift unlock ──────────────────────────────────────────────────────────
    ["玩家通过赠礼解锁槽位<p4>的皮肤"] = function(world, example)
      local slot = number_utils.to_integer(example.p4)
      if slot == nil then return nil, "invalid slot: " .. tostring(example.p4) end
      skin_panel.unlock(world.skin_state, world.ui_role_id or 1, "gift", slot)
      return true
    end,

    -- ── unequip ──────────────────────────────────────────────────────────────
    ["玩家脱下当前皮肤"] = function(world)
      skin_panel.handle_action(world.skin_state, "unequip", world.ui_role_id or 1)
      return true
    end,

    ["无皮肤装备中"] = function(world)
      local key = _role_key(world)
      local panel = _panel(world)
      if panel.selected_by_role[key] ~= nil then
        return nil, "expected no skin equipped, got " .. tostring(panel.selected_by_role[key])
      end
      return true
    end,

    -- ── pagination ───────────────────────────────────────────────────────────
    ["玩家翻到皮肤下一页"] = function(world)
      skin_panel.handle_action(world.skin_state, "next", world.ui_role_id or 1)
      return true
    end,

    ["玩家翻到皮肤上一页"] = function(world)
      skin_panel.handle_action(world.skin_state, "prev", world.ui_role_id or 1)
      return true
    end,

    ["当前皮肤页码为1"] = function(world)
      local panel = _panel(world)
      if panel.page_index ~= 1 then
        return nil, "expected page 1, got " .. tostring(panel.page_index)
      end
      return true
    end,

    ["当前皮肤页码为<p5>"] = function(world, example)
      local expected = number_utils.to_integer(example.p5)
      if expected == nil then return nil, "invalid page: " .. tostring(example.p5) end
      local panel = _panel(world)
      if panel.page_index ~= expected then
        return nil, "expected page " .. tostring(expected) .. ", got " .. tostring(panel.page_index)
      end
      return true
    end,

    -- ── render-layer card visibility (参考 图鉴 _refresh_card) ─────────────────
    ["皮肤卡片渲染数为<p6>个"] = function(world, example)
      local expected = number_utils.to_integer(example.p6)
      if expected == nil then return nil, "invalid render count: " .. tostring(example.p6) end
      local count = 0
      for slot = 1, SLOTS_PER_PAGE do
        if world.skin_visibility[skin_nodes.card_images[slot]] == true then
          count = count + 1
        end
      end
      if count ~= expected then
        return nil, "expected " .. tostring(expected) .. " visible cards, got " .. tostring(count)
      end
      return true
    end,

    ["皮肤静态文本未被改写"] = function(world)
      local guarded = { "皮肤_皮肤商店文本", "皮肤_皮肤商店底框", "皮肤_皮肤商店底框2" }
      for _, node in ipairs(guarded) do
        if world.skin_labels[node] ~= nil then
          return nil, node .. " 文字被改写为: " .. tostring(world.skin_labels[node])
        end
      end
      return true
    end,

    -- ── 基础屏入口：模拟点击 -> 意图 -> dispatch -> 商店开启 ─────────────────
    ["触发基础屏皮肤按钮"] = function(world)
      _ensure_skin_state(world)
      for _, spec in ipairs(base_intents.build(world.skin_state)) do
        if spec.name == base_nodes.skin_button then
          local intent = spec.build_intent()
          intent.actor_role_id = world.ui_role_id or 1
          view_command.dispatch(world.skin_state, intent)
          return true
        end
      end
      return nil, "base canvas 未注册 skin_button 路由"
    end,
  }
end

return skin_shop_steps
