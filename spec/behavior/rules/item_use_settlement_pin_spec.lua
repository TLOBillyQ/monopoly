---@diagnostic disable: redundant-parameter
-- 道具使用结果结算 pin spec(深化迁移 step 0)
-- 在 settlement 深模块落地前,把散布在 executor/handlers/use_flow_resolvers 的
-- 结算行为(成功判定、消耗时机、广播/遥测恰好一次、留卡语义)按 类别×路径 钉死。
-- fixture 一律经真实 begin/resolve 路径构造;禁止手搓 choice.meta(假绿风险)。
local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local availability = require("src.rules.items.availability")
local choice_resolver = require("src.rules.choice.resolver")
local demolish = require("src.rules.items.demolish")
local item_ids = require("src.config.gameplay.item_ids")
local post_effects = require("src.rules.items.post_effects")
local remote_dice = require("src.rules.items.remote_dice")
local use_flow = require("src.rules.items.use_flow")

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _new_game()
  return support.new_game({ map = default_map })
end

local function _count_item(player, item_id)
  local count = 0
  for _, item in ipairs(player.inventory.items or {}) do
    if item.id == item_id then
      count = count + 1
    end
  end
  return count
end

-- 广播(item_card popup)与成就遥测(item_used)的按局探针。
-- use_broadcast 经 game.intent_output_port.push_popup 出口;成就经 game.achievement_progress_port。
local function _install_probes(game)
  local probes = { item_card_popups = 0, item_used_events = 0, opened_choice_specs = {} }
  game.achievement_progress_port = {
    item_used = function()
      probes.item_used_events = probes.item_used_events + 1
      return true
    end,
  }
  game.intent_output_port = {
    push_popup = function(_, payload)
      if type(payload) == "table" and payload.kind == "item_card" then
        probes.item_card_popups = probes.item_card_popups + 1
      end
      return true
    end,
    open_choice = function(_, choice_spec)
      probes.opened_choice_specs[#probes.opened_choice_specs + 1] = choice_spec
      return true
    end,
  }
  return probes
end

local function _with_patches(patches, fn)
  local previous = {}
  for index, patch in ipairs(patches) do
    previous[index] = patch.target[patch.key]
    patch.target[patch.key] = patch.value
  end
  local ok, result = pcall(fn)
  for index = #patches, 1, -1 do
    local patch = patches[index]
    patch.target[patch.key] = previous[index]
  end
  if not ok then
    error(result, 0)
  end
  return result
end

local function _select_action(choice, option_id, actor_role_id)
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = option_id,
    actor_role_id = actor_role_id,
  }
end

