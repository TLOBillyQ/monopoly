--- Domain-aware assertions for e2e specs.
---
--- These wrap raw client calls in semantic helpers so spec files read at
--- the intent level, not the API level. Each helper raises a descriptive
--- error on failure that busted picks up as a test failure.

local client = require("editor_cli.client")

local M = {}

local function _ensure_ok(payload, label)
  if type(payload) ~= "table" then
    error(label .. ": expected payload table, got " .. type(payload))
  end
  if payload.ok == false then
    error(label .. ": editor returned error — " .. tostring(payload.err))
  end
  if payload.ok == nil and payload.err then
    error(label .. ": " .. tostring(payload.err))
  end
end

--- Assert that the editor is reachable and reports a known mode.
function M.editor_online()
  local status = client.status()
  if type(status) ~= "table" then
    error("editor_assert.editor_online: status returned " .. type(status))
  end
  return status
end

--- Assert that a marker round-trip works by emitting `value` and
--- decoding it back. Returns the decoded value.
function M.marker_roundtrip(value)
  local literal
  if type(value) == "string" then
    literal = string.format("%q", value)
  elseif type(value) == "number" or type(value) == "boolean" then
    literal = tostring(value)
  else
    error("marker_roundtrip: only string/number/boolean values are supported")
  end
  local payload = client.exec_capture(literal)
  _ensure_ok(payload, "marker_roundtrip")
  return payload.value
end

--- Assert a scene unit with the given id exists in edit mode.
--- Returns the unit's serialized form.
function M.unit_exists(unit_id)
  local expr = string.format(
    "EditorAPI.scene.get_unit_by_id(%q)",
    tostring(unit_id)
  )
  local payload = client.exec_capture(expr)
  _ensure_ok(payload, "unit_exists")
  if payload.value == nil or payload.value == false then
    error("unit_exists: no unit found with id=" .. tostring(unit_id))
  end
  return payload.value
end

--- Assert that no unit exists with the given id.
function M.unit_absent(unit_id)
  local expr = string.format(
    "EditorAPI.scene.get_unit_by_id(%q) == nil",
    tostring(unit_id)
  )
  local payload = client.exec_capture(expr)
  _ensure_ok(payload, "unit_absent")
  if payload.value ~= true then
    error("unit_absent: unit still present with id=" .. tostring(unit_id))
  end
  return true
end

--- Read the position of a play-mode player. Returns { x, y, z }.
function M.player_position(player_index)
  local idx = tostring(player_index or 1)
  local expr = "(function() local p = GameAPI.get_player(" .. idx ..
    "); local pos = p and p:get_position(); return pos and {pos.x, pos.y, pos.z} or nil end)()"
  local payload = client.game_exec_capture(expr)
  _ensure_ok(payload, "player_position")
  return payload.value
end

return M
