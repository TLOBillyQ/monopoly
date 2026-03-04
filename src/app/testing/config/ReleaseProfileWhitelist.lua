local release_profile_whitelist = {
  default = true,
  scenario_bankruptcy = true,
  scenario_upgrade_building_render = true,
  scenario_market_staging = true,
  scenario_hospital_staging = true,
  scenario_mountain_staging = true,
  items_move_control = true,
  items_economy_tax = true,
  items_target_disrupt = true,
  items_deity_status = true,
}

local M = {}

function M.all()
  local out = {}
  for name in pairs(release_profile_whitelist) do
    out[#out + 1] = name
  end
  table.sort(out)
  return out
end

function M.contains(profile_name)
  return release_profile_whitelist[profile_name] == true
end

return M
