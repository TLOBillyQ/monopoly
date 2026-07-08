-- pending-choice owner/actor 解析唯一权威。
-- 收编原 waits/choice_dispatch.resolve_choice_owner_id、
-- policies/choice_auto._resolve_choice_owner、deadlines/choice_ports 的
-- actor 补全三份散落实现——同一「这个 choice 归谁」问题只在此有一份答案。
local choice_contract = require("src.config.choice.contract")

local owner = {}

function owner.resolve_role_id(game, choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil and game.find_player_by_id then
    local player = game:find_player_by_id(owner_role_id)
    if player then
      return player.id
    end
  end
  local current = game.turn and game.turn.current_player_index or nil
  local player = current and game.players and game.players[current] or nil
  return player and player.id or nil
end

function owner.resolve_player(game, choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil and game and game.find_player_by_id then
    local player = game:find_player_by_id(owner_role_id)
    if player then
      return player
    end
  end
  if game and game.current_player then
    return game:current_player()
  end
  return nil
end

function owner.ensure_actor_role_id(game, choice, action)
  if not action or action.actor_role_id ~= nil then
    return action
  end
  local owner_id = owner.resolve_role_id(game, choice)
  if owner_id ~= nil then
    action.actor_role_id = owner_id
  end
  return action
end

return owner
