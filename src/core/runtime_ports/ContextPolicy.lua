local context_policy = {}

function context_policy.normalize_legacy_fallback_policy(policy)
  local next_policy = policy or {}
  return {
    roles = next_policy.roles == true,
    role = next_policy.role == true,
    vehicle = next_policy.vehicle == true,
    camera = next_policy.camera == true,
  }
end

function context_policy.is_valid(policy)
  return policy == "strict" or policy == "legacy"
end

function context_policy.for_context(policy, enable_legacy_helper_fallback)
  if policy == "legacy" then
    local helper_enabled = enable_legacy_helper_fallback == true
    return {
      roles = true,
      role = true,
      vehicle = helper_enabled,
      camera = helper_enabled,
    }
  end
  return context_policy.normalize_legacy_fallback_policy()
end

return context_policy
