-- [DEBUG-rf01] 全链路复现:真实 gameplay_loop.tick + 真实 choice/modal 超时步进
-- + 真实 need_choice 消费者 + 真实触控输入管线(输入锁/槽位预确认)。
-- 剧本:同回合 2 查税 + 1 财神后,最后一张查税是否可用。
local lu = require("luaunit")
local fixtures = require("test.support.gameplay_fixtures")
local support = require("test.support.shared_support")
local gameplay_loop = require("src.turn.loop")
local ChoiceTimeout = require("src.turn.waits.choice_timeout")
local modal_timeout = require("src.turn.waits.modal_timeout")
local monopoly_event = require("src.foundation.events")
local runtime_event_ports = require("src.ui.ports.events")
local item_ids = require("src.config.gameplay.item_ids")
local ui_intent = require("src.ui.input.intent_dispatcher")

local function _has_option(choice, option_id)
  for _, option in ipairs(choice and choice.options or {}) do
    if option.id == option_id then return true end
  end
  return false
end

TestReproFullLoopRichReopen = {}

function TestReproFullLoopRichReopen:test_window_after_rich_use_stays_interactive()
  local g = support.new_game()
  local state = fixtures.build_loop_state()
  -- 生产真身端口组:真实 modal/ui_sync(reconcile 安全网),动画桩给真实时长
  local presentation_ports = require("src.ui.ports.init")
  local prod_ports = presentation_ports.build()
  prod_ports.anim.play_action_anim = function() return 2.0 end
  prod_ports.anim.play_move_anim = function() return 0 end
  prod_ports.anim.reset_status_3d = function() end
  prod_ports.anim.sync_status_3d = function() end
  prod_ports.ui_sync.step_choice_timeout = function(game, s, dt)
    ChoiceTimeout.step_default(game, s, dt)
  end
  prod_ports.ui_sync.step_modal_timeout = function(game, s, dt)
    modal_timeout.step_default(game, s, dt)
  end
  state.gameplay_loop_ports = prod_ports
  state._resolved_gameplay_loop_ports = nil

  -- 真实渲染需要 board_scene 锚点:按棋盘长度给足桩 tile
  local tiles = {}
  for i = 1, g.board:length() do
    tiles[i] = { get_position = function() return math.Vector3(i * 1.0, 0.0, 0.0) end }
  end
  state.board_scene = { tiles = tiles, buildings = {}, units_by_player_id = {} }
  -- 真机动画门是开的:用卡会排 item_use 兜底动画,续开走「动画收尾回 wait_choice」路径
  state.wait_action_anim = true
  state.wait_move_anim = true

  -- 纯视图渲染打桩(需要完整宿主节点),modal 开合 / reconcile 判定保持真身
  local main_view = require("src.ui.coord.ui_runtime")
  local old_render = main_view.render
  main_view.render = function() end

  -- 生产 gameplay_start 安装的 turn_action_port(输入派发/静默拦截同源)
  local turn_dispatch = require("src.turn.actions.action_dispatcher")
  state.turn_action_port = {
    dispatch_action = function(game_, state_, action, opts)
      return turn_dispatch.dispatch_action(game_, state_, action, opts)
    end,
    should_block_action = function(state_, action_or_type)
      return turn_dispatch.should_block_action(state_, action_or_type)
    end,
  }

  gameplay_loop.set_game(state, g)
  local player = g:current_player()
  player.inventory:add({ id = item_ids.tax })
  player.inventory:add({ id = item_ids.tax })
  player.inventory:add({ id = item_ids.tax })
  player.inventory:add({ id = item_ids.rich })

  -- 接回真实 need_choice 消费者(spec 假宿主不派发全局事件)
  local old_emit = monopoly_event.emit_intent
  monopoly_event.emit_intent = function(kind, payload)
    old_emit(kind, payload)
    if kind == "need_choice" then
      local ok, err = pcall(runtime_event_ports.on_need_choice, state, function() return g end, payload)
      lu.assertTrue(ok, "on_need_choice error: " .. tostring(err))
    end
  end

  local function _tick(total, dt)
    dt = dt or 0.1
    local t = 0
    while t < total do
      gameplay_loop.tick(g, state, dt)
      t = t + dt
    end
  end

  local function _dump(_) end

  -- 真实输入管线:走 intent_dispatcher(含 should_block 输入锁与槽位预确认)
  local function _tap(intent)
    intent.actor_role_id = player.id
    ui_intent.dispatch(state, g, intent)
  end

  -- 槽位 → 道具由 turn 层直读行动者背包(展示层镜像已退场),这里按同一口径
  -- 从真实背包定位槽位号:展示序就是背包序(item_slice 密排,背包 table.remove 保序)。
  local item_slice = require("src.ui.view.item_slice")
  local function _slot_index_of(item_id)
    local filled = item_slice.build_item_slots_for_player(player, 5)
    for i = 1, 5 do
      if filled[i] == item_id then return i end
    end
    return nil
  end

  -- 点槽位 → 预确认屏 → 确认(与真机操作同路)
  local function _use_slot(item_id, tag)
    local idx = _slot_index_of(item_id)
    lu.assertNotNil(idx, "USER SYMPTOM(" .. tag .. "): no tappable slot for item " ..
      tostring(item_id) .. " in cached ui_model — slots dead until countdown")
    local before = g.turn.pending_choice and g.turn.pending_choice.id
    _tap({ type = "item_slot_click", slot_index = idx })
    local pc = g.turn.pending_choice
    if pc and pc.id == before then
      -- 预确认屏路径:再点一次确认
      _tap({ type = "choice_select", choice_id = pc.id, option_id = item_id })
    end
    local after = g.turn.pending_choice and g.turn.pending_choice.id
    lu.assertNotEquals(after, before, "USER SYMPTOM(" .. tag .. "): slot tap+confirm did not advance the window " ..
      "(tap swallowed; user can only wait for countdown)")
  end

  -- 目标选择 modal:直接点目标(必要时二次确认)
  local function _pick_target(tag)
    local followup = assert(g.turn.pending_choice, tag .. ": target choice missing")
    lu.assertNotEquals(followup.kind, "item_phase_passive", tag .. ": expected followup, got passive")
    local option_id = followup.options[1].id
    _tap({ type = "choice_select", choice_id = followup.id, option_id = option_id })
    if g.turn.pending_choice and g.turn.pending_choice.id == followup.id then
      _tap({ type = "choice_select", choice_id = followup.id, option_id = option_id })
    end
    lu.assertEvalToTrue(not (g.turn.pending_choice and g.turn.pending_choice.id == followup.id),
      tag .. ": target selection did not resolve")
  end

  -- 起手:启动回合脚本并 tick 到道具窗口开出
  g:advance_turn()
  _tick(1.0)
  _dump("after boot")
  local pc = assert(g.turn.pending_choice, "item window should open")
  lu.assertEquals(pc.kind, "item_phase_passive", "expected passive, got " .. tostring(pc.kind))

  -- 查税 1(思考 4s,目标 3s)
  _tick(4.0); _use_slot(item_ids.tax, "tax1")
  _tick(3.0); _pick_target("tax1")
  _tick(3.0); _dump("after tax1")

  -- 查税 2(思考 3s,目标 2s)
  lu.assertEvalToTrue(g.turn.pending_choice and g.turn.pending_choice.kind == "item_phase_passive",
    "passive should reopen after tax1")
  _use_slot(item_ids.tax, "tax2")
  _tick(2.0); _pick_target("tax2")
  _tick(3.0); _dump("after tax2")

  -- 财神
  lu.assertEvalToTrue(g.turn.pending_choice and g.turn.pending_choice.kind == "item_phase_passive",
    "passive should reopen after tax2")
  _use_slot(item_ids.rich, "rich")
  _tick(3.0); _dump("after rich settle")

  local reopened = g.turn.pending_choice
  lu.assertNotNil(reopened, "window should reopen after rich use")
  lu.assertEquals(reopened.kind, "item_phase_passive", "reopened should be passive, got " .. tostring(reopened.kind))
  lu.assertEvalToTrue(_has_option(reopened, item_ids.tax), "last tax should be listed")
  local reopened_id = reopened.id

  -- 自身只显示 3s,不得被跨窗口累计超时关闭
  _tick(3.0); _dump("after 3s on reopened")
  local still = g.turn.pending_choice
  lu.assertEvalToTrue(still ~= nil and still.id == reopened_id,
    "reopened window must stay open (user symptom: locked until turn-end countdown)")

  -- 用户症状面:最后一张查税必须还能通过真实触控用出去
  _use_slot(item_ids.tax, "tax3-after-rich")
  _tick(0.5)
  lu.assertNotNil(g.turn.pending_choice, "tax target choice should open for the last tax")
  _dump("after tax3 slot tap")

  monopoly_event.emit_intent = old_emit
  main_view.render = old_render
end


return TestReproFullLoopRichReopen
