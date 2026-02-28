local signals = {
  ACTION = "action",
  TICK = "tick",
}

function signals.is_action(signal)
  return type(signal) == "table" and signal.type == signals.ACTION
end

function signals.is_tick(signal)
  return type(signal) == "table" and signal.type == signals.TICK
end

return signals
