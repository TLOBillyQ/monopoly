-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,断言词汇从 luassert
-- 兼容层切到 lu.assertXxx,用例数与改写前一一对应(7 例)。
-- 2026-08-22 #543 口径反转:全来源统一「卡牌展示屏」弹窗广播,
-- 不再按 source 分流,item_get_reveal 图鉴放大卡私有展示链整条拆除。
local support = require("test.support.shared_support")
local gain_reveal = require("src.rules.items.gain_reveal")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")

local _assert_eq = support.assert_eq

local function _new_game()
  local g = support.new_game()
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  return g
end

local function _capture_popup(g)
  local captured = {}
  g.intent_output_port = { push_popup = function(_, payload, popup_opts)
    captured.payload, captured.popup_opts = payload, popup_opts
    return true
  end }
  return captured
end

local function _assert_gain_popup_payload(captured, player, item_id)
  local payload = assert(captured.payload, "gain should push card reveal popup")
  _assert_eq(payload.title, "道具卡", "gain popup title mismatch")
  _assert_eq(payload.kind, "item_card", "gain popup kind mismatch")
  _assert_eq(payload.image_ref, item_id, "gain popup image ref mismatch")
  _assert_eq(payload.broadcast, true, "gain popup should broadcast to all roles")
  _assert_eq(payload.auto_close_seconds, timing.item_get_reveal_seconds, "gain popup auto close mismatch")
  local cfg = inventory.cfg(item_id)
  _assert_eq(payload.body, player.name .. " 获得道具卡：" .. cfg.name .. "——" .. cfg.description,
    "gain popup body mismatch")
  _assert_eq(captured.popup_opts and captured.popup_opts.policy, "defer", "gain popup should defer behind active popup")
end

local function _assert_broadcast_anim(g, player, item_id, source)
  local anim = assert(g.turn.action_anim, "missing item gain popup anim")
  _assert_eq(anim.kind, "item_gain_popup", "gain anim kind mismatch")
  _assert_eq(anim.player_id, player.id, "reveal player mismatch")
  _assert_eq(anim.owner_role_id, player.id, "reveal owner role mismatch")
  _assert_eq(anim.item_id, item_id, "reveal item mismatch")
  _assert_eq(anim.item_name, inventory.item_name(item_id), "reveal item name mismatch")
  _assert_eq(anim.duration, timing.item_get_reveal_seconds, "reveal duration mismatch")
  _assert_eq(anim.source, source, "reveal source mismatch")
  _assert_eq(anim.broadcast, true, "gain reveal should broadcast to all roles")
end

TestGainReveal = {}

function TestGainReveal:setUp()
  require("test.support.config_reset").reset_all()
end

function TestGainReveal:test_item_tile_gain_pushes_broadcast_popup_and_queues_popup_anim()
  -- 踩道具地块来源:卡牌展示屏弹窗全员广播 + item_gain_popup 纯等待动画(CONTEXT「卡牌展示广播」 修订)。
  local g = _new_game()
  local player = g.players[1]
  local captured = _capture_popup(g)

  local queued = gain_reveal.queue(g, player, item_ids.free_rent, { source = "item_tile" })

  _assert_eq(queued, true, "realtime gain should queue reveal anim")
  _assert_broadcast_anim(g, player, item_ids.free_rent, "item_tile")
  _assert_gain_popup_payload(captured, player, item_ids.free_rent)
  _assert_eq(captured.payload.exclude_role_id, nil, "item tile reveal should not exclude any role")
end

function TestGainReveal:test_steal_source_gain_broadcasts_popup_to_all_roles()
  -- #543:偷窃来源不再维持图鉴放大卡私有展示,统一走卡牌展示屏弹窗全员广播;
  -- 获得者仍是偷窃者本人(正文与 owner_role_id 口径不变)。
  local g = _new_game()
  local player = g.players[1]
  local captured = _capture_popup(g)

  local queued = gain_reveal.queue(g, player, item_ids.free_rent, { source = "steal" })

  _assert_eq(queued, true, "steal gain should queue reveal anim")
  _assert_broadcast_anim(g, player, item_ids.free_rent, "steal")
  _assert_gain_popup_payload(captured, player, item_ids.free_rent)
end

function TestGainReveal:test_chance_source_gain_broadcasts_popup_to_all_roles()
  -- #543:机会卡发放来源同样统一广播,不再有「仅获得者可见」来源。
  local g = _new_game()
  local player = g.players[1]
  local captured = _capture_popup(g)

  local queued = gain_reveal.queue(g, player, item_ids.free_rent, { source = "chance" })

  _assert_eq(queued, true, "chance gain should queue reveal anim")
  _assert_broadcast_anim(g, player, item_ids.free_rent, "chance")
  _assert_gain_popup_payload(captured, player, item_ids.free_rent)
