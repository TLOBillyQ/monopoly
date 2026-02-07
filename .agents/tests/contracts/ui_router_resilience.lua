local ui_event_router = require("src.ui.UIEventRouter")
local turn_dispatch = require("src.game.turn.TurnDispatch")

local function _assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local function _with_patches(patches, fn)
  local originals = {}
  for i, patch in ipairs(patches) do
    local target = patch.target or _G
    originals[i] = { target = target, key = patch.key, value = target[patch.key] }
    target[patch.key] = patch.value
  end
  local handler = debug and debug.traceback or function(err) return err end
  local ok, err = xpcall(fn, handler)
  for i = #originals, 1, -1 do
    local patch = originals[i]
    patch.target[patch.key] = patch.value
  end
  if not ok then
    error(err)
  end
end

local nodes = {}
local function _make_node(name)
  local node = { name = name }
  function node:listen(_, callback)
    self._callback = callback
    return { destroy = function() end }
  end
  nodes[name] = node
  return node
end

local function _node_for(name)
  if not nodes[name] then
    _make_node(name)
  end
  return nodes[name]
end

_with_patches({
  {
    key = "UIManager",
    value = {
      EVENT = { CLICK = "click" },
      query_nodes_by_name = function(name)
        if nodes[name] then
          return { nodes[name] }
        end
        return nil
      end,
    },
  },
  { key = "GlobalAPI", value = { show_tips = function() end } },
}, function()
  package.loaded["Data.UIManagerNodes"] = {
    { "通用选择_选项_01", "EButton" },
  }

  _node_for("通用选择_选项_01")

  local actions = {}
  local original_dispatch = turn_dispatch.dispatch_action
  turn_dispatch.dispatch_action = function(_, _, action)
    table.insert(actions, action)
    return { status = "applied" }
  end

  local state = {
    ui_model = {
      choice = {
        id = 1,
        options = { { id = "opt1", label = "Option" } },
        allow_cancel = true,
      },
    },
    ui_event_router_registered = {},
    ui_event_router_listeners = {},
  }

  ui_event_router.bind(state, function()
    return {}
  end, {})

  nodes["通用选择_选项_01"]._callback({})
  _assert_eq(#actions, 1, "choice_select should dispatch once")
  _assert_eq(actions[1].type, "choice_select", "choice_select type")

  state.ui_model = {}
  nodes["通用选择_选项_01"]._callback({})
  _assert_eq(#actions, 1, "missing choice should not dispatch")

  turn_dispatch.dispatch_action = original_dispatch
end)

print("Contract ui_router_resilience passed")
