local contract_helper = {}

function contract_helper.resolve_required_port(game, field_name, port_name)
  assert(game ~= nil, "missing game for " .. tostring(port_name))
  local port = game[field_name]
  assert(type(port) == "table", "missing game." .. tostring(field_name))
  return port
end

function contract_helper.resolve_required_method(game, field_name, port_name, method_name)
  local port = contract_helper.resolve_required_port(game, field_name, port_name)
  local fn = port[method_name]
  assert(type(fn) == "function", "missing " .. tostring(port_name) .. "." .. tostring(method_name))
  return fn
end

function contract_helper.resolve_method(game, field_name, method_name)
  return contract_helper.resolve_required_method(game, field_name, field_name, method_name)
end

function contract_helper.resolve_optional_port(game, field_name, fallback_port)
  if game ~= nil then
    local port = game[field_name]
    if type(port) == "table" then
      return port
    end
  end
  if type(fallback_port) == "table" then
    return fallback_port
  end
  return nil
end

function contract_helper.resolve_optional_method(game, field_name, method_name, opts)
  local options = opts or {}
  local port = contract_helper.resolve_optional_port(game, field_name, options.fallback_port)
  if type(port) ~= "table" then
    return nil
  end
  local fn = port[method_name]
  if type(fn) ~= "function" then
    return nil
  end
  return fn, port
end

function contract_helper.call_required_method(game, field_name, port_name, method_name, ...)
  local fn = contract_helper.resolve_required_method(game, field_name, port_name, method_name)
  return fn(...)
end

function contract_helper.call_optional_method(game, field_name, method_name, opts, ...)
  local fn = contract_helper.resolve_optional_method(game, field_name, method_name, opts)
  if type(fn) ~= "function" then
    local options = opts or {}
    return options.default_result
  end
  return fn(...)
end

return contract_helper

--[[ mutate4lua-manifest
version=4
projectHash=801a0b7498e572c0
scope.0.id=chunk:src/rules/ports/contract_helper.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=62
scope.0.semanticHash=f400a4f3fa6ffa28
scope.1.id=function:contract_helper.resolve_required_port
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=8
scope.1.semanticHash=0008eae2ce8f502a
scope.2.id=function:contract_helper.resolve_required_method
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=15
scope.2.semanticHash=d485e7098e6118d5
scope.3.id=function:contract_helper.resolve_method
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=19
scope.3.semanticHash=609439c0a328e2dc
scope.4.id=function:contract_helper.resolve_optional_port
scope.4.kind=function
scope.4.startLine=21
scope.4.endLine=32
scope.4.semanticHash=ab856a6a4655503e
scope.5.id=function:contract_helper.resolve_optional_method
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=45
scope.5.semanticHash=6f9728373165921f
scope.6.id=function:contract_helper.call_required_method
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=50
scope.6.semanticHash=20f09dbb038a2fd4
scope.7.id=function:contract_helper.call_optional_method
scope.7.kind=function
scope.7.startLine=52
scope.7.endLine=59
scope.7.semanticHash=788f76aaf93aa154
]]
