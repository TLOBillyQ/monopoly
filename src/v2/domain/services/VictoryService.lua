local common = require("src.v2.domain.services.Common")

local victory_service = {}

local function _alive_seats(state)
  local out = {}
  for seat, player in ipairs(state.players) do
    if not player.eliminated then
      out[#out + 1] = seat
    end
  end
  return out
end

function victory_service.check(state)
  if state.match.finished then
    return {
      finished = true,
      winner_ids = state.match.winner_ids,
      reason = state.match.reason,
    }
  end

  local alive = _alive_seats(state)
  if #alive <= 1 then
    local winner_ids = {}
    local winner_names = {}
    if alive[1] then
      winner_ids[1] = alive[1]
      winner_names[1] = state.players[alive[1]].name
    end
    return {
      finished = true,
      winner_ids = winner_ids,
      winner_names = winner_names,
      reason = "last_alive",
    }
  end

  local turn_limit = state.rules.turn_limit or 0
  if turn_limit > 0 and state.turn.turn_no >= turn_limit then
    local best_assets = -math.huge
    local winner_ids = {}
    local winner_names = {}
    for _, seat in ipairs(alive) do
      local assets = common.total_assets(state, seat)
      if assets > best_assets then
        best_assets = assets
        winner_ids = { seat }
      elseif assets == best_assets then
        winner_ids[#winner_ids + 1] = seat
      end
    end
    for _, seat in ipairs(winner_ids) do
      winner_names[#winner_names + 1] = state.players[seat].name
    end
    return {
      finished = true,
      winner_ids = winner_ids,
      winner_names = winner_names,
      reason = "turn_limit",
    }
  end

  return nil
end

return victory_service
