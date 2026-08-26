local dsl = require("packages.acceptance.step_dsl")
local number_utils = require("src.foundation.number")
local transaction = require("src.app.cosmetics.transaction")
local skin_panel = require("src.ui.screens.skin_panel")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local skin_nodes = require("src.ui.schema.skin")
local view_command = require("src.ui.input.view_command")
local base_intents = require("src.ui.input.route_base")
local base_nodes = require("src.ui.schema.base")
local ui_mock = require("packages.acceptance.support.ui_mock")

-- 皮肤商店域绑定：服务 skin_shop / skin_persistence。渲染态走 ui_mock，付费购买走
-- src.rules.ports.paid_purchase 假网关（fulfill 时同步跑 entry.on_purchase() 镜像宿主回调），
-- 存档走 world 级 in-memory archive（挂 world 上，跨「重新开局」存活）。

local SLOTS = skin_nodes.page_size

local function _make_catalog(n)
  local catalog = {}
  for i = 1, n do catalog[i] = { product_id = "skin_" .. tostring(i), name = "皮肤" .. tostring(i), unlock = "purchase", currency = "金豆", price = 198 } end
  return catalog
end

local function _seed_images(state)
  for _, skin in ipairs(skin_panel.catalog or {}) do
    state.runtime_asset_context.refs.images[tostring(skin.product_id)] = "tex_" .. tostring(skin.product_id)
  end
end

-- 付费路径经 state.game:find_player_by_id 解析买家；绑捕获表并补最小 game。
local function _bind_state(world)
  local state, captures = ui_mock.build_render_state({ with_buttons = true })
  state.game = { find_player_by_id = function(_, role_id) return { id = role_id } end }
  world.skin_state, world.skin_visibility, world.skin_labels = state, captures.visibility, captures.labels
  world.skin_button_text, world.skin_button_touch, world.skin_textures = captures.button_text, captures.button_touch, captures.textures
  _seed_images(state)
  return state
end

local function _configure_gateway(world, fulfill)
  paid_purchase_port.reset_for_tests()
  paid_purchase_port.configure({
    setup_for_game = function() end,
    can_start = function() return true end,
    start = function(_, player, entry)
      world.purchase_call_args = { role_id = player and player.id or nil, skin = entry, on_success = entry and entry.on_purchase or nil }
      if fulfill and entry and type(entry.on_purchase) == "function" then entry.on_purchase() end
      return true
    end,
  })
end

local function _ensure_state(world)
  if not world.skin_state then
    _bind_state(world)
    paid_purchase_port.reset_for_tests()
    if not world.skin_catalog_injected then skin_panel.reset_for_tests()
    else skin_panel.configure_equip(nil) skin_panel.configure_archive(nil) end -- 目录先注入时只清模块级回调
    _seed_images(world.skin_state)
  end
  return world.skin_state
end

local function _role(w) return number_utils.to_integer(w.ui_role_id) or 1 end
local function _panel(w) return w.skin_state and w.skin_state.ui.skin_panel or nil end
local function _view(w, slot) return w.skin_state and transaction.slot_view_model(w.skin_state, slot) or nil end
local function _equipped(w) return transaction.equipped_product(w.skin_state, _role(w)) end
local function _owned(view) return view ~= nil and (view.status == "owned" or view.status == "equipped") end

local function _skin_at(w, slot)
  local view = _view(w, slot)
  if view and view.skin then return view.skin end
  local panel = _panel(w)
  return skin_panel.catalog[((panel and panel.page_index or 1) - 1) * SLOTS + slot]
end

