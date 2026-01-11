local Effect = {}
Effect.__index = Effect

-- effect: { id, label, mandatory, can_apply(ctx), apply(ctx) }

local function can_apply(effect, ctx)
  if effect.can_apply then
    local ok, reason = effect.can_apply(ctx)
    return ok, reason
  end
  return true, nil
end

local function apply(effect, ctx)
  if effect.apply then
    return effect.apply(ctx)
  end
end

-- Scan available effects for a given context
function Effect.list(effect_defs, ctx)
  local available = {}
  for _, eff in ipairs(effect_defs) do
    local ok = true
    if eff.can_apply then
      ok = eff.can_apply(ctx)
    end
    if ok then
      table.insert(available, eff)
    end
  end
  return available
end

-- Apply mandatory first, then optional via chooser callback
function Effect.resolve(effect_defs, ctx, choose_fn)
  local mandatory = {}
  local optional = {}
  for _, eff in ipairs(Effect.list(effect_defs, ctx)) do
    if eff.mandatory then
      table.insert(mandatory, eff)
    else
      table.insert(optional, eff)
    end
  end

  for _, eff in ipairs(mandatory) do
    apply(eff, ctx)
  end

  if #optional == 0 then
    return
  end

  if choose_fn then
    choose_fn(optional, function(chosen)
      if chosen then
        apply(chosen, ctx)
      end
    end)
  else
    -- default: take first optional
    apply(optional[1], ctx)
  end
end

return Effect