end

function TestGainReveal:test_market_source_gain_broadcasts_popup_to_all_roles()
  -- #543:黑市购买来源统一广播;market 取消路径按 source=="market" 识别
  -- 待播动画,source 字段必须原样保留。
  -- 2026-08-25 买家免展示口径:展示仍全员广播,但载荷置 exclude_role_id
  -- 排除买家本人,UI 按标志分发时跳过其 canvas(黑市屏全程不动)。
  local g = _new_game()
  local player = g.players[1]
  local captured = _capture_popup(g)

  local queued = gain_reveal.queue(g, player, item_ids.free_rent, { source = "market" })

  _assert_eq(queued, true, "market gain should queue reveal anim")
  _assert_broadcast_anim(g, player, item_ids.free_rent, "market")
  _assert_gain_popup_payload(captured, player, item_ids.free_rent)
  _assert_eq(captured.payload.exclude_role_id, player.id,
    "market purchase reveal should exclude the buyer from the broadcast display")
end

function TestGainReveal:test_sourceless_gain_also_broadcasts_popup()
  -- 无 source 的实时获得不再落入私有展示兜底,同样统一广播。
  local g = _new_game()
  local player = g.players[1]
  local captured = _capture_popup(g)

  local queued = gain_reveal.queue(g, player, item_ids.free_rent)

  _assert_eq(queued, true, "sourceless gain should queue reveal anim")
  local anim = assert(g.turn.action_anim, "missing gain popup anim")
  _assert_eq(anim.kind, "item_gain_popup", "sourceless gain anim kind mismatch")
  _assert_eq(anim.source, nil, "sourceless gain should keep nil source")
  _assert_eq(anim.broadcast, true, "sourceless gain should broadcast")
  _assert_gain_popup_payload(captured, player, item_ids.free_rent)
end

function TestGainReveal:test_preserves_gain_order_behind_current_source_animation()
  local g = _new_game()
  local player = g.players[1]
  g.turn.action_anim = { seq = 9, kind = "chance", player_id = player.id }
  g.turn.action_anim_seq = 9

  gain_reveal.queue(g, player, item_ids.free_rent, { source = "chance" })
  gain_reveal.queue(g, player, item_ids.roadblock, { source = "chance" })

  local queue = g.turn.action_anim_queue or {}
  _assert_eq(#queue, 2, "two gained items should be queued")
  _assert_eq(queue[1].kind, "item_gain_popup", "first queued reveal kind mismatch")
  _assert_eq(queue[1].item_id, item_ids.free_rent, "first reveal item mismatch")
  _assert_eq(queue[2].item_id, item_ids.roadblock, "second reveal item mismatch")
end

function TestGainReveal:test_does_not_queue_when_action_anim_gate_is_disabled()
  local g = support.new_game()
  local player = g.players[1]
  g.anim_gate_port = { wait_action_anim = false, wait_move_anim = false }
  local captured = _capture_popup(g)

  local queued = gain_reveal.queue(g, player, item_ids.free_rent)
  local queued_tile = gain_reveal.queue(g, player, item_ids.free_rent, { source = "item_tile" })

  _assert_eq(queued, false, "disabled gate should skip reveal anim")
  _assert_eq(queued_tile, false, "disabled gate should skip item tile reveal anim")
  _assert_eq(g.turn.action_anim, nil, "disabled gate should not set current anim")
  _assert_eq(#(g.turn.action_anim_queue or {}), 0, "disabled gate should not append queue")
  _assert_eq(captured.payload, nil, "disabled gate should not push gain popup")
end

function TestGainReveal:test_does_not_queue_when_required_context_is_missing()
  local g = _new_game()
  local player = g.players[1]

  _assert_eq(gain_reveal.queue(nil, player, item_ids.free_rent), false, "missing game should skip reveal")
  _assert_eq(gain_reveal.queue(g, nil, item_ids.free_rent), false, "missing player should skip reveal")
  _assert_eq(gain_reveal.queue(g, player, nil), false, "missing item should skip reveal")
  _assert_eq(g.turn.action_anim, nil, "invalid reveal context should not queue current anim")
  _assert_eq(#(g.turn.action_anim_queue or {}), 0, "invalid reveal context should not append queue")
end

function TestGainReveal:test_plain_inventory_give_with_game_context_does_not_trigger_reveal()
  local g = _new_game()
  local player = g.players[1]

  local ok = inventory.give(player, item_ids.free_rent, { game = g })

  _assert_eq(ok, true, "inventory give should still add item")
  _assert_eq(g.turn.action_anim, nil, "plain inventory give should not queue reveal")
  _assert_eq(#(g.turn.action_anim_queue or {}), 0, "plain inventory give should not enqueue reveal")
end


return TestGainReveal