-- world 级存档替身：跨重开局存活。
local function _archive(world)
  world.skin_archive_store = world.skin_archive_store or { owned = {}, equipped = {} }
  local store = world.skin_archive_store
  return {
    mark_owned = function(role, pid) store.owned[tostring(role)] = store.owned[tostring(role)] or {} store.owned[tostring(role)][pid] = true end,
    load_owned = function(role)
      local out = {}
      for pid in pairs(store.owned[tostring(role)] or {}) do out[#out + 1] = pid end
      return out
    end,
    save_equipped = function(role, pid) store.equipped[tostring(role)] = pid end,
    load_equipped = function(role) return store.equipped[tostring(role)] end,
  }
end

-- 双相句面：Given/When 侧先 unlock 预置，Then 侧纯断言（验证槽位恒断言——并且 归一为
-- And，双相工厂会经 Given 分支自证，故按占位名拆句面注册，#132）。
local function _owned_step(field, assert_only)
  return function(w, a, step)
    local slot = a[field]
    if not _skin_at(w, slot) then return nil, "no skin at slot " .. tostring(slot) end
    if not assert_only and not (step and step.keyword == "Then") then skin_panel.unlock(w.skin_state, _role(w), "given", slot) end
    return dsl.truthy(_owned(_view(w, slot)), "槽位" .. tostring(slot) .. " 归角色" .. tostring(_role(w)) .. "持有")
  end
end

-- 槽位节点断言工厂：nodes[槽位] 缺失即报错，否则交 check。
-- <槽位> 是规范 slot key：<清空槽位>/<断言槽位>/<验证槽位> 等步骤占位符由
-- acceptance runtime 的 shape 分派绑定到 handler 声明的 <槽位>，下方直接读
-- a["槽位"] 的 handler 同理，无需别名 handler 或 or 回退（#515/#516）。
local function _node_step(nodes, check)
  return function(w, a)
    local node = nodes[a["槽位"]]
    if not node then return nil, "no node for slot " .. tostring(a["槽位"]) end
    return check(w, a, node)
  end
end

local function _count_visible(w, nodes)
  local count = 0
  for slot = 1, SLOTS do
    if w.skin_visibility[nodes[slot]] == true then count = count + 1 end
  end
  return count
end

local function _catalog_mutation(field)
  return function(_, a)
    local slot = a["槽位"]
    local skin = skin_panel.catalog[slot]
    if not skin then return nil, "no skin at slot " .. tostring(slot) end
    skin[field] = nil
    return true
  end
end

local function _dispatch_route(world, specs, target)
  for _, spec in ipairs(specs) do
    if spec.name == target then
      local intent = spec.build_intent()
      intent.actor_role_id = _role(world)
      view_command.dispatch(world.skin_state, intent)
      return true
    end
  end
  return nil, "canvas 未注册路由: " .. tostring(target)
end

return dsl.steps({
  ["皮肤目录共有<皮肤数:int>款皮肤"] = function(w, a)
    skin_panel.configure_catalog_for_tests(_make_catalog(a["皮肤数"]))
    w.skin_catalog_injected = true
    return true
  end,
  -- 排序场景注入：按给定价格序列造目录，product_id 依注入序编 skin_1..skin_N。
  -- 非大纲场景，价格序列是字面值，用 {价格序列} 内联捕获（非 <> 大纲占位符）。
  ['皮肤目录注入价格序列"{价格序列}"'] = function(w, a)
    local catalog = {}
    local index = 0
    for token in string.gmatch(a["价格序列"], "[^,]+") do
      index = index + 1
      catalog[index] = { product_id = "skin_" .. tostring(index), name = "皮肤" .. tostring(index), unlock = "purchase", currency = "金豆", price = number_utils.to_integer(token) }
    end
    if index == 0 then return nil, "价格序列为空" end
    skin_panel.configure_catalog_for_tests(catalog)
    w.skin_catalog_injected = true
    return true
  end,
  -- 跨簇共享句面（skin_shop / market_cash 复用）：断言当前观察角色。
  ["当前角色ID为<验证角色ID:int>"] = function(w, a) return dsl.eq(w.ui_role_id, a["验证角色ID"], "ui_role_id") end,
  -- ── 开关 / 入口 ────────────────────────────────────────────────────
  ["玩家打开皮肤商店"] = function(w) skin_panel.open(_ensure_state(w), _role(w)) return true end,
  ["玩家关闭皮肤商店"] = function(w) skin_panel.close(_ensure_state(w)) return true end,
  ["皮肤商店屏幕已开启"] = function(w) local p = _panel(w) return dsl.truthy(p and p.open, "皮肤商店开启") end,
  ["皮肤商店屏幕已关闭"] = function(w) local p = _panel(w) return dsl.truthy(not (p and p.open), "皮肤商店关闭") end,
  ["触发基础屏皮肤按钮"] = function(w) return _dispatch_route(w, base_intents.build(_ensure_state(w)), base_nodes.skin_button) end,
  -- ── 槽位 / 翻页 ────────────────────────────────────────────────────
  ["当前页面展示<槽位数:int>个皮肤槽位"] = function(w, a)
    local count = 0
    for slot = 1, SLOTS do
      if _skin_at(w, slot) then count = count + 1 end
    end
    return dsl.eq(count, a["槽位数"], "当前页槽位数")
  end,
  ["槽位<槽位:int>在皮肤卡牌可见槽位范围内"] = function(_, a) return dsl.range(a["槽位"], 1, SLOTS, "槽位") end,
  ["玩家翻到皮肤下一页"] = function(w) skin_panel.handle_action(w.skin_state, "next", _role(w)) return true end,
  ["玩家翻到皮肤上一页"] = function(w) skin_panel.handle_action(w.skin_state, "prev", _role(w)) return true end,
  ["当前皮肤页码为1"] = function(w) return dsl.eq(_panel(w).page_index, 1, "皮肤页码") end,
  ["当前皮肤页码为<页码:int>"] = function(w, a) return dsl.eq(_panel(w).page_index, a["页码"], "皮肤页码") end,
  ["皮肤总页数为<总页数:int>"] = function(_, a) return dsl.eq(number_utils.page_count(#skin_panel.catalog, SLOTS), a["总页数"], "皮肤总页数") end,
  ["皮肤目录末页展示<末页槽位数:int>个皮肤槽位"] = function(_, a)
    local size = #skin_panel.catalog
    local remainder = size % SLOTS
    return dsl.eq(remainder == 0 and math.min(size, SLOTS) or remainder, a["末页槽位数"], "末页槽位数")
  end,
  ["皮肤商店打开角色ID为<验证角色ID:int>"] = function(w, a) return dsl.eq(_panel(w).role_id, a["验证角色ID"], "皮肤商店角色ID") end,
  -- ── 解锁 / 购买 / 装备 ─────────────────────────────────────────────
  ["槽位<槽位:int>的皮肤尚未解锁"] = function(w, a)
    if not _skin_at(w, a["槽位"]) then return nil, "no skin at slot " .. tostring(a["槽位"]) end
    local view = _view(w, a["槽位"])
    if view and view.status ~= "locked" then return nil, "槽位" .. tostring(a["槽位"]) .. " 皮肤已被持有" end
    return true
  end,
  ["玩家购买槽位<槽位:int>的皮肤"] = function(w, a) skin_panel.unlock(w.skin_state, _role(w), "buy", a["槽位"]) return true end,
  ["槽位<槽位:int>的皮肤已归玩家持有"] = _owned_step("槽位", false),
  ["槽位<新槽位:int>的皮肤已归玩家持有"] = _owned_step("新槽位", false),
  ["槽位<验证槽位:int>的皮肤已归玩家持有"] = _owned_step("验证槽位", true),
  ["玩家穿上槽位<槽位:int>的皮肤"] = function(w, a) skin_panel.equip(w.skin_state, _role(w), a["槽位"]) return true end,
  ["槽位<槽位:int>的皮肤已装备成功"] = function(w, a)
    local view = _view(w, a["槽位"])
    if not (view and view.status == "equipped") then return nil, "槽位" .. tostring(a["槽位"]) .. " 未装备; selected=" .. tostring(_equipped(w)) end
    return true
  end,
  ["皮肤未成功装备"] = function(w) return dsl.eq(_equipped(w), nil, "装备中皮肤") end,
  ["无皮肤装备中"] = function(w) return dsl.eq(_equipped(w), nil, "装备中皮肤") end,
  ["玩家脱下当前皮肤"] = function(w) skin_panel.handle_action(w.skin_state, "unequip", _role(w)) return true end,
  -- 真实点击路径：皮肤面板路由意图 -> dispatch（区别于 equip 直调）。
  ["玩家点击槽位<槽位:int>的皮肤动作按钮"] = _node_step(skin_nodes.action_buttons, function(w, _, node)
    return _dispatch_route(w, skin_panel.build_route_specs(w.skin_state), node)
  end),
  -- ── 付费购买存档 / 重开局 ──────────────────────────────────────────
  ["玩家付费购买槽位<槽位:int>的皮肤"] = function(w, a)
    skin_panel.configure_archive(_archive(w))
    _configure_gateway(w, true)
    skin_panel.equip(w.skin_state, _role(w), a["槽位"])
    return true
  end,
  ["玩家重新开局并打开皮肤商店"] = function(w)
    _bind_state(w)
    skin_panel.configure_archive(_archive(w))
    skin_panel.open(w.skin_state, _role(w))
    return true
  end,
  -- ── 回调注册 / 断言 ────────────────────────────────────────────────
  ["换装回调已注册"] = function(w)
    w.equip_callback_product = nil
    skin_panel.configure_equip(function(_, skin) w.equip_callback_product = skin and skin.product_id return true end)
    return true
  end,
  ["换装回调收到的皮肤产品ID为<产品ID>"] = function(w, a) return dsl.eq(w.equip_callback_product, a["产品ID"], "换装回调产品ID") end,
  ["脱下回调已注册"] = function(w)
    w.unequip_callback_role = nil
    skin_panel.configure_unequip(function(role_id) w.unequip_callback_role = role_id end)
    return true
  end,
  ["脱下回调收到的角色ID为<角色ID:int>"] = function(w, a) return dsl.eq(w.unequip_callback_role, a["角色ID"], "脱下回调角色ID") end,
  ["购买回调已注册"] = function(w) _ensure_state(w) w.purchase_call_args = nil _configure_gateway(w, false) return true end,
  ["购买回调注册为成功回调"] = function(w) _ensure_state(w) w.purchase_call_args = nil _configure_gateway(w, true) return true end,
  ["购买回调收到的角色ID为<角色ID:int>"] = function(w, a)
    if not w.purchase_call_args then return nil, "purchase callback was not invoked" end
    return dsl.eq(w.purchase_call_args.role_id, a["角色ID"], "购买回调角色ID")
  end,
  ["购买回调收到的皮肤产品ID为<产品ID>"] = function(w, a)
    local skin = w.purchase_call_args and w.purchase_call_args.skin
    if not skin then return nil, "purchase callback missing skin entry" end
    return dsl.eq(tostring(skin.product_id), tostring(a["产品ID"] or ""), "购买回调产品ID")
  end,
  -- ── 渲染断言 ──────────────────────────────────────────────────────
  ["皮肤卡片渲染数为<卡片渲染数:int>个"] = function(w, a) return dsl.eq(_count_visible(w, skin_nodes.card_images), a["卡片渲染数"], "卡片渲染数") end,
  ["皮肤卡牌槽位容器展示数为<容器数:int>个"] = function(w, a) return dsl.eq(_count_visible(w, skin_nodes.card_outlines), a["容器数"], "槽位容器展示数") end,
  ["皮肤静态文本未被改写"] = function(w)
    for _, node in ipairs({ "皮肤_皮肤商店文本", "皮肤_皮肤商店底框", "皮肤_皮肤商店底框2" }) do
      if w.skin_labels[node] ~= nil then return nil, node .. " 文字被改写为: " .. tostring(w.skin_labels[node]) end
    end
    return true
  end,
  ["皮肤卡牌槽位<槽位:int>当前贴图为皮肤<皮肤ID>的图"] = _node_step(skin_nodes.card_images, function(w, a, node)
    return dsl.eq(w.skin_textures[node], "tex_" .. tostring(a["皮肤ID"] or ""), "槽位" .. tostring(a["槽位"]) .. " 贴图")
  end),
  ["槽位<槽位:int>对应皮肤产品ID为<产品ID>"] = function(w, a)
    local slot = a["槽位"]
    local skin = _skin_at(w, slot)
    if not skin then return nil, "no skin at slot " .. tostring(slot) end
    return dsl.eq(tostring(skin.product_id), tostring(a["产品ID"] or ""), "槽位" .. tostring(slot) .. " 产品ID")
  end,
  -- 非大纲场景（排序）：步骤文本是字面值（如「槽位1对应皮肤产品ID为skin_2」），
  -- shape matching 命中不了 <...> 键；用 {名:int}/{名} 内联捕获作为第三层 fallback。
  ["槽位{slot:int}对应皮肤产品ID为{product_id}"] = function(w, a)
    local skin = _skin_at(w, a["slot"])
    if not skin then return nil, "no skin at slot " .. tostring(a["slot"]) end
    return dsl.eq(tostring(skin.product_id), tostring(a["product_id"] or ""), "槽位" .. tostring(a["slot"]) .. " 产品ID")
  end,
  ['皮肤卡牌槽位<槽位:int>按钮文本为"<按钮文本>"'] = _node_step(skin_nodes.action_buttons, function(w, a, node)
    return dsl.eq(w.skin_button_text[node], tostring(a["按钮文本"] or ""), "槽位" .. tostring(a["槽位"]) .. " 按钮文本")
  end),
  ["皮肤卡牌槽位<槽位:int>按钮可点"] = _node_step(skin_nodes.action_buttons, function(w, a, node)
    return dsl.eq(w.skin_button_touch[node], true, "槽位" .. tostring(a["槽位"]) .. " 按钮触摸")
  end),
  ["皮肤卡牌槽位<槽位:int>价格图标已展示"] = _node_step(skin_nodes.price_icons, function(w, a, node)
    return dsl.eq(w.skin_visibility[node] == true, true, "槽位" .. tostring(a["槽位"]) .. " 价格图标")
  end),
  -- <槽位>/<断言槽位>/<验证槽位> 三套句面经 shape 分派绑定后共用这一个工厂 handler。
  ["皮肤卡牌槽位<槽位:int>价格图标已隐藏"] = _node_step(skin_nodes.price_icons, function(w, a, node)
    return dsl.eq(w.skin_visibility[node] == true, false, "槽位" .. tostring(a["槽位"]) .. " 价格图标")
  end),
  -- 变异种子：purchase 解锁但价格/货币字段缺失时价格图标仍隐藏（价格判定两个 and 分支）。
  ["槽位<槽位:int>的皮肤保持购买解锁但清空价格字段"] = _catalog_mutation("price"),
  ["槽位<槽位:int>的皮肤保持购买解锁但清空货币字段"] = _catalog_mutation("currency"),
}, { name = "skin_shop" })
