local Effect = {}
Effect.__index = Effect

local function can_apply(effect, ctx)
  if effect.can_apply then
    local ok, reason = effect.can_apply(ctx)
    return ok == true, reason
  end
  return true, nil
end

local function apply(effect, ctx)
  if effect.apply then
    return effect.apply(ctx)
  end
end

function Effect.scan(effect_defs, ctx)
  local entries = {}
  for _, eff in ipairs(effect_defs or {}) do
    local ok, reason = can_apply(eff, ctx)
    table.insert(entries, {
      id = eff.id,
      label = eff.label or eff.id,
      mandatory = eff.mandatory == true,
      ok = ok,
      reason = reason,
      effect = eff,
    })
  end
  return entries
end

function Effect.execute(effect, ctx)
  local ok, reason = can_apply(effect, ctx)
  if not ok then
    return { ok = false, reason = reason }
  end
  return { ok = true, result = apply(effect, ctx) }
end

return Effect
