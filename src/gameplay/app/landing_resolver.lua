local Effect = require("src.gameplay.domain.effect")
local landing_effects = require("src.gameplay.domain.landing")
local IntentDispatcher = require("src.gameplay.app.intent_dispatcher")

local LandingResolver = {}

local function copy_array(arr)
  if type(arr) ~= "table" then
    return nil
  end
  local out = {}
  for i = 1, #arr do
    out[i] = arr[i]
  end
  return out
end


local function snapshot_move_result(move_result)
  if type(move_result) ~= "table" then
    return nil
  end
  return {
    encountered_players = copy_array(move_result.encountered_players),
    passed_start = move_result.passed_start,
    stopped_on_roadblock = move_result.stopped_on_roadblock,
    visited = copy_array(move_result.visited),
    steps = move_result.steps,
    landing_tile_id = move_result.landing_tile and move_result.landing_tile.id or nil,
  }
end

local function build_ctx(game, player, tile, move_result)
  local phase = game and game.store and game.store:get({ "turn", "phase" }) or "landing"
  return {
    game = game,
    store = game and game.store,
    rng = game and game.rng,
    services = game and game.services,
    phase = phase,
    player = player,
    tile = tile,
    move_result = move_result,
    on_landing = true,
  }
end



function LandingResolver.resolve(game, player, tile, move_result)
  local ctx = build_ctx(game, player, tile, move_result)

  local scanned = Effect.scan(landing_effects.defs, ctx)
  local mandatory = {}
  local optional = {}

  for _, entry in ipairs(scanned) do
    if entry.ok then
      if entry.mandatory then
        table.insert(mandatory, entry.effect)
      else
        table.insert(optional, entry.effect)
      end
    end
  end

  
  for _, eff in ipairs(mandatory) do
    local res = Effect.execute(eff, ctx)
    local out = res and res.result

    if type(out) == "table" and out.kind == "need_landing" then
      local target_player = (out.player_id and game and game.players and game.players[out.player_id]) or player
      local next_tile = nil
      if target_player then
        local idx = out.board_index or target_player.position
        next_tile = idx and game and game.board and game.board:get_tile(idx) or nil
      end
      if next_tile then
          local deep_sub_res = LandingResolver.resolve(game, target_player, next_tile, out.move_result)
          out = deep_sub_res
      end
    end

    IntentDispatcher.dispatch(game, out or res)
    if type(out) == "table" and out.waiting then
      out.resume_state = out.resume_state or "landing"
      out.resume_args = out.resume_args or { player = player, move_result = move_result }
      return out
    end
  end

  if #optional == 0 then
    return nil
  end

  local body_lines = {}
  local options = {}
  local effect_ids = {}
  for _, eff in ipairs(optional) do
    local label = eff.label or eff.id
    table.insert(body_lines, label)
    table.insert(options, { id = eff.id, label = label })
    table.insert(effect_ids, eff.id)
  end

  local out = {
    waiting = true,
    reason = "landing_optional",
    resume_state = "post_action",
    resume_args = { player = player },
    intent = {
      kind = "need_choice",
      choice_spec = {
        kind = "landing_optional_effect",
        title = "可选行动",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "跳过",
        meta = {
          player_id = player.id,
          tile_id = tile.id,
          move_result = snapshot_move_result(move_result),
          effect_ids = effect_ids,
        },
      },
    },
  }
  IntentDispatcher.dispatch(game, out)
  return out
end

return LandingResolver
