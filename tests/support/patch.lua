local patch = {}

function patch.with_patches(patches, fn)
  local originals = {}
  for i, item in ipairs(patches or {}) do
    local target = item.target or _G
    originals[i] = {
      target = target,
      key = item.key,
      value = target[item.key],
    }
    target[item.key] = item.value
  end

  local handler = debug and debug.traceback or function(err)
    return err
  end
  local ok, err = xpcall(fn, handler)

  for i = #originals, 1, -1 do
    local item = originals[i]
    item.target[item.key] = item.value
  end

  if not ok then
    error(err)
  end
end

return patch
