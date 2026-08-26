local dsl = require("packages.acceptance.step_dsl")
local popup_presenter = require("src.ui.coord.popup_presenter")
local view_command = require("src.ui.input.view_command")
local route_popup = require("src.ui.input.route_popup")
local event_actor_policy = require("src.ui.coord.event_actor_policy")
local runtime_ui = require("src.ui.render.support.runtime_ui")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local canvas = require("src.ui.coord.canvas_coordinator")
local role_context = require("src.ui.view.role_context")
local popup_nodes = require("src.ui.schema.popup")
local bankruptcy_nodes = require("src.ui.schema.bankruptcy")
local item_atlas_nodes = require("src.ui.schema.item_atlas")
local market_nodes = require("src.ui.schema.market")
local presentation_ports = require("src.ui.ports")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local card_reveal_port = require("src.rules.ports.card_reveal")
local market_screen = require("src.ui.screens.market")
local market_view = require("src.ui.render.market")

-- 卡牌展示广播域绑定：服务 card_reveal_broadcast。生产者走 src.rules.ports.card_reveal
-- 端口（land popup / gain reveal / 破产文案），展示走 popup_presenter 真实渲染链路
-- （2026-08-22 #543：获得展示全来源统一卡牌展示屏弹窗广播，item_get_reveal
-- 图鉴放大卡私有展示链已拆除）；runtime_ui / canvas / role_context 只在执行窗口内
-- 打补丁，把 per-role 可见性与画布切换捕获到 world。

local ITEM_A, ITEM_B = item_ids.free_rent, item_ids.roadblock

local function _ensure_roles(w)
  if not w.roles then
    w.roles = { { id = 1, get_roleid = function() return 1 end }, { id = 2, get_roleid = function() return 2 end } }
  end
  return w.roles
end

local function _role_by_id(w, role_id)
  for _, role in ipairs(_ensure_roles(w)) do
    if role.id == role_id then return role end
  end
  return nil
end

local function _ensure_state(w)
  if w.broadcast_state then return w.broadcast_state end
  local captures = { visibility = {}, labels = {}, textures = {}, button_text = {}, button_touch = {} }
  local ui = {
    set_visible = function(_, n, visible)
      captures.visibility[n] = visible == true
    end,
    -- set_visible_global：常驻屏节点绕过 per-role 过滤的全局显隐口（#512）。
    -- 弹窗链路不消费它,留 stub 保持 ui 面完整。
    set_visible_global = function(_, n, visible)
      captures.visibility[n] = visible == true
    end,
    set_touch_enabled_global = function(_, n, v) captures.button_touch[n] = v == true end,
    set_label = function(_, n, t) captures.labels[n] = t end,
    set_button = function(_, n, t) captures.button_text[n] = t end,
    set_touch_enabled = function(_, n, v) captures.button_touch[n] = v == true end,
    set_event_log = function(_, t) captures.labels["event_log"] = t end,
    set_event_log_visible = function(_, v) captures.visibility["debug_canvas"] = v == true end,
    query_node = function(_, n) return n end,
  }
  local fake_runtime = {
    query_node = function(n) return n end,
    query_nodes = function(n) return { n } end,
    set_node_texture_keep_size = function(node, key) captures.textures[node] = key end,
    set_node_texture_native_size = function(node, key) captures.textures[node] = key end,
    set_client_role = function() end,
    with_client_role = function(role, fn, ...)
      local ok, result = pcall(fn, ...)
      if not ok then error(result) end
      return result
    end,
  }
  -- 规则层真实生产者需要的最小 game 宿主：action_anim 队列 + 弹窗 intent 出口。
  local state
  local game = { turn = { phase = "wait_choice" }, anim_gate_port = { wait_action_anim = true, wait_move_anim = false } }
  game.queue_action_anim = function(self, payload)
    local seq = (self.turn.action_anim_seq or 0) + 1
    self.turn.action_anim_seq, payload.seq = seq, seq
    if self.turn.action_anim == nil then self.turn.action_anim = payload
    else
      self.turn.action_anim_queue = self.turn.action_anim_queue or {}
      table.insert(self.turn.action_anim_queue, payload)
    end
  end
  game.intent_output_port = { push_popup = function(_, payload, opts) return popup_presenter.push_popup(state, payload, opts) end }
  state = {
    ui = ui, runtime_asset_context = { refs = { images = { ["Empty"] = "tex_empty" } } },
    presentation_runtime = { runtime = fake_runtime },
    gameplay_loop_ports = presentation_ports.build(),
    ui_model = { current_player_id = 1, item_slots_by_player_id = { [1] = true, [2] = true } },
    game = game,
  }
  ui.popup_screen = { root = popup_nodes.canvas, title = popup_nodes.title, card = popup_nodes.card, dismiss_nodes = popup_nodes.dismiss_nodes }
  ui.bankruptcy_screen = { root = bankruptcy_nodes.canvas, text = bankruptcy_nodes.text, avatar = bankruptcy_nodes.avatar }
  ui.current_action_role_id = 1
  w.broadcast_state, w.broadcast_captures, w.broadcast_canvas_by_role = state, captures, {}
  return state
