local runtime = require("src.presentation.runtime.ui")
local role_id_utils = require("src.core.utils.role_id")

local M = {}

local function _ensure_debug_tables(ui)
  if type(ui.debug_visible_by_role) ~= "table" then
    ui.debug_visible_by_role = {}
  end
  if type(ui.debug_log_enabled_by_role) ~= "table" then
    ui.debug_log_enabled_by_role = {}
  end
end

function M.set_debug_log(state, text)
  local ui = state and state.ui
  if not ui or not ui.set_debug_log then
    return
  end
  ui:set_debug_log(text or "")
end

function M.set_debug_log_for_role(state, role, text)
  local ui = state and state.ui
  if not ui or not ui.set_debug_log or role == nil then
    return
  end
  runtime.with_client_role(role, function()
    ui:set_debug_log(text or "")
  end)
end

function M.set_debug_visible_for_role(state, role, visible)
  local ui = state and state.ui
  if not ui or not ui.set_debug_visible then
    return false
  end
  local role_id = role_id_utils.normalize(runtime.resolve_role_id(role))
  if role_id == nil then
    return false
  end
  local resolved = visible == true
  runtime.with_client_role(role, function()
    ui:set_debug_visible(resolved)
  end)
  _ensure_debug_tables(ui)
  role_id_utils.write(ui.debug_visible_by_role, role_id, resolved)
  role_id_utils.write(ui.debug_log_enabled_by_role, role_id, resolved)
  return true
end

function M.set_debug_visible(state, visible)
  local role = runtime.get_client_role()
  if role ~= nil then
    return M.set_debug_visible_for_role(state, role, visible)
  end
  local ui = state and state.ui
  if not ui or not ui.set_debug_visible then
    return false
  end
  local resolved = visible == true
  -- 启动/兼容路径：无角色上下文时仍允许全局写入，但运行态逻辑不依赖它。
  ui:set_debug_visible(resolved)
  ui.debug_visible = resolved
  return true
end

return M
