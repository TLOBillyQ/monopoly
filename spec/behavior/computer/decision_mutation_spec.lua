-- Mutation-pinning specs for src/computer/agent/decision.lua.
-- State shapes kept inline (no shared helpers) so nil-vs-value discrimination is
-- the contract each test pins. Every test drives the real decision fn built from
-- decision_engine.build and asserts a value that differs between original/mutant.

local decision_engine = require("src.computer.agent.decision")

local function _ai_game(player)
  local g = {}
  function g:current_player() return player end
  return g
end

describe("decision.lua mutation pins", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("L9 _first_option_id returns options[1] via bare-string option (kills '1'->'0')", function()
    -- remote_dice fallback funnels through _first_option_id(choice.options).
    -- With a bare-string option, options[1].id is nil so the code returns
    -- `options[1]` ("opt_x"). Mutating either `1` to `0` reads options[0]:
    --   `options[0].id` -> indexing nil -> error, or
    --   `... or options[0]` -> nil.
    -- Both differ from the original "opt_x".
    local fn = decision_engine.build({
      pick_remote_dice_value = function() return nil end, -- force fallback
      pick_roadblock_target = function() return nil end,
      pick_demolish_target = function() return nil end,
      pick_target_player = function() return nil end,
    })
    local game = _ai_game({ id = "ai_1", is_ai = true })
    local choice = { id = 1, kind = "remote_dice_value", options = { "opt_x" }, meta = { dice_count = 1 } }
    local result = fn(game, choice)
    assert(result ~= nil, "remote_dice fallback must produce an action")
    assert(result.option_id == "opt_x",
      "first option of bare-string list must be 'opt_x'; got " .. tostring(result.option_id))
  end)

  it("L14 _choice_owner needs BOTH player_id AND find_player_by_id (kills 'and'->'or')", function()
    -- meta.player_id present but game has NO find_player_by_id method.
    -- Original: `player_id and nil` -> falsy -> falls through to current_player()
    --   (an AI player) -> dispatches market_buy -> choice_cancel.
    -- Mutant 'or': `player_id or nil` -> truthy -> enters block -> calls
    --   game:find_player_by_id (nil) -> error.
    local fn = decision_engine.build({
      pick_remote_dice_value = function() return nil end,
      pick_roadblock_target = function() return nil end,
      pick_demolish_target = function() return nil end,
      pick_target_player = function() return nil end,
    })
    local game = _ai_game({ id = "ai_owner", is_ai = true }) -- no find_player_by_id
    local choice = { id = 2, kind = "market_buy", options = {}, meta = { player_id = "p2" } }
    local ok, result = pcall(fn, game, choice)
    assert(ok, "original must not enter the find_player branch when method is absent")
    assert(result ~= nil and result.type == "choice_cancel",
      "AI current_player owner must dispatch market_buy -> choice_cancel; got "
        .. tostring(result and result.type))
  end)

  it("L41 _resolve_target_option falls back to _first_option_id (kills '...(options)'->nil)", function()
    -- landing_optional_effect with an option that matches NO preferred id.
    -- Original: no preferred match -> returns _first_option_id(options) = "pass"
    --   -> choice_select with option_id "pass".
    -- Mutant nil: returns nil -> _handle_landing_optional_effect cancels.
    local fn = decision_engine.build({
      pick_remote_dice_value = function() return nil end,
      pick_roadblock_target = function() return nil end,
      pick_demolish_target = function() return nil end,
      pick_target_player = function() return nil end,
    })
    local game = _ai_game({ id = "ai_1", is_ai = true })
    local choice = { id = 41, kind = "landing_optional_effect",
      options = { { id = "pass" } }, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "landing_optional_effect must produce an action")
    assert(result.type == "choice_select",
      "unmatched-but-nonempty options must select first, not cancel; got " .. tostring(result.type))
    assert(result.option_id == "pass",
      "fallback option_id must be first option 'pass'; got " .. tostring(result.option_id))
  end)

  it("L56/L57 roadblock branch uses resolver(game,actor) with no count arg", function()
    -- resolver reports whether it received a 3rd arg. For a roadblock choice:
    --   original: option_id = (kind=="roadblock_target") and resolver(game,actor)
    --             -> "two" (no count arg).
    -- Kills all three survivors on L56/L57:
    --   L56 ==->~= : condition flips false -> resolver(game,actor,3) -> "three".
    --   L56 literal->nil : kind==nil false -> resolver(game,actor,3) -> "three".
    --   L57 resolver(game,actor)->nil : `true and nil` -> or resolver(game,actor,3) -> "three".
    local fn = decision_engine.build({
      pick_remote_dice_value = function() return nil end,
      pick_roadblock_target = function(_, _, count)
        return count == nil and "two" or "three"
      end,
      pick_demolish_target = function() return "demolish" end,
      pick_target_player = function() return nil end,
    })
    local game = _ai_game({ id = "ai_1", is_ai = true })
    local choice = { id = 56, kind = "roadblock_target", options = {}, meta = {} }
    local result = fn(game, choice)
    assert(result ~= nil, "roadblock_target must produce an action")
    assert(result.option_id == "two",
      "roadblock resolver must be called as resolver(game,actor) with no count; got "
        .. tostring(result.option_id))
  end)
end)
