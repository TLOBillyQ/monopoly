local debug_flags = require("src.config.gameplay.debug_flags")

local M = {}

local function _should_build_debug_auto_players(build_mode)
  return build_mode ~= "release"
    and debug_flags.debug_auto_non_primary == true
end

local function _add_debug_auto_player(auto_players, entry)
  if entry == nil or entry.role_id == nil then
    return auto_players
  end
  auto_players = auto_players or {}
  auto_players[entry.role_id] = true
  return auto_players
end

function M.build_auto_players(role_roster, build_mode)
  if not _should_build_debug_auto_players(build_mode) then
    return nil
  end
  local auto_players = nil
  for i = 2, #role_roster do
    auto_players = _add_debug_auto_player(auto_players, role_roster[i])
  end
  return auto_players
end

return M
