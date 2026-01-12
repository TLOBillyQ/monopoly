local Effect = {}
Effect.__index = Effect

-- effect: { id, label, mandatory, can_apply(ctx), apply(ctx) }

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

-- Scan effects for a given context, keeping disabled reasons for UI.
-- Returns entries like: { id, label, mandatory, ok, reason, effect }
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

-- Backward-compatible: list only available effects.
function Effect.list(effect_defs, ctx)
  local available = {}
  for _, entry in ipairs(Effect.scan(effect_defs, ctx)) do
    if entry.ok then
      table.insert(available, entry.effect)
    end
  end
  return available
end

-- Execute a single effect with a mandatory re-check (prevents stale choice).
-- Returns { ok=true, result=? } or { ok=false, reason=? }.
function Effect.execute(effect, ctx)
  local ok, reason = can_apply(effect, ctx)
  if not ok then
    return { ok = false, reason = reason }
  end
  return { ok = true, result = apply(effect, ctx) }
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
    Effect.execute(eff, ctx)
  end

  if #optional == 0 then
    return
  end

  if choose_fn then
    choose_fn(optional, function(chosen)
      if chosen then
        Effect.execute(chosen, ctx)
      end
    end)
  else
    -- default: take first optional
    Effect.execute(optional[1], ctx)
  end
end

return Effect
