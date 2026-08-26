local dsl = require("packages.acceptance.step_dsl")
local number_utils = require("src.foundation.number")
local items_cfg = require("src.config.content.items")
local panel_slice = require("src.ui.view.panel_slice")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local ui_runtime = require("src.ui.coord.ui_runtime")
local ui_state = require("src.ui.coord.ui_state")
local panel_presenter = require("src.ui.render.widgets.presenter")
local route_base = require("src.ui.input.route_base")
local completion = require("src.turn.optional_action_completion")
local choice_builder = require("src.ui.view.choice_builder")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local game_driver = require("packages.acceptance.game_driver")
local turn_driver = require("packages.acceptance.turn_driver")
local base_nodes = require("src.ui.schema.base")

-- 基础屏域绑定：收编旧 base_screen/ 九个子模块（context / render_flow_context / state_tables /
-- assert_helpers / 五个 step 文件）。自建 world（前缀 bs_）状态 + panel_slice / presenter /
-- route_base 公开面驱动。按视角分工(#597)：按钮可见性与推进语义全住
-- game/main_turn_buttons，身份可见性(旁观/AI/托管/非当前玩家)住 base_screen；
-- 两个 feature 的句面都由本域提供。
-- 道具使用/目标选择句面例外：不走 world 模拟,驱动真实引擎(game_driver 开真实道具窗、
-- 真实槽位派发进 followup、真实 choice_cancel 派发链),choice 投影与库存断言全落真实
-- game 状态——手捏 choice 的老路是「验收全绿、真机全挂」的事故成因,不许回头。

local SKIN_NODES = { ["按钮"] = base_nodes.skin_button, ["文字"] = base_nodes.skin_label }
local AUX_NODES = { ["道具图鉴"] = base_nodes.gallery_button, ["托管按钮"] = base_nodes.auto_button, ["行动日志"] = base_nodes.action_log_button }
local OPTIONAL_KIND = { ["道具槽位"] = "item_phase_passive", ["选择控件"] = "item_phase_passive", ["落地选择"] = "landing_optional_effect" }
local FOLLOWUP = { ["道具槽位"] = "投骰移动落地流程", ["选择控件"] = "必经流程", ["落地选择"] = "回合清理流程" }
local BLOCKING = { ["选择弹窗"] = true, ["二次确认弹窗"] = true, ["目标选择"] = true, ["黑市界面"] = true, ["弹窗提示"] = true, ["行动动画"] = true, ["移动动画"] = true, ["落地视觉等待"] = true }
local STAGE = { ["扣留等待"] = true, ["医院等待"] = true, ["山路等待"] = true, ["回合间等待"] = true, ["游戏结束"] = true, ["空可选行动阶段"] = true }
local CONFIRM = { ["购买地块"] = true, ["加盖建筑"] = true, ["强征卡"] = true, ["免税卡"] = true }

local function _rid(w) return number_utils.to_integer(w.ui_role_id) or 1 end

local function _make_game()
  local players = {}
  for id = 1, 4 do players[id] = { id = id, name = "P" .. tostring(id), cash = 1000, properties = {} } end
  return { players = players, auto_play_port = { is_computer_controlled = function() return false end, auto_action_for_choice = function() return nil end } }
end

local function _action_rid(w)
  if w.bs_action_role_unset == true then return nil end
  return number_utils.to_integer(w.bs_action_role_id) or _rid(w)
end

local function _followup(w) return FOLLOWUP[tostring(w.bs_optional_action or "")] or "必经流程" end

-- 可选行动阶段在 ui_model 上是一条 pending choice；道具使用/目标选择先于命名可选行动占位。
-- 引擎驱动的道具句面在场时，choice 一律从真实 game.turn.pending_choice 经生产投影
-- (choice_builder)取得——渲染与 intent 看到的就是 rules 层真实产出的形态。
local function _choice_for(w, action_rid)
  if w.bs_engine_item ~= nil then
    local pending = w.driver and w.driver.game.turn.pending_choice or nil
    if pending == nil then return nil end
    return choice_builder.build_choice_view(pending)
  end
  if w.bs_empty_optional == true or w.bs_optional_action == nil then return nil end
  local name = tostring(w.bs_optional_action)
  local kind = OPTIONAL_KIND[name]
  if kind == nil then return nil end
  return { id = 9001, kind = kind, allow_cancel = true, owner_role_id = action_rid,
    route_key = kind == "item_phase_passive" and "item_phase_passive" or "base_inline",
    options = { { id = "optional", label = name } }, meta = { optional_action = name, followup_flow = _followup(w) } }
end

-- 引擎驱动的 followup 在场时,真机会由选择屏开屏置 choice_active——渲染断言
-- 必须在同一前提下跑(此前 fake ui 恒 false,正是「门禁绿、真机不亮」的测不到点)。
local function _engine_followup_active(w)
  local pending = w.driver and w.driver.game.turn.pending_choice or nil
  return pending ~= nil and type(pending.meta) == "table" and pending.meta.passive_origin == true
end

local function _make_render_state(w)
  local state = {
    ui = ui_state.build_ui_state(),
    runtime_asset_context = { refs = { images = { Empty = "EMPTY" } } },
  }
  local ui = state.ui
  ui.labels, ui.buttons, ui.visibility, ui.touch = {}, {}, {}, {}
  ui.input_blocked, ui.popup_active = w.bs_input_blocked == true, w.bs_buy_property_open == true or w.bs_upgrade_choice_open == true
  ui.choice_active = w.bs_engine_item ~= nil and _engine_followup_active(w)
  ui.set_label = function(self, n, t) self.labels[n] = t end
  ui.set_button = function(self, n, t) self.buttons[n] = t end
  ui.set_visible = function(self, n, v) self.visibility[n] = v end
  ui.set_touch_enabled = function(self, n, v) self.touch[n] = v end
  -- 门面新增的同名节点全量压触摸口（分享装饰子节点用），同样收进 touch 捕获表。
  ui.set_touch_enabled_all = function(self, n, v) self.touch[n] = v end
  ui.query_node = function() return {} end
  return state
end

local function _delegated_by_player(w) return { [_rid(w)] = w.bs_auto_enabled == true } end

local function _build_panel(w, panel_rid, game, delegated)
  return panel_slice.build(game or _make_game(), { game = { board = {} } }, { turn_count = 1, countdown_seconds = 0 }, panel_rid, delegated or _delegated_by_player(w))
end

local function _build_ui_model(w)
  local game, action_rid, delegated = _make_game(), _action_rid(w), _delegated_by_player(w)
  local slots = {}
  if w.bs_viewer_is_spectator ~= true then slots[_rid(w)] = {} end
  if action_rid ~= nil then slots[action_rid] = {} end
  return { current_player_id = action_rid, delegated_by_player = delegated, board = { players = game.players },
    item_slots_by_player = slots, choice = _choice_for(w, action_rid), panel = _build_panel(w, action_rid or _rid(w), game, delegated) }
end

local function _refresh(w)
  w.bs_render_state, w.bs_ui_model = _make_render_state(w), _build_ui_model(w)
  w.bs_render_state.ui_runtime = { ui_model = w.bs_ui_model }
  panel_presenter.refresh(w.bs_render_state, w.bs_ui_model, {
    runtime = { set_client_role = function() end, query_node = function() return {} end, set_node_texture_native_size = function() end,
      resolve_role_id = function(target) return target and target.id or nil end,
      for_each_role_or_global = function(callback) callback({ id = _rid(w) }) end },
    refresh_item_slots = function() end })
  return w.bs_render_state
end

local function _refresh_step(w) _refresh(w) return true end

local function _intent(w, node)
  if w.bs_render_state == nil then _refresh(w) end
  for _, spec in ipairs(route_base.build(w.bs_render_state)) do
    if spec.name == node and type(spec.build_intent) == "function" then return spec.build_intent() end
  end
  return nil
end

local function _vis(w, node) local s = w.bs_render_state return s and s.ui and s.ui.visibility and s.ui.visibility[node] end
local function _tch(w, node) local s = w.bs_render_state return s and s.ui and s.ui.touch and s.ui.touch[node] end

local function _shown_touchable(w, node, label)
  return dsl.all(function() return dsl.eq(_vis(w, node), true, label .. " 可见") end,
    function() return dsl.eq(_tch(w, node), true, label .. " 可点") end)
end

local function _completion_game(w)
  local game = _make_game()
  game.turn = { current_player_index = _action_rid(w) or _rid(w), pending_choice = w.bs_ui_model and w.bs_ui_model.choice or nil }
  game.current_player = function(self) return self.players[self.turn.current_player_index] end
  return game
end

local function _clear_choice(w)
  if w.bs_ui_model then w.bs_ui_model.choice = nil end
  local m = w.bs_render_state and w.bs_render_state.ui_runtime and w.bs_render_state.ui_runtime.ui_model
  if m then m.choice = nil end
end

local function _run_completion(w, input_source, capture_key)
  return completion.complete_optional_action_phase(_completion_game(w), _rid(w), w.bs_render_state, {
    input_source = input_source,
    dispatch_choice_action = function(action) w[capture_key] = action return { status = "applied" } end })
end

local function _complete_optional(w, intent, input_source)
  local result = _run_completion(w, input_source, "bs_completion_action")
  w.bs_completion_result = result
  if result.ok == true then
    w.bs_optional_completed, w.bs_pending_cleared, w.bs_followup_flow = true, true, _followup(w)
    w.bs_end_intent = intent or w.bs_end_intent
    _clear_choice(w)
  end
  return result
end

-- ── 道具使用/目标选择：真实引擎驱动 ────────────────────────────────
local function _item_cfg(name)
  for _, item in ipairs(items_cfg) do
    if item.name == name then return item end
  end
  return nil
end

local function _engine_game(w) return w.driver and w.driver.game or nil end

local function _engine_player(w)
  local game = _engine_game(w)
  return game and game.players[_action_rid(w) or _rid(w)] or nil
end

local function _opponent_of(game, player)
  return game.players[player.id % #game.players + 1]
end

-- 拆除类卡(怪兽/导弹)候选前置：3 格内造一栋对手建筑。
local function _demolishable_setup(w, game, player)
  for _, idx in ipairs(game_driver.tile_indices_in_range(w.driver, player.position, 3)) do
    local tile = game.board:get_tile(idx)
    if tile and tile.type == "land" and idx ~= player.position then
      game:set_tile_owner(tile, _opponent_of(game, player).id)
      game:set_tile_level(tile, 1)
      return true
    end
  end
  return nil, "3 格内没有可布置对手建筑的 land 地块"
end

-- 各卡 followup 的候选前置：让真实 availability / 候选面成立。
-- 未列出的卡(均富/流放/查税/穷神/遥控骰子/路障)默认局面即有候选。
local ITEM_TARGET_SETUP = {
  ["偷窃卡"] = function(w, game, player)
    game_driver.give_item(w.driver, _opponent_of(game, player), _item_cfg("路障卡").id)
    return true
  end,
  ["怪兽卡"] = _demolishable_setup,
  ["导弹卡"] = _demolishable_setup,
  ["请神卡"] = function(_, game, player)
    game:set_player_deity(_opponent_of(game, player), "rich")
    return true
  end,
  ["送神卡"] = function(_, game, player)
    game:set_player_deity(player, "poor")
    return true
  end,
}

local function _slot_window_offers(pending, item_id)
  for _, opt in ipairs(pending.options or {}) do
    if (type(opt) == "table" and opt.id or opt) == item_id then return true end
  end
  return false
end

-- 让真实回合机自己把道具阶段窗开出来(turn_driver.advance_to_item_window;手工
-- open_choice 的窗会被回合协程首次 step 时自开的新窗顶掉,choice_id 必失配),
-- 并要求窗内确实供出目标卡。
local function _machine_item_window(w, item_id)
  local window = turn_driver.advance_to_item_window(w.driver)
  if window == nil or not _slot_window_offers(window, item_id) then
    return nil
  end
  return window
end

-- 进入某道具的使用后续选择：回合机开真实道具阶段窗 → 真实槽位派发(#199 链路)→
-- 真实 followup pending_choice。「<道具名>的道具使用阶段」与「点击道具槽位1进入
-- 目标选择」都落到这一真实状态(引擎里道具用出后唯一的可反悔中间态就是 followup)。
local function _enter_item_followup(w, raw_name)
  local name = tostring(raw_name or "")
  local cfg = _item_cfg(name)
  if cfg == nil then return nil, "unknown item name: " .. name end
  w.driver = w.driver or game_driver.new_game()
  local game = _engine_game(w)
  local player = _engine_player(w)
  if player == nil then return nil, "no engine player for role " .. tostring(_action_rid(w)) end
  game.turn.current_player_index = player.id
  local setup = ITEM_TARGET_SETUP[name]
  if setup ~= nil then
    local ok, err = setup(w, game, player)
    if not ok then return nil, err end
  end
  game_driver.clear_items(w.driver, player)
  game_driver.give_item(w.driver, player, cfg.id)
  local window = _machine_item_window(w, cfg.id)
  if window == nil then return nil, name .. " 的道具阶段窗未由回合机开出" end
  local phase = window.meta and window.meta.phase
  local click = game_driver.click_item_slot(w.driver, player, 1)
  if not (click and click.status == "applied") then
    return nil, name .. " 槽位点击未 applied: " .. tostring(click and click.status)
  end
  local pending = game.turn.pending_choice
  if not (pending and pending.meta and pending.meta.passive_origin == true) then
    return nil, name .. " 未打开后续选择(pending kind: " .. tostring(pending and pending.kind) .. ")"
  end
  w.bs_engine_item = { id = cfg.id, name = name, phase = phase }
  return true
end

-- 取消后应回到的状态：重开的道具阶段窗(reopen_or_finish 语义,非 followup)。
local function _pending_slot_window(w)
  local pending = _engine_game(w) and _engine_game(w).turn.pending_choice or nil
  if pending == nil or pending.kind ~= "item_phase_passive" then return nil end
  if pending.meta and pending.meta.passive_origin == true then return nil end
  return pending
end

local function _trigger_action(w)
  local intent = _intent(w, base_nodes.action_button)
  w.bs_action_triggered, w.bs_action_intent = true, intent
  if intent and intent.type == "ui_button" and intent.id == "next" then
    w.bs_required_flow_started, w.bs_dice_rolled, w.bs_move_completed = true, true, true
  end
  return true
end

local function _trigger_end(w)
  local intent = _intent(w, base_nodes.end_button)
  w.bs_end_intent = intent
  if intent and intent.type == "complete_optional_action_phase" then
    if _complete_optional(w, intent, "user").ok == true then w.bs_turn_ended, w.bs_next_player = true, true end
  end
  return true
end

local function _catalog_has(item_name)
  for _, item in ipairs(items_cfg) do
    if item.name == item_name then return true end
  end
  return false
end

local function _give_item(w, raw)
  local name = tostring(raw or "")
  if not _catalog_has(name) then return nil, "unknown item name: " .. name end
  w.bs_inventory = w.bs_inventory or {}
  w.bs_inventory[name] = (w.bs_inventory[name] or 0) + 1
  return true
end

local function _set_blocking(w, raw)
  local name = tostring(raw or "")
  if BLOCKING[name] ~= true then return nil, "unknown blocking state: " .. name end
  w.bs_blocking_state, w.bs_input_blocked = name, true
  return true
end

local function _set_optional_phase(w, a)
  local name = tostring(a["可选行动"] or "")
  if OPTIONAL_KIND[name] == nil then return nil, "unknown optional action: " .. name end
  w.bs_optional_action, w.bs_empty_optional = name, false
  return true
end

local function _set_item_phase(w, a, phase)
  local name = tostring(a["道具名"] or "")
  if not _catalog_has(name) then return nil, "unknown item name: " .. name end
  w.bs_item_phases = w.bs_item_phases or {}
  w.bs_item_phases[name] = phase
  if phase == "post_action" then w.bs_optional_action, w.bs_empty_optional = "落地选择", false end
  return true
end

-- 落点归属 → bs_landed_property 形状：决定落地后开哪条强制选择（买地 / 加盖）。
local LANDED_PROPERTY = {
  ["可购买的无主地块"] = function() return { buyable = true, owner_role_id = nil } end,
  ["自有可加盖地块"] = function(w) return { buyable = false, owner_role_id = _action_rid(w), upgradeable = true } end,
}

local function _land_step(w, ownership)
  local build = LANDED_PROPERTY[tostring(ownership or "")]
  if build == nil then return nil, "unknown landed property ownership: " .. tostring(ownership) end
  w.bs_landed_property = build(w)
  return true
end

-- 落地选择弹窗（买地 / 加盖）打开的公共形：置开标志 + 选择弹窗阻断 + 刷新。
local CHOICE_OPEN_FIELD = { ["买地选择界面"] = "bs_buy_property_open", ["加盖选择界面"] = "bs_upgrade_choice_open" }

local function _choice_open_step(w, screen)
  local field = CHOICE_OPEN_FIELD[tostring(screen or "")]
  if field == nil then return nil, "unknown landing choice screen: " .. tostring(screen) end
  w[field] = true
  local ok, err = _set_blocking(w, "选择弹窗")
  if not ok then return nil, err end
  return _refresh_step(w)
end

local function _skin_step(expected)
  return function(w, a)
    local node = SKIN_NODES[tostring(a["节点"] or "")]
    if node == nil then return nil, "unknown skin entry node: " .. tostring(a["节点"]) end
    return dsl.eq(_vis(w, node), expected, node .. " 显隐")
  end
end

local function _aux_step(check)
  return function(w, a)
    local node = AUX_NODES[tostring(a["入口"] or "")]
    if node == nil then return nil, "unknown base auxiliary entry: " .. tostring(a["入口"]) end
    return check(w, node)
  end
end

return dsl.steps({
  -- ── 角色 / 回合 / 控制 ──────────────────────────────────────────────
  ["玩家角色ID为<角色ID:int>"] = function(w, a)
    if a["角色ID"] < 1 or a["角色ID"] > 4 then return nil, "invalid role_id: " .. tostring(a["角色ID"]) end
    w.ui_role_id = a["角色ID"]
    if w.driver then w.market_player = w.driver.game.players[a["角色ID"]] end
    return true
  end,
  ["当前轮到角色ID为<行动角色ID:int>"] = function(w, a)
    if a["行动角色ID"] < 1 or a["行动角色ID"] > 4 then return nil, "invalid action role_id: " .. tostring(a["行动角色ID"]) end
    w.bs_action_role_id, w.bs_action_role_unset = a["行动角色ID"], false
    return true
  end,
  ["当前轮次未定"] = function(w) w.bs_action_role_id, w.bs_action_role_unset = nil, true return true end,
  ["观察身份为<观察身份>"] = function(w, a)
    if tostring(a["观察身份"] or "") ~= "旁观角色" then return nil, "unknown observer identity: " .. tostring(a["观察身份"]) end
    w.ui_role_id, w.bs_viewer_is_spectator = 99, true
    return true
  end,
  ["玩家托管状态为<托管状态>"] = function(w, a)
    local text = tostring(a["托管状态"] or "")
    if text ~= "开启" and text ~= "关闭" then return nil, "unknown auto state: " .. text end
    w.bs_auto_enabled = text == "开启"
    return true
  end,
  ["当前行动控制为人类"] = function(w) w.bs_action_control, w.bs_input_blocked = "人类", false return true end,
  ["当前行动控制为<行动控制>"] = function(w, a)
    local control = tostring(a["行动控制"] or "")
    if control ~= "人类" and control ~= "AI" and control ~= "托管" then return nil, "unknown action control: " .. control end
    w.bs_action_control = control
    if control ~= "人类" then w.bs_input_blocked = true end
    return true
  end,
  -- ── 阶段 / 阻断状态 ────────────────────────────────────────────────
  ["输入门已锁"] = function(w) w.bs_input_blocked = true return true end,
  ["玩家处于行动等待阶段"] = function(w) w.bs_optional_action, w.bs_empty_optional, w.bs_stage_state = nil, false, "行动等待阶段" return true end,
  ["玩家处于包含<可选行动>的可选行动阶段"] = _set_optional_phase,
  ["行动角色处于包含<可选行动>的可选行动阶段"] = _set_optional_phase,
  ["没有阻断性界面或动画等待"] = function(w) w.bs_input_blocked, w.bs_blocking_state = false, nil return true end,
  ["<阻断状态>正在生效"] = function(w, a) return _set_blocking(w, a["阻断状态"]) end,
  ["弹窗提示导致输入锁定"] = function(w) return _set_blocking(w, "弹窗提示") end,
  ["通用二次确认屏因<触发源>而显示"] = function(w, a)
    local source = tostring(a["触发源"] or "")
    if CONFIRM[source] ~= true then return nil, "unknown secondary confirm trigger: " .. source end
    local ok, err = _set_blocking(w, "二次确认弹窗")
    if not ok then return nil, err end
    w.bs_secondary_confirm_open, w.bs_secondary_confirm_trigger = true, source
    return true
  end,
  ["玩家处于<阶段状态>"] = function(w, a)
    local name = tostring(a["阶段状态"] or "")
    if STAGE[name] ~= true then return nil, "unknown stage state: " .. name end
    w.bs_stage_state, w.bs_optional_action, w.bs_empty_optional = name, nil, name == "空可选行动阶段"
    if not w.bs_empty_optional then w.bs_input_blocked = true end
    return true
  end,
  -- ── 道具 / 落地前置 ────────────────────────────────────────────────
  ["玩家背包中有<道具名>"] = function(w, a) return _give_item(w, a["道具名"]) end,
  ["玩家背包中还有<第二道具名>"] = function(w, a) return _give_item(w, a["第二道具名"]) end,
  ["<道具名>可在行动前使用"] = function(w, a) return _set_item_phase(w, a, "pre_action") end,
  ["<道具名>可在行动后使用"] = function(w, a) return _set_item_phase(w, a, "post_action") end,
  ["玩家点击道具槽位1进入目标选择"] = function(w, a) return _enter_item_followup(w, a["道具名"]) end,
  ["玩家处于<道具名>的道具使用阶段"] = function(w, a) return _enter_item_followup(w, a["道具名"]) end,
  ["玩家已投骰子并完成移动"] = function(w) w.bs_dice_rolled, w.bs_move_completed, w.bs_stage_state = true, true, "移动完成" return true end,
  ["玩家已投骰子且移动被路障截停"] = function(w) w.bs_dice_rolled, w.bs_move_completed, w.bs_stopped_on_roadblock, w.bs_stage_state = true, true, true, "移动完成" return true end,
  ["玩家落点为<地块归属>"] = function(w, a) return _land_step(w, a["地块归属"]) end,
  -- 路障触发动画 = 生产侧 roadblock_trigger 行动动画（wait_action_anim 阶段），
  -- 播放期间输入锁住，主按钮全下。只有截停才播，故先校前置。
  ["路障触发动画播放时"] = function(w)
    if w.bs_stopped_on_roadblock ~= true then return nil, "roadblock trigger animation requires a roadblock stop" end
    local ok, err = _set_blocking(w, "行动动画")
    if not ok then return nil, err end
    return _refresh_step(w)
  end,
  ["<选择界面>显示时"] = function(w, a) return _choice_open_step(w, a["选择界面"]) end,
  ["所有强制落地选择已处理完毕"] = function(w)
    w.bs_forced_landing_resolved, w.bs_buy_property_open, w.bs_upgrade_choice_open, w.bs_blocking_state, w.bs_input_blocked = true, false, false, nil, false
    if w.bs_optional_action == nil then w.bs_optional_action, w.bs_empty_optional = "落地选择", false end
    return true
  end,
  ["倒计时已超时"] = function(w) w.bs_countdown_timeout = true return true end,
  -- ── 刷新 / 触发 ────────────────────────────────────────────────────
  ["基础屏刷新"] = function(w) w.bs_panel = _build_panel(w, _rid(w)) return true end,
  ["基础屏为该玩家刷新"] = _refresh_step,
  ["基础屏为观察玩家刷新"] = _refresh_step,
  ["基础屏为观察身份刷新"] = _refresh_step,
  ["基础屏刷新后应用输入锁"] = function(w) w.bs_input_blocked = true ui_runtime.apply_input_lock(_refresh(w)) return true end,
  ["触发基础屏行动按钮"] = _trigger_action,
  ["触发基础屏结束按钮"] = _trigger_end,
  -- 取消触发走真机同径:route_base 从真实投影 choice 构造 intent(按钮口径),
  -- 再经 turn_dispatch.dispatch_action 过 gate/validator/resolver 真实取消链。
  ["触发基础屏取消按钮"] = function(w)
    local intent = _intent(w, base_nodes.cancel_button)
    w.bs_cancel_intent = intent
    if w.bs_engine_item == nil then return nil, "取消句面需要先进入真实道具使用/目标选择前置" end
    if not (intent and intent.type == "choice_cancel") then
      return nil, "基础屏取消按钮未构造 choice_cancel 意图"
    end
    w.bs_cancel_result = turn_dispatch.dispatch_action(_engine_game(w), w.bs_render_state, {
      type = "choice_cancel",
      choice_id = intent.choice_id,
      actor_role_id = _action_rid(w) or _rid(w),
      input_source = "user",
    })
    return true
  end,
  ["系统自动执行主按钮操作"] = function(w)
    if w.bs_stage_state == "行动等待阶段" then return _trigger_action(w) end
    return _trigger_end(w)
  end,
  ["可选行动阶段超时"] = function(w)
    if w.bs_render_state == nil then _refresh(w) end
    local intent = choice_auto_policy.decide(_completion_game(w), w.bs_render_state, w.bs_ui_model and w.bs_ui_model.choice or nil, { mode = "tick_timeout" })
    w.bs_timeout_intent = intent
    if intent and intent.type == "complete_optional_action_phase" then _complete_optional(w, intent, "timer") end
    return true
  end,
  -- ── 渲染断言 ──────────────────────────────────────────────────────
  ["基础屏当前行动角色ID为<预期行动角色ID:int>"] = function(w, a)
    return dsl.eq(w.bs_ui_model and w.bs_ui_model.current_player_id or nil, a["预期行动角色ID"], "基础屏当前行动角色ID")
  end,
  ['基础屏托管按钮文字为"<按钮文字>"'] = function(w, a)
    local panel = w.bs_panel or {}
    return dsl.eq((panel.auto_label_by_player or {})[_rid(w)] or panel.auto_label, tostring(a["按钮文字"] or ""), "托管按钮文字")
  end,
  ["基础屏皮肤<节点>已隐藏"] = _skin_step(false),
  ["基础屏皮肤<节点>已展示"] = _skin_step(true),
  ["基础屏<入口>未被输入锁隐藏"] = _aux_step(function(w, node) return dsl.ne(_vis(w, node), false, node .. " 显隐") end),
  ["基础屏<入口>未被输入锁禁用"] = _aux_step(function(w, node) return dsl.eq(_tch(w, node), true, node .. " 触摸") end),
  ["基础屏行动按钮已展示且可点击"] = function(w) return _shown_touchable(w, base_nodes.action_button, "行动按钮") end,
  ["基础屏行动按钮已隐藏"] = function(w) return dsl.eq(_vis(w, base_nodes.action_button), false, "行动按钮显隐") end,
  ["基础屏结束按钮已隐藏"] = function(w) return dsl.eq(_vis(w, base_nodes.end_button), false, "结束按钮显隐") end,
  ["基础屏结束按钮已展示且可点击"] = function(w) return _shown_touchable(w, base_nodes.end_button, "结束按钮") end,
  ["基础屏取消按钮已隐藏"] = function(w) return dsl.eq(_vis(w, base_nodes.cancel_button), false, "取消按钮显隐") end,
  ["基础屏取消按钮已展示且可点击"] = function(w) return _shown_touchable(w, base_nodes.cancel_button, "取消按钮") end,
  ["基础屏结束按钮不额外写入文字"] = function(w)
    local ui = w.bs_render_state and w.bs_render_state.ui or {}
    return dsl.all(function() return dsl.eq(ui.buttons and ui.buttons[base_nodes.end_button], nil, "结束按钮 button 文字") end,
      function() return dsl.eq(ui.labels and ui.labels[base_nodes.end_button], nil, "结束按钮 label 文字") end)
  end,
  ["基础屏结束按钮不可派发完成可选行动阶段"] = function(w)
    if _tch(w, base_nodes.end_button) == true then return nil, "expected end button not touchable" end
    if w.bs_input_blocked == true or (w.bs_ui_model and w.bs_ui_model.choice) == nil then
      if _intent(w, base_nodes.end_button) ~= nil then return nil, "end button built an intent while blocked or without optional choice" end
    end
    return true
  end,
  ["基础屏行动按钮未作为可点击推进入口"] = function(w)
    if _tch(w, base_nodes.action_button) == true then return nil, "action button should not be touchable during optional action" end
    return dsl.eq(_intent(w, base_nodes.action_button), nil, "行动按钮推进意图")
  end,
  ["基础屏只展示被动当前回合提示"] = function(w)
    if _tch(w, base_nodes.action_button) == true then return nil, "passive view should not expose action touch" end
    return dsl.eq(_vis(w, base_nodes.end_button), false, "结束按钮显隐")
  end,
  -- ── 流程结果断言 ──────────────────────────────────────────────────
  ["玩家进入必经回合流程"] = function(w) return dsl.eq(w.bs_required_flow_started, true, "必经回合流程") end,
  ["玩家完成可选行动阶段"] = function(w) return dsl.eq(w.bs_optional_completed, true, "可选行动完成") end,
  ["当前待处理选择已按完成语义清除"] = function(w) return dsl.eq(w.bs_pending_cleared, true, "待处理选择清除") end,
  ["后续必经流程未被跳过"] = function(w) return dsl.ne(w.bs_followup_flow, nil, "后续必经流程") end,
  ["未触发基础屏行动按钮"] = function(w) return dsl.ne(w.bs_action_triggered, true, "行动按钮触发") end,
  ["可选行动阶段不会停在空选择入口"] = function(w) return dsl.eq(w.bs_ui_model and w.bs_ui_model.choice or nil, nil, "空选择入口") end,
  ["<可选行动>仍可作为主动选择入口"] = function(w, a)
    local choice = w.bs_ui_model and w.bs_ui_model.choice or nil
    return dsl.eq(choice and choice.meta and choice.meta.optional_action or nil, tostring(a["可选行动"] or ""), "可选行动入口")
  end,
  ["没有打开二次确认弹窗"] = function(w)
    local screen = w.bs_render_state and w.bs_render_state.ui and w.bs_render_state.ui.active_choice_screen_key
    if screen == "secondary_confirm" or w.bs_secondary_confirm_open == true then return nil, "secondary confirm should not open" end
    return true
  end,
  ["未派发通用结束动作"] = function(w)
    local intent = w.bs_end_intent or w.bs_action_intent
    if intent and intent.type == "ui_button" and (intent.id == "end" or intent.id == "end_turn") then return nil, "generic end action was dispatched" end
    return true
  end,
  ["回合继续到<后续流程>"] = function(w, a)
    local expected = tostring(a["后续流程"] or "")
    if expected == "必经流程" then return dsl.ne(w.bs_followup_flow, nil, "后续流程") end
    return dsl.eq(w.bs_followup_flow, expected, "后续流程")
  end,
  ["玩家投骰子并移动"] = function(w)
    return dsl.all(function() return dsl.eq(w.bs_dice_rolled, true, "投骰") end,
      function() return dsl.eq(w.bs_move_completed, true, "移动完成") end)
  end,
  ["玩家跳过 pre-action 道具使用"] = function(w)
    local action = w.bs_action_intent
    if action == nil or action.type ~= "ui_button" or action.id ~= "next" then return nil, "action button did not skip pre-action item phase" end
    w.bs_pre_action_skipped, w.bs_dice_rolled, w.bs_move_completed = true, true, true
    return true
  end,
  ["玩家跳过 post-action 道具使用"] = function(w)
    local action = w.bs_end_intent
    if action == nil or action.type ~= "complete_optional_action_phase" then return nil, "end button did not skip post-action item phase" end
    w.bs_post_action_skipped = true
    return true
  end,
  ["当前回合结束"] = function(w)
    if w.bs_turn_ended ~= true and w.bs_post_action_skipped ~= true then return nil, "turn was not ended" end
    return true
  end,
  ["轮到下一玩家"] = function(w)
    if w.bs_next_player ~= true and w.bs_turn_ended ~= true then return nil, "turn did not advance" end
    return true
  end,
  ["取消该道具的使用"] = function(w)
    local item = w.bs_engine_item
    if item == nil then return nil, "no engine item usage in play" end
    local result = w.bs_cancel_result
    if not (result and result.status == "applied") then
      return nil, "choice_cancel 未 applied: " .. tostring(result and result.status)
    end
    -- followup_cancel → reopen_or_finish:后续选择关闭,重开道具阶段窗。
    if _pending_slot_window(w) == nil then
      local pending = _engine_game(w).turn.pending_choice
      return nil, "取消后应回到道具阶段窗,实际 pending: " .. tostring(pending and pending.kind)
    end
    return true
  end,
  ["玩家回到<道具名>的道具使用阶段"] = function(w, a)
    local name = tostring(a["道具名"] or "")
    local item = w.bs_engine_item
    if item == nil or item.name ~= name then return nil, "engine item mismatch: " .. tostring(item and item.name) end
    if not (w.bs_cancel_result and w.bs_cancel_result.status == "applied") then
      return nil, "choice_cancel 未 applied: " .. tostring(w.bs_cancel_result and w.bs_cancel_result.status)
    end
    local pending = _pending_slot_window(w)
    if pending == nil then return nil, "未回到道具阶段窗" end
    if (pending.meta and pending.meta.phase) ~= item.phase then
      return nil, "重开窗阶段不符: " .. tostring(pending.meta and pending.meta.phase)
    end
    if not _slot_window_offers(pending, item.id) then
      return nil, name .. " 未重新出现在道具阶段窗选项中"
    end
    return true
  end,
  ["该道具未被消耗"] = function(w)
    local item = w.bs_engine_item
    if item == nil then return nil, "no engine item usage in play" end
    if not game_driver.has_item(w.driver, _engine_player(w), item.id) then
      return nil, "item was consumed: " .. item.name
    end
    return true
  end,
}, { name = "base_screen" })
