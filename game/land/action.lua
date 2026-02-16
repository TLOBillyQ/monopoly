local action = {}
local event = require("game.land.event")
local rule = require("game.land.rule")
function action.safe_tile_state(game, tile)
  return rule.safe_tile_state(game, tile)
end

function action.resolve_rent_owner(game, tile, state_fn)
  local owner, st, skip = rule.resolve_rent_owner(game, tile, state_fn)
  if skip and skip.reason == "mountain" then
    event.apply(game, {
      ok = false,
      event = "rent_skipped_mountain",
      payload = {
        owner = skip.owner,
        tile = tile,
        text = skip.owner.name .. " 在深山，租金不收取",
      },
    })
    return nil, st
  end
  return owner, st
end

function action.execute_strong_card(game, player_id, tile_id)
  local result = rule.execute_strong_card(game, player_id, tile_id)
  if result and result.ok then
    event.apply(game, result)
  end
  return result and result.ok == true
end

function action.execute_free_card(game, player_id, tile_id)
  local result = rule.execute_free_card(game, player_id, tile_id)
  if result and result.ok then
    event.apply(game, result)
  end
  return result and result.ok == true
end

function action.execute_pay_rent(game, player_id, tile_id)
  local result = rule.execute_pay_rent(game, player_id, tile_id)
  if result and result.event == "rent_skipped_mountain" then
    event.apply(game, result)
    return false
  end
  if result and result.ok then
    event.apply(game, result)
  end
  return result and result.ok == true
end

function action.execute_tax_free_card(game, player_id)
  local result = rule.execute_tax_free_card(game, player_id)
  if result and result.ok then
    event.apply(game, result)
  end
  return result and result.ok == true
end

function action.execute_pay_tax(game, player_id)
  local result = rule.execute_pay_tax(game, player_id)
  if result and result.ok then
    event.apply(game, result)
  end
  return result and result.ok == true
end

return action
