local GameEvents = {}
GameEvents.__index = GameEvents

function GameEvents.new()
  return setmetatable({ _listeners = {} }, GameEvents)
end

function GameEvents:on(kind, fn)
  if not (kind and fn) then
    return
  end
  local list = self._listeners[kind]
  if not list then
    list = {}
    self._listeners[kind] = list
  end
  table.insert(list, fn)
end

function GameEvents:emit(kind, payload)
  local list = self._listeners[kind]
  if not list then
    return
  end
  for _, fn in ipairs(list) do
    fn(payload)
  end
end

return GameEvents