end

-- 补丁窗口：runtime_ui / runtime_ports / canvas / role_context 换成读 world 的假实现，
-- 跑完 fn 立即还原（失败也先还原再抛）。extra 可追加一次性补丁(同幂等还原口径)。
local function _with_patches(w, fn, extra)
  local patches = {
    { runtime_ui, "set_client_role", function() end },
    { runtime_ui, "get_client_role", function() return nil end },
    { runtime_ui, "with_client_role", function(role, inner, ...)
      local s = w.broadcast_state
      local fake = s and s.presentation_runtime and s.presentation_runtime.runtime
      if fake and type(fake.with_client_role) == "function" then return fake.with_client_role(role, inner, ...) end
      return inner(...)
    end },
    { runtime_ui, "for_each_role_or_global", function(inner)
      for _, role in ipairs(_ensure_roles(w)) do runtime_ui.with_client_role(role, inner, role) end
    end },
    { runtime_ui, "query_node", function(n) return n end },
    { runtime_ui, "query_nodes", function(n) return { n } end },
    { runtime_ui, "set_node_texture_keep_size", function(node, key) if node ~= nil then w.broadcast_captures.textures[node] = key end end },
    { runtime_ui, "set_node_texture_native_size", function(node, key) if node ~= nil then w.broadcast_captures.textures[node] = key end end },
    { runtime_ports, "resolve_role", function(role_id) return _role_by_id(w, role_id) end },
    { runtime_ports, "resolve_roles", function() return _ensure_roles(w) end },
    { canvas, "switch_for_role", function(_, target, role) w.broadcast_canvas_by_role[role and role.id or "global"] = target end },
    { canvas, "switch", function(_, target) w.broadcast_canvas_global = target end },
    { role_context, "resolve", function(role)
      local role_id = role and role.id or 1
      local operator_id = w.broadcast_state and w.broadcast_state.ui.current_action_role_id or nil
      return { can_operate = operator_id ~= nil and role_id == operator_id, role_id = role_id }
    end },
  }
  for _, patch in ipairs(extra or {}) do
    patches[#patches + 1] = patch
  end
  local originals = {}
  for i, patch in ipairs(patches) do
    originals[i] = patch[1][patch[2]]
    patch[1][patch[2]] = patch[3]
  end
  local ok, err = pcall(fn)
  for i = #patches, 1, -1 do patches[i][1][patches[i][2]] = originals[i] end
  if not ok then error(err) end
end

local function _captures(w) _ensure_state(w) return w.broadcast_captures end

-- 与真机同路径的点击：intent 由 route_popup 构造，actor 经点击事件附加（#143 回归）。
local function _click_popup_as(w, role)
  local state = _ensure_state(w)
  _with_patches(w, function()
    local specs = route_popup.build(state)
    local intent = specs[1] and specs[1].build_intent() or nil
    if intent == nil then return end
    event_actor_policy.attach_event_actor(state, intent, { role = role })
    view_command.dispatch(state, intent)
  end)
  return true
end

-- 复刻 effect_chance 执行器对 land presenter 的真实调用（仅省掉抽卡 RNG）。
local function _push_chance_popup(w, player_name)
  local state = _ensure_state(w)
  _with_patches(w, function()
    card_reveal_port.push_land_popup(state.game, "机会卡", player_name .. " 抽到机会卡：测试卡", {
      kind = "chance_card", image_ref = 2001, auto_close_seconds = timing.popup_dwell_default_seconds or 1.0,
      popup_opts = { policy = "defer" }, broadcast = true })
  end)
  return true
end

-- 黑市开屏/重建的真实收口(#583):跑真实 open_market_panel,数据刷新打桩旁路
-- (本域只钉 canvas 切换面),切换经 _with_patches 捕获 —— 补 panel_interrupt
-- 验收域 stub ui 遮住的旁观者强切盲区。
local function _open_market_panel(w)
  local state = _ensure_state(w)
  _with_patches(w, function()
    market_screen.open_market_panel(state,
      { options = { { id = 1 } }, allow_cancel = true, cancel_label = "取消" }, 10, nil)
  end, {
    { market_view, "refresh_market", function() return true end },
  })
  return true
end

local function _seed_item_image(state, item_id)
  state.runtime_asset_context.refs.images[tostring(item_id)] = "tex_item_" .. tostring(item_id)
end

local function _queue_item_reveal(w, item_id)
  local state = _ensure_state(w)
  _seed_item_image(state, item_id)
  return card_reveal_port.queue_gain_reveal(state.game, { id = 1, name = "角色1" }, item_id, { source = "item_tile" })
end

-- 道具获得步骤公共形(#543 全来源统一广播):排 gain_reveal + 校验
-- item_gain_popup 纯等待动画带广播标志。item_tile 与 steal 仅 source 不同。
local function _gain_step(w, item_id, source, label)
  local state = _ensure_state(w)
  _seed_item_image(state, item_id)
  local queued
  _with_patches(w, function()
    queued = card_reveal_port.queue_gain_reveal(state.game, { id = 1, name = "角色1" }, item_id, { source = source })
  end)
  if not queued then return nil, "gain_reveal did not queue " .. label .. " reveal" end
  local anim = state.game.turn.action_anim
  if not (anim and anim.kind == "item_gain_popup") then return nil, label .. " gain should queue item_gain_popup wait anim" end
  if anim.broadcast ~= true then return nil, label .. " reveal payload should carry broadcast flag" end
  return true
end

-- 全员弹窗屏断言工厂（卡牌展示屏 / 破产屏共用形状）。
local function _popup_shown_step(canvas_node, label)
  return function(w, a)
    local state = _ensure_state(w)
    return dsl.all(function() return dsl.truthy(state.ui.popup_active, label .. "弹窗激活") end,
      function() return dsl.truthy(_captures(w).visibility[canvas_node], label .. "屏可见") end,
      function() return dsl.eq(w.broadcast_canvas_by_role[a["角色ID"]], canvas_node, "角色" .. tostring(a["角色ID"]) .. " 画布") end)
  end
end

return dsl.steps({
  ["游戏存在角色1和角色2"] = function(w) _ensure_roles(w) return true end,
  ["游戏存在观战角色3"] = function(w)
    local roles = _ensure_roles(w)
    if not _role_by_id(w, 3) then roles[#roles + 1] = { id = 3, get_roleid = function() return 3 end } end
    return true
  end,
  ["当前轮到角色1行动"] = function(w)
    local state = _ensure_state(w)
    state.ui.current_action_role_id, state.ui_model.current_player_id = 1, 1
    return true
  end,
  ["当前轮到电脑玩家行动"] = function(w)
    -- 电脑玩家没有 role 映射：行动 role 为空，模型侧当前玩家指向电脑位。
    local state = _ensure_state(w)
    state.ui.current_action_role_id, state.ui_model.current_player_id = nil, 9
    return true
  end,
  ["角色1在机会格抽到机会卡"] = function(w) return _push_chance_popup(w, "角色1") end,
  ["电脑玩家在机会格抽到机会卡"] = function(w) return _push_chance_popup(w, "电脑玩家") end,
  ["角色{角色ID:int}的客户端显示卡牌展示屏"] = _popup_shown_step(popup_nodes.canvas, "卡牌展示"),
  ["角色<角色ID:int>的客户端显示破产展示屏"] = _popup_shown_step(bankruptcy_nodes.canvas, "破产"),
  ["角色<角色ID:int>的客户端隐藏卡牌展示屏"] = function(w, a)
    local state = _ensure_state(w)
    if state.ui.popup_active then return nil, "popup should be hidden" end
    if _captures(w).visibility[popup_nodes.canvas] then return nil, "card reveal screen should be hidden" end
    return dsl.ne(w.broadcast_canvas_by_role[a["角色ID"]], popup_nodes.canvas, "角色" .. tostring(a["角色ID"]) .. " 离开卡牌展示屏")
  end,
  ["角色1踩道具地块获得道具"] = function(w)
    -- 2026-08-18 换皮(CONTEXT「卡牌展示广播」 修订)+ 2026-08-22 #543:道具地块获得走
    -- 「卡牌展示屏」弹窗全员广播 + item_gain_popup 纯等待动画。
    return _gain_step(w, ITEM_A, "item_tile", "item tile")
  end,
  ["角色2点击卡牌展示屏"] = function(w) return _click_popup_as(w, _role_by_id(w, 2)) end,
  ["角色1关闭卡牌展示屏"] = function(w) return _click_popup_as(w, _role_by_id(w, 1)) end,
  -- #599:买家的关闭只是请求——被排除在受众外时 popup_confirm 被拒（关闭先要求可见），
  -- 旁观者的购买展示不受影响，只能超时收屏。走与真实点击相同的 dispatch 链路。
  ["角色1的客户端请求关闭卡牌展示屏"] = function(w) return _click_popup_as(w, _role_by_id(w, 1)) end,
  ["角色{角色ID:int}的客户端仍显示卡牌展示屏"] = _popup_shown_step(popup_nodes.canvas, "卡牌展示"),
  ["卡牌展示超过自动关闭时长"] = function(w)
    local state = _ensure_state(w)
    local payload = state.ui.popup_payload
    if not (payload and payload.auto_close_seconds and payload.auto_close_seconds > 0) then
      return nil, "chance popup payload should carry auto_close_seconds for timeout close"
    end
    -- 超时收屏走 turn 层 modal 端口（与 timeout_closure 行为规约同链路）。
    _with_patches(w, function() state.gameplay_loop_ports.modal.close_popup(state) end)
    return true
  end,
  ["角色2打开了道具图鉴"] = function(w)
    _ensure_state(w).ui.item_atlas = { open = true, role_id = 2, page_index = 1, selected_item_id = nil }
    w.broadcast_canvas_by_role[2] = item_atlas_nodes.canvas
    return true
  end,
  -- #583:旁观者图鉴处于「选中放大」态 —— 放大覆盖层三节点住图鉴 canvas 且当前可见。
  ["角色2打开道具图鉴并放大了道具卡"] = function(w)
    _ensure_state(w).ui.item_atlas = { open = true, role_id = 2, page_index = 1, selected_item_id = ITEM_A }
    w.broadcast_canvas_by_role[2] = item_atlas_nodes.canvas
    local caps = _captures(w)
    caps.visibility[item_atlas_nodes.enlarged_card], caps.visibility[item_atlas_nodes.close_hint_label], caps.visibility[item_atlas_nodes.close_blank] = true, true, true
    return true
  end,
  ["角色2的陈旧放大卡不复活"] = function(w)
    local atlas = _ensure_state(w).ui.item_atlas
    if atlas and atlas.selected_item_id ~= nil then return nil, "图鉴选中态未清" end
    local caps = _captures(w)
    for _, node in ipairs({ item_atlas_nodes.enlarged_card, item_atlas_nodes.close_hint_label, item_atlas_nodes.close_blank }) do
      if caps.visibility[node] == true then return nil, node .. " 未隐藏" end
    end
    return true
  end,
  ["角色1正在黑市选购"] = function(w) _ensure_state(w).ui.market_active = true w.broadcast_canvas_by_role[1] = market_nodes.canvas return true end,
  -- 黑市成交与道具地块获得同走 gain_reveal 广播链(#543),仅 source 不同。
  ["角色1在黑市购买到道具"] = function(w) return _gain_step(w, ITEM_A, "market", "market purchase") end,
  ["黑市屏因购买后库存变化触发重建"] = function(w) return _open_market_panel(w) end,
  ["黑市屏为角色1开启"] = function(w) return _open_market_panel(w) end,
  ["角色2的客户端仍显示道具图鉴屏"] = function(w) return dsl.eq(w.broadcast_canvas_by_role[2], item_atlas_nodes.canvas, "角色2 画布") end,
  ["机会卡把角色1传送进黑市"] = function(w)
    -- 黑市屏在弹窗存活期间打开：关屏时行动者按当前面板态解析进黑市。
    _ensure_state(w).ui.market_active = true
    return true
  end,
  ["角色1的客户端显示黑市屏"] = function(w) return dsl.eq(w.broadcast_canvas_by_role[1], market_nodes.canvas, "角色1 画布") end,
  -- 2026-08-25 买家免展示口径:黑市购买展示期间买家 canvas 保持黑市屏不动。
  ["角色{角色ID:int}的客户端仍显示黑市屏"] = function(w, a)
    return dsl.eq(w.broadcast_canvas_by_role[a["角色ID"]], market_nodes.canvas, "角色" .. tostring(a["角色ID"]) .. " 画布")
  end,
  ["角色2的客户端回到道具图鉴屏"] = function(w)
    local atlas = _ensure_state(w).ui.item_atlas
    if not (atlas and atlas.open and atlas.role_id == 2) then return nil, "item atlas is not open for role 2" end
    return dsl.eq(w.broadcast_canvas_by_role[2], item_atlas_nodes.canvas, "角色2 画布")
  end,
  ["角色1通过偷窃卡获得道具"] = function(w)
    -- #543 口径反转：偷窃来源同样走「卡牌展示屏」弹窗全员广播。
    return _gain_step(w, ITEM_A, "steal", "steal")
  end,
  ["角色1踩道具地块连续获得两张道具"] = function(w)
    local first, second
    _with_patches(w, function()
      first, second = _queue_item_reveal(w, ITEM_A), _queue_item_reveal(w, ITEM_B)
    end)
    if not (first and second) then return nil, "gain_reveal did not queue both item tile reveals" end
    return true
  end,
  ["两张道具按获得顺序逐张对全体角色展示"] = function(w)
    local state = _ensure_state(w)
    local turn = state.game.turn
    local queue = turn.action_anim_queue or {}
    -- 等待动画按获得顺序 FIFO,均带广播标志。
    if not (turn.action_anim and turn.action_anim.item_id == ITEM_A) then return nil, "first reveal should be the first gained item" end
    if not (queue[1] and queue[1].item_id == ITEM_B) then return nil, "second gained item should wait in the reveal queue" end
    if turn.action_anim.broadcast ~= true or queue[1].broadcast ~= true then return nil, "both item tile reveals should carry broadcast flag" end
    -- 卡牌展示屏按 popup 队列逐张播:第一张激活,第二张 defer 排队。
    local active = state.ui.popup_payload
    if not (active and active.image_ref == ITEM_A) then return nil, "first gain popup should be active" end
    local popup_queue = state.ui.popup_queue or {}
    if not (popup_queue[1] and popup_queue[1].image_ref == ITEM_B) then return nil, "second gain popup should wait in the popup queue" end
    for _, role in ipairs(_ensure_roles(w)) do
      if w.broadcast_canvas_by_role[role.id] ~= popup_nodes.canvas then
        return nil, "first gain popup not shown for role " .. tostring(role.id)
      end
    end
    -- 第一张收屏后按 FIFO 推进到第二张(队列推进语义由 popup_presenter 负责)。
    _with_patches(w, function() popup_presenter.close_popup(state) end)
    local next_popup = state.ui.popup_payload
    return dsl.eq(next_popup and next_popup.image_ref, ITEM_B, "第二张卡牌展示屏卡图")
  end,
  ["角色1破产"] = function(w)
    local state = _ensure_state(w)
    -- 真实破产链路载荷形状：kind=bankruptcy，不带 broadcast 标志（既有全员可见行为）。
    local player = { id = 1, name = "角色1" }
    _with_patches(w, function()
      popup_presenter.push_popup(state, { kind = "bankruptcy", player_id = player.id, player_name = player.name,
        text = card_reveal_port.bankruptcy_text(player, nil) })
    end)
    return true
  end,
}, { name = "card_reveal_broadcast" })
