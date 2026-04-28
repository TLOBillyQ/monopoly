local decision_engine = require("src.computer.agent.decision")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_ai_player(id)
  return { id = id or "ai_1", is_ai = true }
end

local function _make_human_player(id)
  return { id = id or "human_1", is_ai = false }
end

local function _make_game(player, opts)
  opts = opts or {}
  local g = {}
  function g:current_player() return player end
  if opts.find_player then
    function g:find_player_by_id(pid)
      return opts.find_player(pid)
    end
  end
  return g
end

local function _make_agent_ref(overrides)
  overrides = overrides or {}
  return {
    pick_remote_dice_value = overrides.pick_remote_dice_value or function() return nil end,
    pick_roadblock_target = overrides.pick_roadblock_target or function() return nil end,
    pick_demolish_target = overrides.pick_demolish_target or function() return nil end,
    pick_target_player = overrides.pick_target_player or function() return nil end,
  }
end

-- non-auto player returns nil

local function test_returns_nil_for_non_auto_player()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_human_player())
  local choice = { id = 1, kind = "market_buy", options = {}, meta = {} }
  local result = fn(game, choice)
  _assert_eq(result, nil, "non-auto player should return nil")
end

-- auto player (via .auto flag)

local function test_auto_flag_player_triggers_dispatch()
  local fn = decision_engine.build(_make_agent_ref())
  local player = { id = "ai_2", auto = true }
  local game = _make_game(player)
  local choice = { id = 1, kind = "market_buy", options = {}, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "auto=true player should produce an action")
  _assert_eq(result.type, "choice_cancel", "market_buy should cancel")
end

-- _choice_owner: meta.player_id finds player

local function test_choice_owner_uses_meta_player_id()
  local other_player = _make_ai_player("p2")
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_human_player(), {
    find_player = function(pid) if pid == "p2" then return other_player end end,
  })
  local choice = { id = 1, kind = "market_buy", options = {}, meta = { player_id = "p2" } }
  local result = fn(game, choice)
  -- other_player is_ai=true so should dispatch
  assert(result ~= nil, "should dispatch when meta.player_id points to AI player")
end

-- _choice_owner: meta.player_id not found → falls back to current_player

local function test_choice_owner_falls_back_to_current_player()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_human_player(), {
    find_player = function() return nil end,
  })
  local choice = { id = 1, kind = "market_buy", options = {}, meta = { player_id = "unknown" } }
  local result = fn(game, choice)
  _assert_eq(result, nil, "fallback to current human player should return nil")
end

-- remote_dice_value: agent returns value

