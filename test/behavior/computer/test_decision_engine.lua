require("test.bootstrap").install_package_paths()
local luassert = assert
local decision_engine = require("src.computer.agent.decision")
local control = require("src.player.control")

local function _assert_eq(a, b, msg)
  luassert.truthy(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_ai_player(id)
  local player = { id = id or "ai_1", is_ai = true }
  control.initialize(player)
  return player
end

local function _make_human_player(id)
  local player = { id = id or "human_1", is_ai = false }
  control.initialize(player)
  return player
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

local _config_reset = require("test.support.config_reset")

local function set_up()
  _config_reset.reset_all()
end

local function test_returns_nil_for_non_auto_player()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_human_player())
  local choice = { id = 1, kind = "market_buy", options = {}, meta = {} }
  local result = fn(game, choice)
  _assert_eq(result, nil, "non-auto player should return nil")
end

local function test_auto_flag_player_triggers_dispatch()
  local fn = decision_engine.build(_make_agent_ref())
  local player = { id = "ai_2" }
  control.initialize(player)
  control.toggle_manual_delegation(player)
  local game = _make_game(player)
  local choice = { id = 1, kind = "market_buy", options = {}, meta = {} }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "manually delegated player should produce an action")
  _assert_eq(result.type, "choice_cancel", "market_buy should cancel")
end

local function test_choice_owner_uses_meta_player_id()
  local other_player = _make_ai_player("p2")
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_human_player(), {
    find_player = function(pid) if pid == "p2" then return other_player end end,
  })
  local choice = { id = 1, kind = "market_buy", options = {}, meta = { player_id = "p2" } }
  local result = fn(game, choice)
  -- other_player is_ai=true so should dispatch
  luassert.truthy(result ~= nil, "should dispatch when meta.player_id points to AI player")
end

local function test_choice_owner_falls_back_to_current_player()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_human_player(), {
    find_player = function() return nil end,
  })
  local choice = { id = 1, kind = "market_buy", options = {}, meta = { player_id = "unknown" } }
  local result = fn(game, choice)
  _assert_eq(result, nil, "fallback to current human player should return nil")
end