-- 经真实 item_phase_choice 注册表 handler 构造预消耗 followup(禁止手搓 meta)。
-- availability 收窄 patch 是唯一 stub:live 三个 phase 全部 repeatable,
-- 非重复分支今天只能经此进入,与被钉的消耗语义正交。
local function _open_preconsumed_followup(game, player, item_id, probes)
  local phase_choice = support.open_choice(game, {
    kind = "item_phase_choice",
    options = { { id = item_id, label = "道具" } },
    meta = { player_id = player.id, phase = "landing" },
  })
  _with_patches({
    {
      target = availability,
      key = "can_offer_in_phase",
      value = function()
        return true, "ok"
      end,
    },
  }, function()
    choice_resolver.resolve(game, phase_choice, { option_id = item_id })
  end)
  local followup_spec = probes.opened_choice_specs[#probes.opened_choice_specs]
  assert(followup_spec ~= nil, "preconsumed followup choice spec should be dispatched")
  return followup_spec
end

describe("item_use_settlement_pins", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  -- 类别:简单 post 道具 · 路径:begin(人类)
  it("post item consumes before apply and broadcasts exactly once", function()
    local g = _new_game()
    local player = g.players[1]
    local probes = _install_probes(g)
    player.inventory:add({ id = item_ids.free_rent })
    local count_at_apply = nil

    _with_patches({
      {
        target = post_effects,
        key = "apply_post",
        value = function(_, apply_player)
          count_at_apply = _count_item(apply_player, item_ids.free_rent)
          return true
        end,
      },
    }, function()
      local result = use_flow.begin_item_use(g, player.id, item_ids.free_rent, {})

      _assert_eq(result.ok, true, "post item should apply")
      _assert_eq(result.status, "applied", "post item status")
      _assert_eq(result.item_consumed, true, "post item should report consumed")
    end)

    _assert_eq(count_at_apply, 0, "post item must be consumed before apply runs")
    _assert_eq(_count_item(player, item_ids.free_rent), 0, "post item should leave inventory")
    _assert_eq(probes.item_card_popups, 1, "post item should broadcast exactly once")
    _assert_eq(probes.item_used_events, 1, "post item should report telemetry exactly once")
  end)

  -- 类别:遥控骰子 · 路径:begin(AI 即时 apply)
  it("ai remote dice consumes before apply and broadcasts exactly once", function()
    local g = _new_game()
    local player = g.players[1]
    local probes = _install_probes(g)
    player.inventory:add({ id = item_ids.remote_dice })
    g.auto_play_port = {
      pick_remote_dice_value = function()
        return 4
      end,
    }
    local count_at_apply = nil

    _with_patches({
      {
        target = remote_dice,
        key = "apply",
        value = function(_, apply_player)
          count_at_apply = _count_item(apply_player, item_ids.remote_dice)
          return { ok = true }
        end,
      },
    }, function()
      local result = use_flow.begin_item_use(g, player.id, item_ids.remote_dice, { by_ai = true })

      _assert_eq(result.ok, true, "ai remote dice should apply")
      _assert_eq(result.status, "applied", "ai remote dice status")
    end)

    _assert_eq(count_at_apply, 0, "ai remote dice must be consumed before apply runs")
    _assert_eq(probes.item_card_popups, 1, "ai remote dice should broadcast exactly once")
    _assert_eq(probes.item_used_events, 1, "ai remote dice should report telemetry exactly once")
  end)

  -- 类别:目标玩家道具 · 路径:begin 等待选择
  it("waiting choice never consumes broadcasts or reports telemetry", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    local probes = _install_probes(g)
    user.inventory:add({ id = item_ids.steal })
    target.inventory:add({ id = item_ids.roadblock })

    local result = use_flow.begin_item_use(g, user.id, item_ids.steal, { phase = "pre_action" })

    _assert_eq(result.status, "waiting_choice", "steal begin should wait for target")
    _assert_eq(result.item_consumed, false, "waiting must not consume")
    _assert_eq(_count_item(user, item_ids.steal), 1, "steal card should remain while waiting")
    _assert_eq(probes.item_card_popups, 0, "waiting must not broadcast")
    _assert_eq(probes.item_used_events, 0, "waiting must not report telemetry")
  end)

  -- 类别:目标玩家道具 · 路径:choice 取消
  it("cancelling a target choice retains the item without broadcast", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    local probes = _install_probes(g)
    user.inventory:add({ id = item_ids.steal })
    target.inventory:add({ id = item_ids.roadblock })

    local begin_result = use_flow.begin_item_use(g, user.id, item_ids.steal, { phase = "pre_action" })
    local choice = support.open_choice(g, begin_result.choice_spec)
    choice_resolver.resolve(g, choice, { type = "choice_cancel", choice_id = choice.id })

    _assert_eq(_count_item(user, item_ids.steal), 1, "cancelled choice should retain the item")
    _assert_eq(probes.item_card_popups, 0, "cancelled choice must not broadcast")
    _assert_eq(probes.item_used_events, 0, "cancelled choice must not report telemetry")
  end)

  -- 类别:偷窃(applier 自耗) · 路径:resolve(经 executor 重入)
  it("steal resolve broadcasts exactly once and consumes exactly one card", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    local probes = _install_probes(g)
    user.inventory:add({ id = item_ids.steal })
    target.inventory:add({ id = item_ids.roadblock })

    local begin_result = use_flow.begin_item_use(g, user.id, item_ids.steal, { phase = "pre_action" })
    local choice = support.open_choice(g, begin_result.choice_spec)
    local result = use_flow.resolve_item_use_choice(g, choice, _select_action(choice, target.id, user.id))

    _assert_eq(result.ok, true, "steal resolve should apply")
    _assert_eq(result.item_consumed, true, "steal resolve should report consumed")
    _assert_eq(_count_item(user, item_ids.steal), 0, "steal card should be consumed")
    _assert_eq(_count_item(user, item_ids.roadblock), 1, "stolen item should arrive")
    _assert_eq(_count_item(target, item_ids.roadblock), 0, "target should lose the stolen item")
    _assert_eq(probes.item_card_popups, 1, "steal resolve should broadcast exactly once")
    _assert_eq(probes.item_used_events, 1, "steal resolve should report telemetry exactly once")
  end)

  -- 类别:偷窃 · 路径:resolve,背包已满(is_full 检查先于自耗腾格)
  it("steal against a full bag rejects with bag_full and retains the card", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    local probes = _install_probes(g)
    user.inventory:add({ id = item_ids.steal })
    while not user.inventory:is_full() do
      user.inventory:add({ id = item_ids.roadblock })
    end
    target.inventory:add({ id = item_ids.mine })

    local begin_result = use_flow.begin_item_use(g, user.id, item_ids.steal, { phase = "pre_action" })
    local choice = support.open_choice(g, begin_result.choice_spec)
    local result = use_flow.resolve_item_use_choice(g, choice, _select_action(choice, target.id, user.id))

    _assert_eq(result.ok, false, "full bag steal should reject")
    _assert_eq(result.reason, "bag_full", "full bag steal reason")
    _assert_eq(_count_item(user, item_ids.steal), 1, "full bag steal should retain the card")
    _assert_eq(_count_item(target, item_ids.mine), 1, "full bag steal must not take the item")
    _assert_eq(probes.item_card_popups, 0, "rejected steal must not broadcast")
    _assert_eq(probes.item_used_events, 0, "rejected steal must not report telemetry")
  end)

  -- 类别:目标玩家道具 · 路径:resolve(apply 成功后才消耗)
  it("target item consumes only after successful apply", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    local probes = _install_probes(g)
    user.inventory:add({ id = item_ids.exile })
    local count_at_apply = nil

    _with_patches({
      {
        target = post_effects,
        key = "apply_target",
        value = function(_, apply_user)
          count_at_apply = _count_item(apply_user, item_ids.exile)
          return { ok = true }
        end,
      },
    }, function()
      local begin_result = use_flow.begin_item_use(g, user.id, item_ids.exile, { phase = "pre_action" })
      local choice = support.open_choice(g, begin_result.choice_spec)
      local result = use_flow.resolve_item_use_choice(g, choice, _select_action(choice, target.id, user.id))

      _assert_eq(result.ok, true, "target item resolve should apply")
      _assert_eq(result.item_consumed, true, "target item resolve should report consumed")
    end)

    _assert_eq(count_at_apply, 1, "target item must still be held while apply runs")
    _assert_eq(_count_item(user, item_ids.exile), 0, "target item should be consumed after apply")
    _assert_eq(probes.item_card_popups, 1, "target item resolve should broadcast exactly once")
    _assert_eq(probes.item_used_events, 1, "target item resolve should report telemetry exactly once")
  end)

  -- 类别:目标玩家道具 · 路径:resolve,apply 失败(留卡、零广播)
  it("failed target apply retains the item and never broadcasts", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    local probes = _install_probes(g)
    user.inventory:add({ id = item_ids.exile })

    _with_patches({
      {
        target = post_effects,
        key = "apply_target",
        value = function()
          return { ok = false, reason = "blocked" }
        end,
      },
    }, function()
      local begin_result = use_flow.begin_item_use(g, user.id, item_ids.exile, { phase = "pre_action" })
      local choice = support.open_choice(g, begin_result.choice_spec)
      local result = use_flow.resolve_item_use_choice(g, choice, _select_action(choice, target.id, user.id))

      _assert_eq(result.ok, false, "failed target apply should reject")
      _assert_eq(result.reason, "blocked", "failed target apply reason")
      _assert_eq(result.item_consumed, false, "failed target apply must not report consumed")
    end)

    _assert_eq(_count_item(user, item_ids.exile), 1, "failed target apply should retain the item")
    _assert_eq(probes.item_card_popups, 0, "failed target apply must not broadcast")
    _assert_eq(probes.item_used_events, 0, "failed target apply must not report telemetry")
  end)

  -- 类别:遥控骰子 · 路径:resolve(人类)
  it("remote dice resolve broadcasts exactly once and consumes exactly one card", function()
    local g = _new_game()
    local user = g.players[1]
    local probes = _install_probes(g)
    user.inventory:add({ id = item_ids.remote_dice })

    local begin_result = use_flow.begin_item_use(g, user.id, item_ids.remote_dice, { phase = "pre_action" })
    _assert_eq(begin_result.status, "waiting_choice", "remote dice begin should wait")
    local choice = support.open_choice(g, begin_result.choice_spec)
    local result = use_flow.resolve_item_use_choice(g, choice, _select_action(choice, 4, user.id))

    _assert_eq(result.ok, true, "remote dice resolve should apply")
    _assert_eq(_count_item(user, item_ids.remote_dice), 0, "remote dice should consume exactly one card")
    _assert_eq(probes.item_card_popups, 1, "remote dice resolve should broadcast exactly once")
    _assert_eq(probes.item_used_events, 1, "remote dice resolve should report telemetry exactly once")
  end)

  -- 类别:路障 · 路径:resolve(真实 roadblock.apply)
  it("roadblock resolve broadcasts exactly once and consumes exactly one card", function()
    local g = _new_game()
    local user = g.players[1]
    local probes = _install_probes(g)
    user.inventory:add({ id = item_ids.roadblock })

    local begin_result = use_flow.begin_item_use(g, user.id, item_ids.roadblock, { phase = "pre_action" })
    _assert_eq(begin_result.status, "waiting_choice", "roadblock begin should wait")
    local choice = support.open_choice(g, begin_result.choice_spec)
    local first_option = choice.options[1]
    local result = use_flow.resolve_item_use_choice(g, choice,
      _select_action(choice, first_option.id or first_option, user.id))

    _assert_eq(result.ok, true, "roadblock resolve should apply")
    _assert_eq(_count_item(user, item_ids.roadblock), 0, "roadblock should consume exactly one card")
    _assert_eq(probes.item_card_popups, 1, "roadblock resolve should broadcast exactly once")
    _assert_eq(probes.item_used_events, 1, "roadblock resolve should report telemetry exactly once")
  end)

  -- 类别:拆除(怪兽) · 路径:resolve 漏斗(resolver 消耗先于 apply)
  it("demolish resolve consumes before apply and broadcasts exactly once", function()
    local g = _new_game()
    local user = g.players[1]
    local probes = _install_probes(g)
    user.inventory:add({ id = item_ids.monster })
    local count_at_apply = nil

    _with_patches({
      {
        target = demolish,
        key = "apply",
        value = function(_, apply_player)
          count_at_apply = _count_item(apply_player, item_ids.monster)
          return { ok = true }
        end,
      },
    }, function()
      local choice = support.open_choice(g, {
        kind = "demolish_target",
        options = { { id = 12, label = "目标" } },
        meta = { player_id = user.id, item_id = item_ids.monster },
      })
      local result = use_flow.resolve_item_use_choice(g, choice, _select_action(choice, 12, user.id))

      _assert_eq(result.ok, true, "demolish resolve should apply")
    end)

    _assert_eq(count_at_apply, 0, "demolish must be consumed before apply runs")
    _assert_eq(_count_item(user, item_ids.monster), 0, "demolish should consume exactly one card")
    _assert_eq(probes.item_card_popups, 1, "demolish resolve should broadcast exactly once")
    _assert_eq(probes.item_used_events, 1, "demolish resolve should report telemetry exactly once")
  end)

  -- 类别:预消耗(非重复阶段) · 路径:真实 item_phase_choice handler → followup resolve
  it("preconsumed followup consumes at choice open and resolves without double consume", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    local probes = _install_probes(g)
    user.inventory:add({ id = item_ids.exile })

    _with_patches({
      {
        target = post_effects,
        key = "apply_target",
        value = function()
          return { ok = true }
        end,
      },
    }, function()
      local followup_spec = _open_preconsumed_followup(g, user, item_ids.exile, probes)

      _assert_eq(_count_item(user, item_ids.exile), 0, "non-repeatable phase item must preconsume at choice open")
      _assert_eq(followup_spec.meta.item_preconsumed, true, "followup must carry preconsumed marker")
      _assert_eq(followup_spec.allow_cancel, false, "preconsumed followup must disable cancel")
      _assert_eq(probes.item_card_popups, 0, "preconsume must not broadcast before resolve")

      local choice = support.open_choice(g, followup_spec)
      local result = use_flow.resolve_item_use_choice(g, choice, _select_action(choice, target.id, user.id))

      _assert_eq(result.ok, true, "preconsumed followup resolve should apply")
      _assert_eq(result.item_consumed, true, "preconsumed followup should report consumed")
    end)

    _assert_eq(_count_item(user, item_ids.exile), 0, "resolve must not consume a second card")
    _assert_eq(probes.item_card_popups, 1, "preconsumed resolve should broadcast exactly once")
    _assert_eq(probes.item_used_events, 1, "preconsumed resolve should report telemetry exactly once")
  end)

  -- 潜伏缺陷 #4(本 pin 起草时发现):旧偷窃卡在 apply 内部无条件自耗,
  -- 无视 item_preconsumed 标志——预消耗的偷窃 followup 在 resolve 时二次消耗,
  -- 命中 inventory.lua 的 missing item 断言直接崩溃。settlement 深化后偷窃
  -- 经台账 commit 自耗(escrow 已入账则空转),此组合自然修复。
  it("preconsumed steal followup resolves without crashing", function()
    local g = _new_game()
    local user = g.players[1]
    local target = g.players[2]
    local probes = _install_probes(g)
    user.inventory:add({ id = item_ids.steal })
    target.inventory:add({ id = item_ids.mine })

    local followup_spec = _open_preconsumed_followup(g, user, item_ids.steal, probes)
    local choice = support.open_choice(g, followup_spec)
    local result = use_flow.resolve_item_use_choice(g, choice, _select_action(choice, target.id, user.id))

    _assert_eq(result.ok, true, "preconsumed steal resolve should apply")
    _assert_eq(_count_item(user, item_ids.steal), 0, "steal must consume exactly one card in total")
    _assert_eq(_count_item(user, item_ids.mine), 1, "stolen item should arrive")
  end)
end)
