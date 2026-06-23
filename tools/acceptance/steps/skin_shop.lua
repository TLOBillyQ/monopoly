local number_utils = require("src.foundation.number")
local skin_panel = require("src.ui.coord.skin_panel")
local skin_nodes = require("src.ui.schema.skin")
local view_command = require("src.ui.input.view_command")
local base_intents = require("src.ui.input.route_base")
local skin_intents = require("src.ui.input.route_skin_panel")
local base_nodes = require("src.ui.schema.base")
local ui_mock = require("tools.acceptance.support.ui_mock")

local skin_shop_steps = {}

local function _make_catalog(n)
  local t = {}
  for i = 1, n do
    t[i] = {
      product_id = "skin_" .. i,
      name = "皮肤" .. i,
      unlock = "purchase",
      currency = "金豆",
      price = 198,
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
    local state, captures = ui_mock.build_render_state({ with_buttons = true })
    world.skin_state = state
    world.skin_visibility = captures.visibility
    world.skin_labels = captures.labels
    world.skin_button_text = captures.button_text
    world.skin_button_touch = captures.button_touch
    world.skin_textures = captures.textures
    if not world.skin_catalog_injected then
      skin_panel.reset_for_tests()
    else
      -- Catalog was injected before _ensure_skin_state was first called; module
      -- callbacks may still hold over from a prior scenario in the same run
      -- (purchase_callback / equip_callback are module-level locals, not on
      -- the per-world state table). Clear them so each scenario boots with a
      -- clean callback slate while preserving the freshly-configured catalog.
      skin_panel.configure_purchase(nil)
      skin_panel.configure_equip(nil)
      skin_panel.configure_archive(nil)
    end
    _seed_image_refs(world.skin_state)
  end
  return world.skin_state
end

local SLOTS_PER_PAGE = skin_nodes.page_size

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

local function _assert_outline_container_count(world, raw_count)
  local expected = number_utils.to_integer(raw_count)
  if expected == nil then return nil, "invalid outline container count: " .. tostring(raw_count) end
  local count = 0
  for slot = 1, SLOTS_PER_PAGE do
    local outline = skin_nodes.card_outlines[slot]
    if not outline then
      return nil, "no outline node for slot " .. tostring(slot)
    end
    if world.skin_visibility[outline] == true then
      count = count + 1
    end
  end
  if count ~= expected then
    return nil, "expected " .. tostring(expected) .. " visible skin card outline containers, got " .. tostring(count)
  end
  return true
end

local function _assert_button_text(world, raw_slot, expected_value)
  local slot = number_utils.to_integer(raw_slot)
  if slot == nil then return nil, "invalid slot: " .. tostring(raw_slot) end
  local expected = tostring(expected_value or "")
  local button_name = skin_nodes.action_buttons[slot]
  if not button_name then return nil, "no button node for slot " .. tostring(slot) end
  local actual = world.skin_button_text[button_name]
  if actual ~= expected then
    return nil, "button text mismatch at slot " .. tostring(slot) ..
      ": expected '" .. expected .. "', got '" .. tostring(actual) .. "'"
  end
  return true
end

local function _parse_slot(example, field)
  local raw = example[field]
  local slot = number_utils.to_integer(raw)
  if slot == nil then
    return nil, "invalid slot: " .. tostring(raw)
  end
  return slot
end

local function _resolve_skin(world, example, field)
  local slot, err = _parse_slot(example, field)
  if slot == nil then
    return nil, nil, err
  end
  local skin = _skin_at_slot(world, slot)
  if not skin then
    return nil, nil, "no skin at slot " .. tostring(slot)
  end
  return skin, slot
end

-- Dual-role factory: Given/When (any non-Then keyword) pre-unlocks the slot
-- via skin_panel.unlock(..., "given", ...); Then asserts the role owns it.
local function _handler_owned_by(field)
  return function(world, example, step)
    local skin, slot, err = _resolve_skin(world, example, field)
    if not skin then return nil, err end
    local key = _role_key(world)
    local panel = _panel(world)
    if not (step and step.keyword == "Then") then
      skin_panel.unlock(world.skin_state, world.ui_role_id or 1, "given", slot)
    end
    if not (panel.owned_by_role[key] and panel.owned_by_role[key][skin.product_id]) then
      return nil, "skin at slot " .. tostring(slot) .. " is not owned by role " .. key
    end
    return true
  end
end

-- Assert-only ownership: never pre-unlocks; used by 验证槽位 doubling where
-- the step is always emitted under 并且 (And) after a Then assertion and 并且
-- normalizes to "And" regardless of context. _handler_owned_by would self-
-- fulfill the assertion via the Given-side pre-unlock branch.
local function _handler_assert_owned_by(field)
  return function(world, example)
    local skin, slot, err = _resolve_skin(world, example, field)
    if not skin then return nil, err end
    local key = _role_key(world)
    local panel = _panel(world)
    if not (panel.owned_by_role[key] and panel.owned_by_role[key][skin.product_id]) then
      return nil, "skin at slot " .. tostring(slot) .. " is not owned by role " .. key
    end
    return true
  end
end

local function _handler_equip_at(field)
  return function(world, example)
    local slot, err = _parse_slot(example, field)
    if slot == nil then return nil, err end
    skin_panel.equip(world.skin_state, world.ui_role_id or 1, slot)
    return true
  end
end

local function _handler_button_touchable(field, expect_touchable)
  return function(world, example)
    local slot, err = _parse_slot(example, field)
    if slot == nil then return nil, err end
    local button_name = skin_nodes.action_buttons[slot]
    if not button_name then return nil, "no button node for slot " .. tostring(slot) end
    if world.skin_button_touch[button_name] ~= expect_touchable then
      local want = expect_touchable and "touchable" or "non-touchable"
      return nil, "expected button at slot " .. tostring(slot) .. " to be " .. want ..
        ", got " .. tostring(world.skin_button_touch[button_name])
    end
    return true
  end
end

local function _handler_price_icon_visible(field, expect_visible)
  return function(world, example)
    local slot, err = _parse_slot(example, field)
    if slot == nil then return nil, err end
    local icon = skin_nodes.price_icons[slot]
    if not icon then return nil, "no price icon node for slot " .. tostring(slot) end
    local actual = world.skin_visibility[icon] == true
    if actual ~= expect_visible then
      local want = expect_visible and "visible" or "hidden"
      return nil, "expected price icon at slot " .. tostring(slot) .. " to be " .. want ..
        ", got " .. tostring(world.skin_visibility[icon])
    end
    return true
  end
end

-- Look up a catalog slot for in-place mutation. Returns the skin table so
-- callers can layer field changes inline; returns nil, err on bad slot.
local function _mutate_slot(example, field)
  local slot = number_utils.to_integer(example[field])
  if slot == nil then return nil, "invalid slot: " .. tostring(example[field]) end
  local skin = skin_panel.catalog[slot]
  if not skin then return nil, "no skin at slot " .. tostring(slot) end
  return skin
end

local function _mutate_fixed_slot(slot)
  local skin = skin_panel.catalog[slot]
  if not skin then return nil, "no skin at slot " .. tostring(slot) end
  return skin
end

local function _set_gift_unlock(skin, gift_name)
  skin.unlock = "gift"
  skin.gift_name = tostring(gift_name or "")
  skin.price = nil
  skin.currency = nil
end

local function _gift_unlock_handler(resolve_skin, resolve_gift_name)
  return function(_, example)
    local skin, err = resolve_skin(example)
    if not skin then return nil, err end
    _set_gift_unlock(skin, resolve_gift_name(example))
    return true
  end
end

local function _handler_gift_unlock(field)
  return _gift_unlock_handler(function(example)
    return _mutate_slot(example, field)
  end, function(example)
    return example["赠礼名"]
  end)
end

local function _handler_fixed_gift_unlock(slot)
  return _gift_unlock_handler(function()
    return _mutate_fixed_slot(slot)
  end, function(example)
    return example["赠礼名"]
  end)
end

local function _handler_fixed_gift_name(slot, gift_name)
  return _gift_unlock_handler(function()
    return _mutate_fixed_slot(slot)
  end, function()
    return gift_name
  end)
end

-- In-memory stand-in for the host skin archive. The backing store lives on the
-- world so it survives the panel/render-state rebuild done by 玩家重新开局, which
-- is what lets a second open() read purchased skins back.
local function _make_world_archive(world)
  world.skin_archive_store = world.skin_archive_store or { owned = {}, equipped = {} }
  local store = world.skin_archive_store
  return {
    mark_owned = function(role, product_id)
      store.owned[tostring(role)] = store.owned[tostring(role)] or {}
      store.owned[tostring(role)][product_id] = true
    end,
    load_owned = function(role)
      local out = {}
      for product_id in pairs(store.owned[tostring(role)] or {}) do
        out[#out + 1] = product_id
      end
      return out
    end,
    save_equipped = function(role, product_id)
      store.equipped[tostring(role)] = product_id
    end,
    load_equipped = function(role)
      return store.equipped[tostring(role)]
    end,
  }
end

-- Rebuild the render/panel state from scratch (a fresh game session) while
-- keeping the world-backed archive store, so seeding on open reads it back.
local function _rebuild_skin_state(world)
  local state, captures = ui_mock.build_render_state({ with_buttons = true })
  world.skin_state = state
  world.skin_visibility = captures.visibility
  world.skin_labels = captures.labels
  world.skin_button_text = captures.button_text
  world.skin_button_touch = captures.button_touch
  world.skin_textures = captures.textures
  _seed_image_refs(world.skin_state)
end

local function _handler_paid_purchase(field)
  return function(world, example)
    local slot, err = _parse_slot(example, field)
    if slot == nil then return nil, err end
    skin_panel.configure_archive(_make_world_archive(world))
    skin_panel.configure_purchase(function(_, _, on_success) on_success() end)
    skin_panel.equip(world.skin_state, world.ui_role_id or 1, slot)
    return true
  end
end

local function _register_purchase_spy(world, invoke_on_success)
  _ensure_skin_state(world)
  world.purchase_call_args = nil
  skin_panel.configure_purchase(function(role_id, skin, on_success)
    world.purchase_call_args = {
      role_id = role_id,
      skin = skin,
      on_success = on_success,
    }
    if invoke_on_success then on_success() end
  end)
end

function skin_shop_steps.handlers()
  return {
    -- ── shared across v102 features ──────────────────────────────────────────
    ["玩家角色ID为<角色ID>"] = function(world, example)
      local role_id = number_utils.to_integer(example["角色ID"])
      if role_id == nil then
        return nil, "invalid role_id: " .. tostring(example["角色ID"])
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
    ["皮肤目录共有<皮肤数>款皮肤"] = function(world, example)
      local n = number_utils.to_integer(example["皮肤数"])
      if n == nil then return nil, "invalid skin count: " .. tostring(example["皮肤数"]) end
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
    ["当前页面展示<槽位数>个皮肤槽位"] = function(world, example)
      local expected = number_utils.to_integer(example["槽位数"])
      if expected == nil then return nil, "invalid slot count: " .. tostring(example["槽位数"]) end
      local count = 0
      for i = 1, SLOTS_PER_PAGE do
        if _skin_at_slot(world, i) then count = count + 1 end
      end
      if count ~= expected then
        return nil, "expected " .. tostring(expected) .. " slots, got " .. tostring(count)
      end
      return true
    end,

    ["槽位<槽位>在皮肤卡牌可见槽位范围内"] = function(_, example)
      local slot = number_utils.to_integer(example["槽位"])
      if slot == nil then return nil, "invalid slot: " .. tostring(example["槽位"]) end
      if slot < 1 or slot > SLOTS_PER_PAGE then
        return nil, "slot " .. tostring(slot) .. " is outside visible skin slots"
      end
      return true
    end,

    -- ── unlock / equip ────────────────────────────────────────────────────────
    ["槽位<槽位>的皮肤尚未解锁"] = function(world, example)
      local skin, slot, err = _resolve_skin(world, example, "槽位")
      if not skin then return nil, err end
      local key = _role_key(world)
      local panel = _panel(world)
      if panel.owned_by_role[key] and panel.owned_by_role[key][skin.product_id] then
        return nil, "skin at slot " .. tostring(slot) .. " is already owned by role " .. key
      end
      return true
    end,

    ["玩家购买槽位<槽位>的皮肤"] = function(world, example)
      local slot, err = _parse_slot(example, "槽位")
      if slot == nil then return nil, err end
      skin_panel.unlock(world.skin_state, world.ui_role_id or 1, "buy", slot)
      return true
    end,

    -- Dual-role: Given = precondition (pre-unlock), Then = assertion
    ["槽位<槽位>的皮肤已归玩家持有"] = _handler_owned_by("槽位"),

    ["玩家穿上槽位<槽位>的皮肤"] = _handler_equip_at("槽位"),

    ["槽位<槽位>的皮肤已装备成功"] = function(world, example)
      local skin, slot, err = _resolve_skin(world, example, "槽位")
      if not skin then return nil, err end
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
    ["玩家通过赠礼解锁槽位<槽位>的皮肤"] = function(world, example)
      local slot, err = _parse_slot(example, "槽位")
      if slot == nil then return nil, err end
      skin_panel.unlock(world.skin_state, world.ui_role_id or 1, "gift", slot)
      return true
    end,

    -- ── purchase archive / persistence ────────────────────────────────────────
    -- Real paid path: a purchase callback that "succeeds" immediately drives
    -- _initiate_purchase -> on_success -> _unlock_skin(.,"purchase") (mark_owned)
    -- and the auto-equip that persists the equipped product. Registered for both
    -- 槽位 and 占用槽位 phrasings used in the persistence scenarios.
    ["玩家付费购买槽位<槽位>的皮肤"] = _handler_paid_purchase("槽位"),
    ["玩家付费购买槽位<占用槽位>的皮肤"] = _handler_paid_purchase("占用槽位"),

    ["玩家重新开局并打开皮肤商店"] = function(world)
      _rebuild_skin_state(world)
      skin_panel.configure_archive(_make_world_archive(world))
      skin_panel.open(world.skin_state, world.ui_role_id or 1)
      return true
    end,

    ["换装回调已注册"] = function(world)
      world.equip_callback_product = nil
      skin_panel.configure_equip(function(_, skin)
        world.equip_callback_product = skin and skin.product_id
        return true
      end)
      return true
    end,

    ["换装回调收到的皮肤产品ID为<产品ID>"] = function(world, example)
      local expected = example["产品ID"]
      if world.equip_callback_product ~= expected then
        return nil, "expected equip callback product " .. tostring(expected) ..
          ", got " .. tostring(world.equip_callback_product)
      end
      return true
    end,

    -- ── unequip ──────────────────────────────────────────────────────────────
    ["脱下回调已注册"] = function(world)
      world.unequip_callback_role = nil
      skin_panel.configure_unequip(function(role_id)
        world.unequip_callback_role = role_id
      end)
      return true
    end,

    ["脱下回调收到的角色ID为<角色ID>"] = function(world, example)
      local expected = number_utils.to_integer(example["角色ID"])
      if expected == nil then return nil, "invalid role id: " .. tostring(example["角色ID"]) end
      if world.unequip_callback_role ~= expected then
        return nil, "expected unequip callback role " .. tostring(expected) ..
          ", got " .. tostring(world.unequip_callback_role)
      end
      return true
    end,

    ["玩家脱下当前皮肤"] = function(world)
      skin_panel.handle_action(world.skin_state, "unequip", world.ui_role_id or 1)
      return true
    end,

    -- 真实点击路径：模拟点击槽位动作按钮 -> 皮肤面板路由意图 -> dispatch。
    -- 与 _handler_equip_at 的 coord 直调不同，这里走 canvas_route -> view_command，
    -- 反映玩家在已装备槽位上点"脱下"按钮时实际派发的意图。
    ["玩家点击槽位<槽位>的皮肤动作按钮"] = function(world, example)
      local slot, err = _parse_slot(example, "槽位")
      if slot == nil then return nil, err end
      local button_name = skin_nodes.action_buttons[slot]
      if not button_name then return nil, "no action button node for slot " .. tostring(slot) end
      for _, spec in ipairs(skin_intents.build(world.skin_state)) do
        if spec.name == button_name then
          local intent = spec.build_intent()
          intent.actor_role_id = world.ui_role_id or 1
          view_command.dispatch(world.skin_state, intent)
          return true
        end
      end
      return nil, "skin canvas 未注册槽位动作按钮路由: " .. tostring(button_name)
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

    ["当前皮肤页码为<页码>"] = function(world, example)
      local expected = number_utils.to_integer(example["页码"])
      if expected == nil then return nil, "invalid page: " .. tostring(example["页码"]) end
      local panel = _panel(world)
      if panel.page_index ~= expected then
        return nil, "expected page " .. tostring(expected) .. ", got " .. tostring(panel.page_index)
      end
      return true
    end,

    -- ── render-layer card visibility (参考 图鉴 _refresh_card) ─────────────────
    ["皮肤卡片渲染数为<卡片渲染数>个"] = function(world, example)
      local expected = number_utils.to_integer(example["卡片渲染数"])
      if expected == nil then return nil, "invalid render count: " .. tostring(example["卡片渲染数"]) end
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

    ["皮肤卡牌槽位容器展示数为<容器数>个"] = function(world, example)
      return _assert_outline_container_count(world, example["容器数"])
    end,

    ["皮肤总页数为<总页数>"] = function(world, example)
      local expected = number_utils.to_integer(example["总页数"])
      if expected == nil then return nil, "invalid total pages: " .. tostring(example["总页数"]) end
      local actual = number_utils.page_count(#skin_panel.catalog, SLOTS_PER_PAGE)
      if actual ~= expected then
        return nil, "total pages mismatch: expected " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["皮肤目录末页展示<末页槽位数>个皮肤槽位"] = function(_, example)
      local expected = number_utils.to_integer(example["末页槽位数"])
      if expected == nil then return nil, "invalid last page slot count: " .. tostring(example["末页槽位数"]) end
      local catalog_size = #skin_panel.catalog
      local remainder = catalog_size % SLOTS_PER_PAGE
      local actual = remainder == 0 and math.min(catalog_size, SLOTS_PER_PAGE) or remainder
      if actual ~= expected then
        return nil, "last page slot count mismatch: expected " .. tostring(expected) .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["皮肤商店打开角色ID为<验证角色ID>"] = function(world, example)
      local expected = number_utils.to_integer(example["验证角色ID"])
      if expected == nil then return nil, "invalid 验证角色ID: " .. tostring(example["验证角色ID"]) end
      local panel = _panel(world)
      if panel.role_id ~= expected then
        return nil, "expected skin panel role_id=" .. tostring(expected) .. ", got " .. tostring(panel.role_id)
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

    -- ── card texture binding (parallel to atlas) ──────────────────────────────
    ["皮肤卡牌槽位<槽位>当前贴图为皮肤<皮肤ID>的图"] = function(world, example)
      local slot, err = _parse_slot(example, "槽位")
      if slot == nil then return nil, err end
      local product_id = tostring(example["皮肤ID"] or "")
      local card_name = skin_nodes.card_images[slot]
      if not card_name then return nil, "no card node for slot " .. tostring(slot) end
      local expected_key = "tex_" .. product_id
      local actual = world.skin_textures[card_name]
      if actual ~= expected_key then
        return nil, "slot " .. tostring(slot) .. " texture mismatch: expected " ..
          expected_key .. ", got " .. tostring(actual)
      end
      return true
    end,

    ["槽位<槽位>对应皮肤产品ID为<产品ID>"] = function(world, example)
      local skin, slot, err = _resolve_skin(world, example, "槽位")
      if not skin then return nil, err end
      local expected = tostring(example["产品ID"] or "")
      if tostring(skin.product_id) ~= expected then
        return nil, "slot " .. tostring(slot) .. " product mismatch: expected "
          .. expected .. ", got " .. tostring(skin.product_id)
      end
      return true
    end,

    -- ── dual-role variants for 旧槽位/新槽位 ─────────────────────────────────
    ["槽位<旧槽位>的皮肤已归玩家持有"] = _handler_owned_by("旧槽位"),

    ["槽位<新槽位>的皮肤已归玩家持有"] = _handler_owned_by("新槽位"),

    ["玩家穿上槽位<旧槽位>的皮肤"] = _handler_equip_at("旧槽位"),

    ["玩家穿上槽位<新槽位>的皮肤"] = _handler_equip_at("新槽位"),

    -- ── 验证槽位 / 验证新槽位 double-up variants (kills Examples-cell slot
    --     mutations by pinning the assertion to a hardcoded column) ─────────
    -- 验证槽位 is always assert-only: the step appears under 并且 (And) which
    -- normalizes regardless of preceding Then context, so the dual-role
    -- factory would self-fulfill via its Given-side pre-unlock branch.
    ["槽位<验证槽位>的皮肤已归玩家持有"] = _handler_assert_owned_by("验证槽位"),

    ["槽位<验证槽位>的皮肤已装备成功"] = function(world, example)
      local skin, slot, err = _resolve_skin(world, example, "验证槽位")
      if not skin then return nil, err end
      local key = _role_key(world)
      local panel = _panel(world)
      if panel.selected_by_role[key] ~= skin.product_id then
        return nil, "slot " .. tostring(slot) .. " skin not equipped; selected=" .. tostring(panel.selected_by_role[key])
      end
      return true
    end,

    ["槽位<验证槽位>的皮肤尚未解锁"] = function(world, example)
      local skin, slot, err = _resolve_skin(world, example, "验证槽位")
      if not skin then return nil, err end
      local key = _role_key(world)
      local panel = _panel(world)
      if panel.owned_by_role[key] and panel.owned_by_role[key][skin.product_id] then
        return nil, "skin at slot " .. tostring(slot) .. " is already owned by role " .. key
      end
      return true
    end,

    -- ── button state assertions ─────────────────────────────────────────────
    ["皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\""] = function(world, example)
      return _assert_button_text(world, example["槽位"], example["按钮文本"])
    end,

    ["皮肤卡牌槽位<槽位>按钮文本为\"<赠礼名>\""] = function(world, example)
      return _assert_button_text(world, example["槽位"], example["赠礼名"])
    end,

    ["皮肤卡牌槽位<验证槽位>按钮文本为\"<按钮文本>\""] = function(world, example)
      return _assert_button_text(world, example["验证槽位"], example["按钮文本"])
    end,

    ["皮肤卡牌槽位<验证槽位>按钮文本为\"<赠礼名>\""] = function(world, example)
      return _assert_button_text(world, example["验证槽位"], example["赠礼名"])
    end,

    ["皮肤卡牌槽位<槽位>按钮可点"] = _handler_button_touchable("槽位", true),
    ["皮肤卡牌槽位<槽位>按钮不可点"] = _handler_button_touchable("槽位", false),
    ["皮肤卡牌槽位<验证槽位>按钮可点"] = _handler_button_touchable("验证槽位", true),
    ["皮肤卡牌槽位<验证槽位>按钮不可点"] = _handler_button_touchable("验证槽位", false),

    -- ── catalog mutations (run before open; for L111 price-icon closure) ───
    ["槽位<槽位>的皮肤改为赠礼解锁并清空价格设赠礼名为\"<赠礼名>\""] = _handler_gift_unlock("槽位"),

    -- Backward-compatible aliases for older feature wording and the hardcoded
    -- control slots used by the purchase-vs-gift button-state scenario.
    ["槽位<槽位>的皮肤改为赠礼解锁并设赠礼名为\"<赠礼名>\""] = _handler_gift_unlock("槽位"),
    ["槽位3的皮肤改为赠礼解锁并设赠礼名为\"<赠礼名>\""] = _handler_fixed_gift_unlock(3),
    ["槽位4的皮肤改为赠礼解锁并设赠礼名为\"<赠礼名>\""] = _handler_fixed_gift_unlock(4),
    ["槽位3的皮肤改为赠礼解锁并设赠礼名为\"占位赠礼\""] = _handler_fixed_gift_name(3, "占位赠礼"),
    ["槽位4的皮肤改为赠礼解锁并设赠礼名为\"占位赠礼\""] = _handler_fixed_gift_name(4, "占位赠礼"),

    -- M1 mutation seed: gift unlock + price/currency intact, asserting the
    -- purchase-button branch gates on unlock, not just price fields.
    ["槽位<槽位>的皮肤改为赠礼解锁但保留价格设赠礼名为\"<赠礼名>\""] = function(_, example)
      local skin, err = _mutate_slot(example, "槽位")
      if not skin then return nil, err end
      skin.unlock = "gift"
      skin.gift_name = tostring(example["赠礼名"] or "")
      return true
    end,

    -- M2 mutation seed: purchase + price=nil (asserts L111 first `and` clause).
    ["槽位<槽位>的皮肤保持购买解锁但清空价格字段"] = function(_, example)
      local skin, err = _mutate_slot(example, "槽位")
      if not skin then return nil, err end
      skin.price = nil
      return true
    end,

    -- M2 symmetric: purchase + currency=nil (asserts L111 second `and` clause).
    ["槽位<槽位>的皮肤保持购买解锁但清空货币字段"] = function(_, example)
      local skin, err = _mutate_slot(example, "槽位")
      if not skin then return nil, err end
      skin.currency = nil
      return true
    end,

    -- ── purchase callback wiring (test-side spy, no production capture mode) ──
    ["购买回调已注册"] = function(world)
      _register_purchase_spy(world, false)
      return true
    end,

    ["购买回调注册为成功回调"] = function(world)
      _register_purchase_spy(world, true)
      return true
    end,

    ["购买回调收到的角色ID为<角色ID>"] = function(world, example)
      local expected = number_utils.to_integer(example["角色ID"])
      if expected == nil then return nil, "invalid role_id: " .. tostring(example["角色ID"]) end
      if not world.purchase_call_args then
        return nil, "purchase callback was not invoked"
      end
      if world.purchase_call_args.role_id ~= expected then
        return nil, "expected role_id " .. tostring(expected) ..
          ", got " .. tostring(world.purchase_call_args.role_id)
      end
      return true
    end,

    ["购买回调收到的皮肤产品ID为<产品ID>"] = function(world, example)
      local expected = tostring(example["产品ID"] or "")
      if not world.purchase_call_args then
        return nil, "purchase callback was not invoked"
      end
      local skin = world.purchase_call_args.skin
      if not skin then
        return nil, "purchase callback received nil skin"
      end
      if tostring(skin.product_id) ~= expected then
        return nil, "expected product_id '" .. expected ..
          "', got '" .. tostring(skin.product_id) .. "'"
      end
      return true
    end,

    -- ── price icon visibility by unlock type ────────────────────────────────
    ["皮肤卡牌槽位<购买槽位>价格图标已展示"] = _handler_price_icon_visible("购买槽位", true),
    ["皮肤卡牌槽位<槽位>价格图标已隐藏"] = _handler_price_icon_visible("槽位", false),
    ["皮肤卡牌槽位<验证槽位>价格图标已隐藏"] = _handler_price_icon_visible("验证槽位", false),

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
