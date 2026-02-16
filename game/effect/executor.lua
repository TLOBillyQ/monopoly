local executor = {}

function executor.validate(effect_id, exec)
  assert(effect_id ~= nil and effect_id ~= "", "missing effect_id")
  assert(type(exec) == "table", "invalid exec: " .. tostring(effect_id))
  assert(type(exec.apply) == "function", "missing exec apply: " .. tostring(effect_id))
end

return executor