local function test_remote_dice_uses_agent_value()
  local fn = decision_engine.build(_make_agent_ref({
    pick_remote_dice_value = function() return 5 end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 10, kind = "remote_dice_value", options = {}, meta = { dice_count = 2 } }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for remote_dice_value")
  _assert_eq(result.option_id, 5, "remote_dice should use agent-picked value")
  _assert_eq(result.choice_id, 10, "choice_id should be set")
end

local function test_remote_dice_falls_back_to_first_option()
  local fn = decision_engine.build(_make_agent_ref({
    pick_remote_dice_value = function() return nil end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 11, kind = "remote_dice_value", options = { { id = 3 } }, meta = { dice_count = 1 } }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for remote_dice fallback")
  _assert_eq(result.option_id, 3, "should fall back to first option when agent returns nil")
end

local function test_roadblock_target_uses_agent()
  local fn = decision_engine.build(_make_agent_ref({
    pick_roadblock_target = function() return 42 end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 20, kind = "roadblock_target", options = {}, meta = {} }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for roadblock_target")
  _assert_eq(result.option_id, 42, "roadblock_target should use agent pick")
end

local function test_roadblock_target_falls_back()
  local fn = decision_engine.build(_make_agent_ref({
    pick_roadblock_target = function() return nil end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 21, kind = "roadblock_target", options = { { id = 7 } }, meta = {} }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for roadblock fallback")
  _assert_eq(result.option_id, 7, "should fall back to first option for roadblock")
end

local function test_demolish_target_uses_demolish_agent()
  local fn = decision_engine.build(_make_agent_ref({
    pick_demolish_target = function() return 99 end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 22, kind = "demolish_target", options = {}, meta = {} }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for demolish_target")
  _assert_eq(result.option_id, 99, "demolish_target should use pick_demolish_target")
end

local function test_item_target_player_returns_target_id()
  local fn = decision_engine.build(_make_agent_ref({
    pick_target_player = function() return { id = "p3" } end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 30, kind = "item_target_player", options = {}, meta = { item_id = "sword" } }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for item_target_player with target")
  _assert_eq(result.option_id, "p3", "item_target_player should use target.id")
  _assert_eq(result.type, "choice_select", "type should be choice_select when target found")
end

local function test_item_target_player_cancels_when_no_target()
  local fn = decision_engine.build(_make_agent_ref({
    pick_target_player = function() return nil end,
  }))
  local game = _make_game(_make_ai_player())
  local choice = { id = 31, kind = "item_target_player", options = {}, meta = { item_id = "sword" } }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for item_target_player cancel")
  _assert_eq(result.type, "choice_cancel", "no target should cancel")
end

local function test_landing_optional_effect_prefers_buy_land()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 60, kind = "landing_optional_effect",
    options = { { id = "pass" }, { id = "buy_land" } }, meta = {} }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for landing_optional_effect")
  _assert_eq(result.option_id, "buy_land", "should prefer buy_land")
end

local function test_landing_optional_effect_prefers_upgrade_land()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 61, kind = "landing_optional_effect",
    options = { { id = "pass" }, { id = "upgrade_land" } }, meta = {} }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for landing_optional_effect upgrade")
  _assert_eq(result.option_id, "upgrade_land", "should prefer upgrade_land")
end

local function test_landing_optional_effect_cancels_when_no_options()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 62, kind = "landing_optional_effect", options = {}, meta = {} }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for landing_optional_effect cancel")
  _assert_eq(result.type, "choice_cancel", "no options should cancel")
end

local function test_rent_card_prompt_uses()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 70, kind = "rent_card_prompt", options = {}, meta = {} }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for rent_card_prompt")
  _assert_eq(result.option_id, "use", "rent_card_prompt should select use")
end

local function test_tax_card_prompt_uses()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 71, kind = "tax_card_prompt", options = {}, meta = {} }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for tax_card_prompt")
  _assert_eq(result.option_id, "use", "tax_card_prompt should select use")
end

local function test_item_phase_passive_cancels()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 81, kind = "item_phase_passive", options = {}, meta = {} }
  local result = fn(game, choice)
  luassert.truthy(result ~= nil, "should have result for item_phase_passive")
  _assert_eq(result.type, "choice_cancel", "item_phase_passive should cancel")
end

local function test_unknown_kind_returns_nil()
  local fn = decision_engine.build(_make_agent_ref())
  local game = _make_game(_make_ai_player())
  local choice = { id = 99, kind = "unknown_kind", options = {}, meta = {} }
  local result = fn(game, choice)
  _assert_eq(result, nil, "unknown choice kind should return nil")
end


describe("TestDecisionEngine", function()
  before_each(set_up)
  it("test_returns_nil_for_non_auto_player", test_returns_nil_for_non_auto_player)
  it("test_auto_flag_player_triggers_dispatch", test_auto_flag_player_triggers_dispatch)
  it("test_choice_owner_uses_meta_player_id", test_choice_owner_uses_meta_player_id)
  it("test_choice_owner_falls_back_to_current_player", test_choice_owner_falls_back_to_current_player)
  it("test_remote_dice_uses_agent_value", test_remote_dice_uses_agent_value)
  it("test_remote_dice_falls_back_to_first_option", test_remote_dice_falls_back_to_first_option)
  it("test_roadblock_target_uses_agent", test_roadblock_target_uses_agent)
  it("test_roadblock_target_falls_back", test_roadblock_target_falls_back)
  it("test_demolish_target_uses_demolish_agent", test_demolish_target_uses_demolish_agent)
  it("test_item_target_player_returns_target_id", test_item_target_player_returns_target_id)
  it("test_item_target_player_cancels_when_no_target", test_item_target_player_cancels_when_no_target)
  it("test_landing_optional_effect_prefers_buy_land", test_landing_optional_effect_prefers_buy_land)
  it("test_landing_optional_effect_prefers_upgrade_land", test_landing_optional_effect_prefers_upgrade_land)
  it("test_landing_optional_effect_cancels_when_no_options", test_landing_optional_effect_cancels_when_no_options)
  it("test_rent_card_prompt_uses", test_rent_card_prompt_uses)
  it("test_tax_card_prompt_uses", test_tax_card_prompt_uses)
  it("test_item_phase_passive_cancels", test_item_phase_passive_cancels)
  it("test_unknown_kind_returns_nil", test_unknown_kind_returns_nil)
end)
