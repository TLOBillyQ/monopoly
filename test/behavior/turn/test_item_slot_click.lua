-- 道具槽点击的唯一裁定：每一条非放行路径都必须有反馈，一条静默分支都不许有。
-- 老设计把裁定切成 UI / turn 两半，两次猜测口径不一致时点击落进夹缝——本 spec
-- 逐条钉死新裁定的分支与其反馈。
local lu = require("luaunit")
local item_slot_click = require("src.turn.actions.item_slot_click")
local denial_cfg = require("src.config.content.item_slot_denial")

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. " got " .. tostring(actual))
end

local function _player(id, item_ids)
  local items = {}
  for index, item_id in ipairs(item_ids or {}) do
    items[index] = { id = item_id }
  end
  return { id = id, inventory = { items = items } }
end

-- 最小真实形状的 game：players + turn.current_player_index + find_player_by_id,
-- 提示经 tip_output_port 捕获（与生产同一条端口）。
local function _game(opts)
  local players = opts.players
  local captured = {}
  local game = {
    players = players,
    turn = {
      current_player_index = opts.current_player_index or 1,
      pending_choice = opts.pending_choice,
      used_effect_groups = opts.used_effect_groups or {},
    },
    tip_output_port = { enqueue = function(_, intent) captured[#captured + 1] = intent return true end },
  }
  function game:find_player_by_id(role_id)
    for _, player in ipairs(self.players) do
      if player.id == role_id then
        return player
      end
    end
    return nil
  end
  return game, captured
end

local function _item_window(owner_role_id, option_ids, phase)
  local options = {}
  for index, option_id in ipairs(option_ids) do
    options[index] = { id = option_id }
  end
  return {
    id = "win_" .. tostring(owner_role_id),
    kind = "item_phase_passive",
    uses_item_slots = true,
    owner_role_id = owner_role_id,
    options = options,
    meta = { phase = phase or "pre_action", player_id = owner_role_id },
  }
end

local function _click(game, actor_role_id, slot_index)
  return item_slot_click.resolve(game, {
    type = "item_slot_click",
    slot_index = slot_index,
    actor_role_id = actor_role_id,
    input_source = "touch",
  })
end

TestItemSlotClick = {}

TestItemSlotClick["test_空槽位静默：不发提示、不派发"] = function(self)
  local game, tips = _game({ players = { _player(1, {}) } })
  local result = _click(game, 1, 1)
  _assert_eq(result.status, "empty", "empty slot status")
  _assert_eq(#tips, 0, "empty slot must stay silent")
end

TestItemSlotClick["test_玩家没有 inventory：点槽位视作空槽静默"] = function(self)
  local game, tips = _game({ players = { { id = 1 } } })
  local result = _click(game, 1, 1)
  _assert_eq(result.status, "empty", "missing inventory should read as an empty slot")
  _assert_eq(#tips, 0, "missing inventory must stay silent")
end

TestItemSlotClick["test_他人回合点自己的卡：拒绝并提示阶段不合法"] = function(self)
  local game, tips = _game({
    players = { _player(1, { "item_a" }), _player(2, {}) },
    current_player_index = 2,
  })
  local result = _click(game, 1, 1)
  _assert_eq(result.status, "denied", "off-turn click must be denied")
  _assert_eq(result.reason, "not_current_turn", "off-turn reason")
  _assert_eq(#tips, 1, "off-turn click must be tipped")
  _assert_eq(tips[1].text, denial_cfg.PHASE_DENIED_TEXT, "off-turn tip text")
  _assert_eq(tips[1].role_id, 1, "denial tip must target the clicker")
end

TestItemSlotClick["test_对手开着道具窗时点自己的卡：不借对手的窗放行,照常提示"] = function(self)
  local game, tips = _game({
    players = { _player(1, { "item_a" }), _player(2, { "item_b" }) },
    current_player_index = 2,
    pending_choice = _item_window(2, { "item_b" }),
  })
  local result = _click(game, 1, 1)
  _assert_eq(result.status, "denied", "another player's window must not admit this click")
  _assert_eq(#tips, 1, "click must still be tipped")
end

TestItemSlotClick["test_自己回合但没有道具窗：拒绝并提示阶段不合法"] = function(self)
  local game, tips = _game({ players = { _player(1, { "item_a" }) } })
  local result = _click(game, 1, 1)
  _assert_eq(result.status, "denied", "no window means denied")
  _assert_eq(result.reason, "no_item_window", "no window reason")
  _assert_eq(tips[1] and tips[1].text, denial_cfg.PHASE_DENIED_TEXT, "no window tip text")
end

TestItemSlotClick["test_窗开着但点的卡不在 offer 里：按 availability 拒因给具体文案"] = function(self)
  local avail = require("src.rules.items.availability")
  local saved = avail.can_offer_in_phase
  avail.can_offer_in_phase = function() return false, "insufficient_funds" end
  local game, tips = _game({
    players = { _player(1, { "item_a", "item_b" }) },
    pending_choice = _item_window(1, { "item_b" }),
  })
  local result = _click(game, 1, 1)
  avail.can_offer_in_phase = saved
  _assert_eq(result.status, "denied", "unofferable card must be denied")
  _assert_eq(result.reason, "insufficient_funds", "reason should come from availability")
  _assert_eq(tips[1] and tips[1].text, denial_cfg.INSUFFICIENT_FUNDS_TEXT, "reason-specific tip text")
end

TestItemSlotClick["test_拒因分类不出时走通用文案,不冒充具体原因"] = function(self)
  local avail = require("src.rules.items.availability")
  local saved = avail.can_offer_in_phase
  avail.can_offer_in_phase = function() return true end
  local game, tips = _game({
    players = { _player(1, { "item_a", "item_b" }) },
    pending_choice = _item_window(1, { "item_b" }),
  })
  local result = _click(game, 1, 1)
  avail.can_offer_in_phase = saved
  _assert_eq(result.reason, "unknown", "unclassifiable denial reason")
  _assert_eq(tips[1] and tips[1].text, denial_cfg.GENERIC_DENIED_TEXT, "generic tip text")
end

TestItemSlotClick["test_可用的卡放行成 choice_select,不发提示"] = function(self)
  local game, tips = _game({
    players = { _player(1, { "item_a" }) },
    pending_choice = _item_window(1, { "item_a" }),
  })
  local result = _click(game, 1, 1)
  _assert_eq(result.status, "select", "offerable card must be admitted")
  _assert_eq(result.action.type, "choice_select", "admitted action type")
  _assert_eq(result.action.choice_id, "win_1", "admitted choice id")
  _assert_eq(result.action.option_id, "item_a", "admitted option id")
  _assert_eq(result.action.input_source, "touch", "input_source carried through")
  _assert_eq(#tips, 0, "admitted click must not raise a tip")
end

TestItemSlotClick["test_槽位索引按行动者真实背包解析,不经任何 UI 镜像"] = function(self)
  local game = _game({
    players = { _player(1, { "item_a", "item_b", "item_c" }) },
    pending_choice = _item_window(1, { "item_c" }),
  })
  local result = _click(game, 1, 3)
  _assert_eq(result.status, "select", "third slot should resolve to the third bag entry")
  _assert_eq(result.action.option_id, "item_c", "slot index maps to bag index")
end

TestItemSlotClick["test_空洞槽位不打断索引恒等:洞静默、洞后卡仍按原槽位解析"] = function(self)
  -- CONTEXT「道具槽位」:背包空洞以 false 占位,槽位 i 恒等于背包第 i 格。
  local player = { id = 1, inventory = { items = { { id = "item_a" }, false, { id = "item_c" } } } }
  local game, tips = _game({ players = { player }, pending_choice = _item_window(1, { "item_c" }) })
  local hole = _click(game, 1, 2)
  _assert_eq(hole.status, "empty", "a hole slot must read as empty and stay silent")
  _assert_eq(#tips, 0, "a hole click must not raise a tip")
  local result = _click(game, 1, 3)
  _assert_eq(result.status, "select", "the card after a hole keeps its slot")
  _assert_eq(result.action.option_id, "item_c", "slot 3 resolves to the third bag entry")
end

TestItemSlotClick["test_去重键带点击者与拒因:跨玩家、跨拒因都不互相吞"] = function(self)
  local base = denial_cfg.dedupe_key(1, "item_a", "not_current_turn")
  lu.assertEvalToTrue(base ~= denial_cfg.dedupe_key(2, "item_a", "not_current_turn"),
    "different clickers must not share a dedupe key")
  lu.assertEvalToTrue(base ~= denial_cfg.dedupe_key(1, "item_a", "insufficient_funds"),
    "different reasons must not share a dedupe key")
end

TestItemSlotClick["test_行动者解析不出时静默,不凭空提示"] = function(self)
  local game, tips = _game({ players = { _player(1, { "item_a" }) } })
  local result = _click(game, 99, 1)
  _assert_eq(result.status, "empty", "unmapped actor yields no verdict")
  _assert_eq(#tips, 0, "unmapped actor must not be tipped")
end

TestItemSlotClick["test_槽位号缺位或非法时静默,不发提示"] = function(self)
  local game, tips = _game({ players = { _player(1, { "item_a" }) } })
  _assert_eq(item_slot_click.resolve(game, { actor_role_id = 1 }).status, "empty", "missing slot index")
  _assert_eq(_click(game, 1, "buy").status, "empty", "unrelated id")
  _assert_eq(#tips, 0, "malformed clicks must stay silent")
end

TestItemSlotClick["test_game 形状残缺时不炸,按静默或拒绝收场"] = function(self)
  local bare = { players = { _player(1, { "item_a" }) } }
  function bare:find_player_by_id(role_id)
    for _, player in ipairs(self.players) do
      if player.id == role_id then return player end
    end
    return nil
  end
  -- 没有 turn 表：当前回合玩家解析不出 → 点击者必然不等于它 → 拒绝并提示。
  _assert_eq(item_slot_click.resolve(bare, { slot_index = 1, actor_role_id = 1 }).reason,
    "not_current_turn", "missing turn table must not crash the verdict")
  _assert_eq(item_slot_click.resolve(nil, { slot_index = 1, actor_role_id = 1 }).status,
    "empty", "missing game yields no actor")
end

TestItemSlotClick["test_槽位号可由 item_slot_N 字面解析,兼容按钮 id 形态"] = function(self)
  _assert_eq(item_slot_click.resolve_slot_index("item_slot_4"), 4, "id form")
  _assert_eq(item_slot_click.resolve_slot_index(2), 2, "numeric form")
  _assert_eq(item_slot_click.resolve_slot_index("buy"), nil, "unrelated id")
  _assert_eq(item_slot_click.resolve_slot_index({}), nil, "table input resolves to nil")
  _assert_eq(item_slot_click.resolve_slot_index(true), nil, "boolean input resolves to nil")
end


return TestItemSlotClick