local function test_remote_dice_uses_agent_value()
  local fn = decision_engine.build(_make_agent_ref({
    pick_remote_dice_value = function() return 5 end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 10, kind = "remote_dice_value", options = {}, meta = { dice_count = 2 } }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for remote_dice_value")
  _assert_eq(result.option_id, 5, "remote_dice should use agent-picked value")
  _assert_eq(result.choice_id, 10, "choice_id should be set")
end

-- remote_dice_value: agent returns nil → falls back to first option

local function test_remote_dice_falls_back_to_first_option()
  local fn = decision_engine.build(_make_agent_ref({
    pick_remote_dice_value = function() return nil end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 11, kind = "remote_dice_value", options = { { id = 3 } }, meta = { dice_count = 1 } }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for remote_dice fallback")
  _assert_eq(result.option_id, 3, "should fall back to first option when agent returns nil")
end

-- roadblock_target

local function test_roadblock_target_uses_agent()
  local fn = decision_engine.build(_make_agent_ref({
    pick_roadblock_target = function() return 42 end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 20, kind = "roadblock_target", options = {}, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for roadblock_target")
  _assert_eq(result.option_id, 42, "roadblock_target should use agent pick")
end

-- roadblock_target falls back to first option when agent returns nil

local function test_roadblock_target_falls_back()
  local fn = decision_engine.build(_make_agent_ref({
    pick_roadblock_target = function() return nil end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 21, kind = "roadblock_target", options = { { id = 7 } }, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for roadblock fallback")
  _assert_eq(result.option_id, 7, "should fall back to first option for roadblock")
end

-- demolish_target uses demolish resolver

local function test_demolish_target_uses_demolish_agent()
  local fn = decision_engine.build(_make_agent_ref({
    pick_demolish_target = function() return 99 end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 22, kind = "demolish_target", options = {}, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for demolish_target")
  _assert_eq(result.option_id, 99, "demolish_target should use pick_demolish_target")
end

-- missile_target uses demolish resolver (same handler)

local function test_missile_target_uses_demolish_agent()
  local fn = decision_engine.build(_make_agent_ref({
    pick_demolish_target = function() return 88 end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 23, kind = "missile_target", options = {}, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for missile_target")
  _assert_eq(result.option_id, 88, "missile_target should use pick_demolish_target")
end

-- item_target_player: target found

local function test_item_target_player_returns_target_id()
  local fn = decision_engine.build(_make_agent_ref({
    pick_target_player = function() return { id = "p3" } end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 30, kind = "item_target_player", options = {}, meta = { item_id = "sword" } }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for item_target_player with target")
  _assert_eq(result.option_id, "p3", "item_target_player should use target.id")
  _assert_eq(result.type, "choice_select", "type should be choice_select when target found")
end

-- item_target_player: no target → cancel

local function test_item_target_player_cancels_when_no_target()
  local fn = decision_engine.build(_make_agent_ref({
    pick_target_player = function() return nil end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 31, kind = "item_target_player", options = {}, meta = { item_id = "sword" } }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for item_target_player cancel")
  _assert_eq(result.type, "choice_cancel", "no target should cancel")
end

-- steal_item: has option → select it

local function test_steal_item_selects_first_option()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 40, kind = "steal_item", options = { { id = "item_a" } }, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for steal_item with option")
  _assert_eq(result.option_id, "item_a", "steal_item should select first option")
  _assert_eq(result.type, "choice_select", "type should be choice_select")
end

-- steal_item: no options → cancel

local function test_steal_item_cancels_when_no_options()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 41, kind = "steal_item", options = {}, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for steal_item with no options")
  _assert_eq(result.type, "choice_cancel", "steal_item with no options should cancel")
end

-- steal_prompt: always use

local function test_steal_prompt_uses()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 50, kind = "steal_prompt", options = {}, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for steal_prompt")
  _assert_eq(result.option_id, "use", "steal_prompt should select use")
end

-- landing_optional_effect: buy_land preferred

local function test_landing_optional_effect_prefers_buy_land()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 60, kind = "landing_optional_effect",
    options = { { id = "pass" }, { id = "buy_land" } }, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for landing_optional_effect")
  _assert_eq(result.option_id, "buy_land", "should prefer buy_land")
end

-- landing_optional_effect: upgrade_land preferred when no buy_land

local function test_landing_optional_effect_prefers_upgrade_land()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 61, kind = "landing_optional_effect",
    options = { { id = "pass" }, { id = "upgrade_land" } }, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for landing_optional_effect upgrade")
  _assert_eq(result.option_id, "upgrade_land", "should prefer upgrade_land")
end

-- landing_optional_effect: no preferred → cancel (empty options, not just no match)

local function test_landing_optional_effect_cancels_when_no_options()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 62, kind = "landing_optional_effect", options = {}, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for landing_optional_effect cancel")
  _assert_eq(result.type, "choice_cancel", "no options should cancel")
end

-- rent_card_prompt: always use

local function test_rent_card_prompt_uses()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 70, kind = "rent_card_prompt", options = {}, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for rent_card_prompt")
  _assert_eq(result.option_id, "use", "rent_card_prompt should select use")
end

-- tax_card_prompt: always use

local function test_tax_card_prompt_uses()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 71, kind = "tax_card_prompt", options = {}, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for tax_card_prompt")
  _assert_eq(result.option_id, "use", "tax_card_prompt should select use")
end

-- item_phase_choice: cancel

local function test_item_phase_choice_cancels()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 80, kind = "item_phase_choice", options = {}, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for item_phase_choice")
  _assert_eq(result.type, "choice_cancel", "item_phase_choice should cancel")
end

-- item_phase_passive: cancel

local function test_item_phase_passive_cancels()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 81, kind = "item_phase_passive", options = {}, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for item_phase_passive")
  _assert_eq(result.type, "choice_cancel", "item_phase_passive should cancel")
end

-- unknown kind: returns nil

local function test_unknown_kind_returns_nil()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 99, kind = "unknown_kind", options = {}, meta = {} }
  local result = fn(game, choice)
  _assert_eq(result, nil, "unknown choice kind should return nil")
end

-- option as plain value (not table)

local function test_first_option_id_handles_plain_value()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 100, kind = "steal_item", options = { "plain_id" }, meta = {} }
  local result = fn(game, choice)
  assert(result ~= nil, "should have result for plain option value")
  _assert_eq(result.option_id, "plain_id", "plain option values should be used as id")
end

return {
  name = "domain decision engine coverage",
  tests = {
    { name = "returns nil for non auto player", run = test_returns_nil_for_non_auto_player },
    { name = "auto flag player triggers dispatch", run = test_auto_flag_player_triggers_dispatch },
    { name = "choice_owner uses meta player_id", run = test_choice_owner_uses_meta_player_id },
    { name = "choice_owner falls back to current player", run = test_choice_owner_falls_back_to_current_player },
    { name = "remote_dice uses agent value", run = test_remote_dice_uses_agent_value },
    { name = "remote_dice falls back to first option", run = test_remote_dice_falls_back_to_first_option },
    { name = "roadblock_target uses agent", run = test_roadblock_target_uses_agent },
    { name = "roadblock_target falls back", run = test_roadblock_target_falls_back },
    { name = "demolish_target uses demolish agent", run = test_demolish_target_uses_demolish_agent },
    { name = "missile_target uses demolish agent", run = test_missile_target_uses_demolish_agent },
    { name = "item_target_player returns target id", run = test_item_target_player_returns_target_id },
    { name = "item_target_player cancels when no target", run = test_item_target_player_cancels_when_no_target },
    { name = "steal_item selects first option", run = test_steal_item_selects_first_option },
    { name = "steal_item cancels when no options", run = test_steal_item_cancels_when_no_options },
    { name = "steal_prompt uses", run = test_steal_prompt_uses },
    { name = "landing_optional_effect prefers buy_land", run = test_landing_optional_effect_prefers_buy_land },
    { name = "landing_optional_effect prefers upgrade_land", run = test_landing_optional_effect_prefers_upgrade_land },
    { name = "landing_optional_effect cancels when no options", run = test_landing_optional_effect_cancels_when_no_options },
    { name = "rent_card_prompt uses", run = test_rent_card_prompt_uses },
    { name = "tax_card_prompt uses", run = test_tax_card_prompt_uses },
    { name = "item_phase_choice cancels", run = test_item_phase_choice_cancels },
    { name = "item_phase_passive cancels", run = test_item_phase_passive_cancels },
    { name = "unknown kind returns nil", run = test_unknown_kind_returns_nil },
    { name = "first option id handles plain value", run = test_first_option_id_handles_plain_value },
  },
}
