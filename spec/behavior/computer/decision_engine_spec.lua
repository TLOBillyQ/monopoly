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

describe("domain decision engine coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("returns nil for non auto player", function()
    local fn = decision_engine.build(_make_agent_ref())
    local game = _make_game(_make_human_player())
    local choice = { id = 1, kind = "market_buy", options = {}, meta = {} }
    local result = fn(game, choice)
    _assert_eq(result, nil, "non-auto player should return nil")
  end)

  it("auto flag player triggers dispatch", function()
    local fn = decision_engine.build(_make_agent_ref())
    local player = { id = "ai_2", auto = true }
    local game = _make_game(player)
    local choice = { id = 1, kind = "market_buy", options = {}, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "auto=true player should produce an action")
    _assert_eq(result.type, "choice_cancel", "market_buy should cancel")
  end)

  it("choice_owner uses meta player_id", function()
    local other_player = _make_ai_player("p2")
    local fn = decision_engine.build(_make_agent_ref())
    local game = _make_game(_make_human_player(), {
      find_player = function(pid) if pid == "p2" then return other_player end end,
    })
    local choice = { id = 1, kind = "market_buy", options = {}, meta = { player_id = "p2" } }
    local result = fn(game, choice)
    -- other_player is_ai=true so should dispatch
    assert(result ~= nil, "should dispatch when meta.player_id points to AI player")
  end)

  it("choice_owner falls back to current player", function()
    local fn = decision_engine.build(_make_agent_ref())
    local game = _make_game(_make_human_player(), {
      find_player = function() return nil end,
    })
    local choice = { id = 1, kind = "market_buy", options = {}, meta = { player_id = "unknown" } }
    local result = fn(game, choice)
    _assert_eq(result, nil, "fallback to current human player should return nil")
  end)

  it("remote_dice uses agent value", function()
    local fn = decision_engine.build(_make_agent_ref({
      pick_remote_dice_value = function() return 5 end,
    }))
    local game = _make_game(_make_ai_player())
    local choice = { id = 10, kind = "remote_dice_value", options = {}, meta = { dice_count = 2 } }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for remote_dice_value")
    _assert_eq(result.option_id, 5, "remote_dice should use agent-picked value")
    _assert_eq(result.choice_id, 10, "choice_id should be set")
  end)

  it("remote_dice falls back to first option", function()
    local fn = decision_engine.build(_make_agent_ref({
      pick_remote_dice_value = function() return nil end,
    }))
    local game = _make_game(_make_ai_player())
    local choice = { id = 11, kind = "remote_dice_value", options = { { id = 3 } }, meta = { dice_count = 1 } }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for remote_dice fallback")
    _assert_eq(result.option_id, 3, "should fall back to first option when agent returns nil")
  end)

  it("roadblock_target uses agent", function()
    local fn = decision_engine.build(_make_agent_ref({
      pick_roadblock_target = function() return 42 end,
    }))
    local game = _make_game(_make_ai_player())
    local choice = { id = 20, kind = "roadblock_target", options = {}, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for roadblock_target")
    _assert_eq(result.option_id, 42, "roadblock_target should use agent pick")
  end)

  it("roadblock_target falls back", function()
    local fn = decision_engine.build(_make_agent_ref({
      pick_roadblock_target = function() return nil end,
    }))
    local game = _make_game(_make_ai_player())
    local choice = { id = 21, kind = "roadblock_target", options = { { id = 7 } }, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for roadblock fallback")
    _assert_eq(result.option_id, 7, "should fall back to first option for roadblock")
  end)

  it("demolish_target uses demolish agent", function()
    local fn = decision_engine.build(_make_agent_ref({
      pick_demolish_target = function() return 99 end,
    }))
    local game = _make_game(_make_ai_player())
    local choice = { id = 22, kind = "demolish_target", options = {}, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for demolish_target")
    _assert_eq(result.option_id, 99, "demolish_target should use pick_demolish_target")
  end)

  it("item_target_player returns target id", function()
    local fn = decision_engine.build(_make_agent_ref({
      pick_target_player = function() return { id = "p3" } end,
    }))
    local game = _make_game(_make_ai_player())
    local choice = { id = 30, kind = "item_target_player", options = {}, meta = { item_id = "sword" } }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for item_target_player with target")
    _assert_eq(result.option_id, "p3", "item_target_player should use target.id")
    _assert_eq(result.type, "choice_select", "type should be choice_select when target found")
  end)

  it("item_target_player cancels when no target", function()
    local fn = decision_engine.build(_make_agent_ref({
      pick_target_player = function() return nil end,
    }))
    local game = _make_game(_make_ai_player())
    local choice = { id = 31, kind = "item_target_player", options = {}, meta = { item_id = "sword" } }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for item_target_player cancel")
    _assert_eq(result.type, "choice_cancel", "no target should cancel")
  end)

  it("landing_optional_effect prefers buy_land", function()
    local fn = decision_engine.build(_make_agent_ref())
    local game = _make_game(_make_ai_player())
    local choice = { id = 60, kind = "landing_optional_effect",
      options = { { id = "pass" }, { id = "buy_land" } }, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for landing_optional_effect")
    _assert_eq(result.option_id, "buy_land", "should prefer buy_land")
  end)

  it("landing_optional_effect prefers upgrade_land", function()
    local fn = decision_engine.build(_make_agent_ref())
    local game = _make_game(_make_ai_player())
    local choice = { id = 61, kind = "landing_optional_effect",
      options = { { id = "pass" }, { id = "upgrade_land" } }, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for landing_optional_effect upgrade")
    _assert_eq(result.option_id, "upgrade_land", "should prefer upgrade_land")
  end)

  it("landing_optional_effect cancels when no options", function()
    local fn = decision_engine.build(_make_agent_ref())
    local game = _make_game(_make_ai_player())
    local choice = { id = 62, kind = "landing_optional_effect", options = {}, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for landing_optional_effect cancel")
    _assert_eq(result.type, "choice_cancel", "no options should cancel")
  end)

  it("rent_card_prompt uses", function()
    local fn = decision_engine.build(_make_agent_ref())
    local game = _make_game(_make_ai_player())
    local choice = { id = 70, kind = "rent_card_prompt", options = {}, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for rent_card_prompt")
    _assert_eq(result.option_id, "use", "rent_card_prompt should select use")
  end)

  it("tax_card_prompt uses", function()
    local fn = decision_engine.build(_make_agent_ref())
    local game = _make_game(_make_ai_player())
    local choice = { id = 71, kind = "tax_card_prompt", options = {}, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for tax_card_prompt")
    _assert_eq(result.option_id, "use", "tax_card_prompt should select use")
  end)

  it("item_phase_choice cancels", function()
    local fn = decision_engine.build(_make_agent_ref())
    local game = _make_game(_make_ai_player())
    local choice = { id = 80, kind = "item_phase_choice", options = {}, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for item_phase_choice")
    _assert_eq(result.type, "choice_cancel", "item_phase_choice should cancel")
  end)

  it("item_phase_passive cancels", function()
    local fn = decision_engine.build(_make_agent_ref())
    local game = _make_game(_make_ai_player())
    local choice = { id = 81, kind = "item_phase_passive", options = {}, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "should have result for item_phase_passive")
    _assert_eq(result.type, "choice_cancel", "item_phase_passive should cancel")
  end)

  it("unknown kind returns nil", function()
    local fn = decision_engine.build(_make_agent_ref())
    local game = _make_game(_make_ai_player())
    local choice = { id = 99, kind = "unknown_kind", options = {}, meta = {} }
    local result = fn(game, choice)
    _assert_eq(result, nil, "unknown choice kind should return nil")
  end)

end)
