local M = {}

local function _normalize_backend(value)
  local backend = tostring(value or ""):lower()
  if backend == "terminal" or backend == "terminal.app" then
    return "terminal-app"
  end
  if backend == "windows" or backend == "wt" then
    return "windows-terminal"
  end
  if backend == "current" or backend == "fallback" then
    return "none"
  end
  if backend == "" then
    return nil
  end
  return backend
end

local function _main_dir_for_worktree(worktree)
  if worktree == "none" or worktree == "master" then
    return "主工作目录"
  end
  return ".worktrees/" .. tostring(worktree)
end

local function _session_name(role)
  return "swarmforge-" .. tostring(role)
end

function M.select_terminal_backend(opts)
  opts = opts or {}
  local env_backend = _normalize_backend(opts.env_terminal)
  if env_backend ~= nil then
    return env_backend
  end
  if opts.has_applescript == true then
    return "terminal-app"
  end
  if opts.has_windows_terminal == true then
    return "windows-terminal"
  end
  return "none"
end

function M.plan_terminal_behavior(backend, can_open_sessions, tracks_windows)
  if can_open_sessions ~= true then
    return {
      terminal_behavior = "当前 shell 附加 cleanup",
      watchdog_behavior = "跳过watchdog",
    }
  end

  local terminal_behavior = "每个角色打开窗口"
  if backend == "terminal-app" then
    terminal_behavior = "每个角色打开可跟踪窗口"
  elseif backend == "ghostty" then
    terminal_behavior = "每个角色打开可跟踪标签"
  end

  return {
    terminal_behavior = terminal_behavior,
    watchdog_behavior = tracks_windows == true and "启动watchdog" or "跳过watchdog",
  }
end

function M.plan_watchdog_missing_window(opts)
  opts = opts or {}
  if opts.missing_window == opts.cleanup_window then
    return {
      action = "shutdown-swarm",
      close_all_sessions = true,
      close_tracked_windows = true,
    }
  end

  if opts.missing_window == opts.role_window then
    return {
      action = "reopen-session",
      replacement_window = opts.replacement_window,
      window_record = "角色窗口使用新稳定窗口id",
    }
  end

  return {
    action = "keep-watching",
  }
end

function M.plan_role(opts)
  opts = opts or {}
  local role = tostring(opts.role or "")
  local worktree = tostring(opts.worktree or "none")
  local receive_mode = tostring(opts.receive_mode or "task")
  local prompt_file = "swarmforge/roles/" .. role .. ".prompt"

  if opts.prompt_exists == false then
    return nil, "missing role prompt " .. prompt_file
  end

  return {
    role = role,
    backend = opts.backend,
    worktree = worktree,
    receive_mode = receive_mode,
    prompt_file = prompt_file,
    session = _session_name(role),
    startup_dir = _main_dir_for_worktree(worktree),
    reads_layered_constitution = true,
    allows_custom_role = true,
  }
end

function M.plan_initial_repository(opts)
  opts = opts or {}
  return {
    init_git_repo = opts.is_git_repo ~= true,
    initial_branch = "master",
    gitignore_paths = opts.local_paths or {},
    create_initial_commit = opts.is_git_repo ~= true,
  }
end

function M.plan_worktree(worktree)
  worktree = tostring(worktree or "none")
  if worktree == "none" or worktree == "master" then
    return {
      create_behavior = "不创建.worktrees/" .. worktree,
      startup_dir = "主工作目录",
    }
  end

  return {
    create_behavior = "创建.worktrees/" .. worktree,
    startup_dir = ".worktrees/" .. worktree,
  }
end

function M.plan_notification(opts)
  opts = opts or {}
  local target = tostring(opts.target or ""):lower()
  local target_session

  for _, entry in ipairs(opts.sessions or {}) do
    if target == tostring(entry.index or ""):lower() or target == tostring(entry.role or ""):lower() then
      target_session = entry.session
      break
    end
  end

  if target_session == nil then
    return nil, "unknown target: " .. tostring(opts.target)
  end

  local window_index = opts.window_index or 0
  local pane_index = opts.pane_index or 0
  return {
    target_session = target_session,
    target_address = target_session .. ":" .. tostring(window_index) .. "." .. tostring(pane_index),
    message_file = opts.message_file,
    tmux_socket = opts.tmux_socket,
    uses_project_local_socket = opts.tmux_socket ~= nil and tostring(opts.tmux_socket) ~= "",
  }
end

function M.plan_handoff_delivery(opts)
  opts = opts or {}
  local notification, err = M.plan_notification(opts)
  if notification == nil then
    return nil, err
  end

  return {
    daemon_owns_tmux_socket = true,
    draft_file = opts.draft_file,
    inbox_state_dir = ".swarmforge/handoffs",
    target_session = notification.target_session,
    target_address = notification.target_address,
    tmux_socket = notification.tmux_socket,
    uses_project_local_socket = notification.uses_project_local_socket,
  }
end

return M
