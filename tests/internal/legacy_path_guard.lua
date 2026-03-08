local retired_path_parts = {
  { "src", "core", "runtime_facade" },
  { "src", "game", "turn_engine" },
  { "src", "game", "legacy", "turn_engine" },
  { "src", "presentation", "adapter" },
  { "src", "presentation", "canvas_runtime" },
  { "src", "game", "systems", "market", "service" },
  { "src", "app", "bootstrap", "runtime_install" },
  { "src", "core", "ports", "turn_ui_sync_shared" },
  { "src", "core", "choice", "choice_contract" },
  { "src", "core", "choice", "choice_route_policy" },
  { "src", "game", "systems", "choices", "choice_registry" },
  { "src", "game", "systems", "choices", "choice_resolver" },
  { "src", "game", "systems", "choices", "choice_handlers" },
  { "src", "presentation", "input", "ui_intent_dispatcher" },
  { "src", "presentation", "runtime", "host_runtime" },
  { "src", "presentation", "runtime", "ui_view_service" },
  { "src", "presentation", "runtime", "presentation_ports", "common" },
  { "src", "presentation", "runtime", "presentation_ports", "modal_ports" },
  { "src", "presentation", "runtime", "presentation_ports", "anim_ports" },
  { "src", "presentation", "runtime", "presentation_ports", "ui_sync_ports" },
  { "src", "presentation", "runtime", "presentation_ports", "debug_ports" },
  { "src", "presentation", "runtime", "presentation_ports", "state_ports" },
  { "src", "presentation", "runtime", "presentation_ports", "clock_ports" },
  { "src", "presentation", "runtime", "presentation_ports", "ui_sync" },
  { "src", "presentation", "view", "widgets", "ui_choice" },
  { "src", "presentation", "view", "widgets", "ui_modal_presenter" },
  { "src", "presentation", "view", "widgets", "ui_panel" },
  { "src", "presentation", "view", "widgets", "ui_panel_presenter" },
  { "src", "presentation", "view", "widgets", "ui_panel_player_slots" },
  { "src", "presentation", "view", "widgets", "ui_panel_cash_delta" },
  { "src", "presentation", "view", "widgets", "ui_turn_effects" },
  { "src", "presentation", "view", "render", "status_3_d_service" },
  { "src", "presentation", "view", "render", "status3d_service" },
  { "src", "presentation", "input", "ui_canvas_coordinator" },
  { "src", "presentation", "input", "ui_choice_route_policy" },
  { "src", "presentation", "input", "ui_event_bindings" },
  { "src", "presentation", "input", "ui_event_intents" },
  { "src", "presentation", "input", "ui_event_state" },
  { "src", "presentation", "input", "ui_input_lock_policy" },
  { "src", "presentation", "input", "ui_modal_state_coordinator" },
  { "src", "presentation", "input", "ui_role_control_lock_policy" },
  { "src", "presentation", "input", "ui_touch_policy" },
  { "src", "game", "core", "runtime", "game_state_players" },
  { "src", "game", "core", "runtime", "game_state_tiles" },
  { "src", "game", "core", "runtime", "game_state_turn" },
  { "src", "game", "flow", "turn", "gameplay_loop" },
  { "src", "game", "flow", "turn", "gameplay_loop_ports" },
  { "src", "game", "flow", "turn", "gameplay_loop_runtime" },
  { "src", "game", "flow", "turn", "gameplay_loop_tick_flow" },
  { "src", "game", "flow", "turn", "gameplay_loop_tick_steps" },
  { "src", "game", "flow", "turn", "gameplay_loop_ui_sync_defaults" },
  { "src", "presentation", "view", "render", "market_view" },
  { "src", "presentation", "view", "render", "market_view_controls" },
  { "src", "presentation", "view", "render", "market_view_slots" },
  { "src", "presentation", "view", "render", "action_anim_registry" },
  { "src", "presentation", "view", "render", "action_anim_handlers" },
  { "src", "presentation", "view", "render", "action_anim_dice" },
  { "src", "presentation", "view", "render", "action_anim_units" },
  { "src", "presentation", "view", "render", "action_anim_tip_text" },
  { "src", "presentation", "view", "render", "action_anim_overlay_compute" },
  { "src", "presentation", "view", "render", "action_anim_overlay_runtime" },
  { "src", "presentation", "view", "render", "action_anim_unit_overlay" },
}

local scan_roots = { "src", "tests" }

local function is_windows()
  return package.config:sub(1, 1) == "\\"
end

local function build_list_command(root)
  if is_windows() then
    local win_root = root:gsub("/", "\\")
    return 'dir /b /s /a-d "' .. win_root .. '\\*.lua" 2>nul'
  end
  return 'find "' .. root .. '" -type f -name "*.lua" 2>/dev/null'
end

local function collect_lua_files(root)
  local process = io.popen(build_list_command(root))
  if not process then
    return nil, "cannot run list command for root: " .. root
  end

  local files = {}
  for line in process:lines() do
    if line and line ~= "" then
      files[#files + 1] = line
    end
  end

  local ok = process:close()
  if ok == nil or ok == false then
    return nil, "list command failed for root: " .. root
  end

  return files
end

local function normalize_path(path)
  return path:gsub("\\", "/")
end

local function should_skip(path)
  local normalized = normalize_path(path)
  return normalized:match("^vendor/") ~= nil
    or normalized:match("^Config/") ~= nil
    or normalized:match("^Data/") ~= nil
    or normalized:match("^tests/internal/legacy_path_guard%.lua$") ~= nil
end

local function join_path(parts)
  return table.concat(parts, ".")
end

local retired_paths = {}
for _, parts in ipairs(retired_path_parts) do
  retired_paths[#retired_paths + 1] = join_path(parts)
end

local files = {}
for _, root in ipairs(scan_roots) do
  local root_files, err = collect_lua_files(root)
  if not root_files then
    io.stderr:write("legacy_path_guard error: ", err, "\n")
    os.exit(1)
  end

  for _, path in ipairs(root_files) do
    if not should_skip(path) then
      files[#files + 1] = path
    end
  end
end

local violations = {}
for _, path in ipairs(files) do
  local file = io.open(path, "r")
  if file then
    local line_number = 0
    for line in file:lines() do
      line_number = line_number + 1
      if not line:match("^%s*%-%-") then
        for _, retired_path in ipairs(retired_paths) do
          if line:find(retired_path, 1, true) then
            violations[#violations + 1] = {
              path = normalize_path(path),
              line = line_number,
              retired_path = retired_path,
              text = line,
            }
          end
        end
      end
    end
    file:close()
  end
end

if #violations > 0 then
  io.stderr:write("legacy_path_guard found retired module paths:\n")
  for _, violation in ipairs(violations) do
    io.stderr:write(
      "legacy_path_guard: ",
      violation.path,
      ":",
      tostring(violation.line),
      " contains ",
      violation.retired_path,
      "\n"
    )
    io.stderr:write("  ", violation.text, "\n")
  end
  os.exit(1)
end

print("legacy_path_guard ok")
