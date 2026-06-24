local M = {}

local _option_id_set = {}
local _cached_option_choice_ref

local function _option_id(option)
  if type(option) == "table" then
    return option.id
  end
  return option
end

local function _clear_option_id_set()
  for k in pairs(_option_id_set) do
    _option_id_set[k] = nil
  end
end

function M.build(choice)
  if not (choice and type(choice.options) == "table") then
    return _option_id_set
  end
  if choice.options == _cached_option_choice_ref then
    return _option_id_set
  end
  _cached_option_choice_ref = choice.options
  _clear_option_id_set()
  for _, option in ipairs(choice.options) do
    local option_id = _option_id(option)
    if option_id ~= nil then
      _option_id_set[tostring(option_id)] = true
    end
  end
  return _option_id_set
end

return M
