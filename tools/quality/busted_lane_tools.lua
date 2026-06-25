local busted_lane_tools = {}

local _PROFILE_TOOLS = {
  acceptance = { "acceptance4lua" },
  contract = { "arch_view" },
  guards = { "arch_view" },
  tooling = { "acceptance4lua", "arch_view", "crap4lua", "dry4lua", "mutate4lua" },
}

function busted_lane_tools.ensure_for_profile(profile, bootstrap, bootstrap_env)
  for _, tool_name in ipairs(_PROFILE_TOOLS[profile] or {}) do
    local _, err = bootstrap.ensure_tool(tool_name, bootstrap_env)
    if err ~= nil then
      return nil, "tool bootstrap failed: " .. tostring(err)
    end
  end
  return true
end

return busted_lane_tools
