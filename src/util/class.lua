local function class(name)
  local cls = {}
  cls.__index = cls
  cls.__name = name or "Class"

  function cls:new(o)
    o = o or {}
    setmetatable(o, cls)
    if o.init then
      o:init()
    end
    return o
  end

  return cls
end

return class
