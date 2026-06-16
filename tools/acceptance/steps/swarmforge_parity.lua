local number_utils = require("src.foundation.number")
local parity = require("swarmforge.lib.upstream_parity")

local swarmforge_parity_steps = {}

local ROLE_INDEXES = {
  specifier = 1,
  coder = 2,
  refactorer = 3,
  architect = 4,
}

local function _bool(value)
  return value == "是"
end

local function _host_capability(value)
  return {
    has_applescript = value == "AppleScript",
    has_windows_terminal = value == "WindowsTerminal",
  }
end

local function _assert_equal(actual, expected, label)
  if actual ~= expected then
    return nil, tostring(label) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)
  end
  return true
end

local function _session_for_role(role)
  return "swarmforge-" .. tostring(role)
end

function swarmforge_parity_steps.handlers()
  return {
    ["SwarmForge 上游 README 是当前行为基线"] = function(world)
      world.swarmforge_parity = {}
      return true
    end,

    ["环境变量SWARMFORGE_TERMINAL为<环境值>"] = function(world, example)
      world.swarmforge_parity.env_terminal = example["环境值"]
      return true
    end,

    ["未设置SWARMFORGE_TERMINAL"] = function(world)
      world.swarmforge_parity.env_terminal = nil
      return true
    end,

    ["本机终端能力为<本机能力>"] = function(world, example)
      world.swarmforge_parity.host_capability = _host_capability(example["本机能力"])
      return true
    end,

    ["SwarmForge 选择终端后端"] = function(world)
      local capability = world.swarmforge_parity.host_capability or {}
      world.swarmforge_parity.selected_backend = parity.select_terminal_backend({
        env_terminal = world.swarmforge_parity.env_terminal,
        has_applescript = capability.has_applescript,
        has_windows_terminal = capability.has_windows_terminal,
      })
      return true
    end,

    ["选择的终端后端为<后端>"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.selected_backend, example["后端"], "terminal backend")
    end,

    ["终端后端<后端>声明可打开会话<可打开会话>"] = function(world, example)
      world.swarmforge_parity.backend = example["后端"]
      world.swarmforge_parity.can_open_sessions = _bool(example["可打开会话"])
      return true
    end,

    ["终端后端<后端>声明可跟踪窗口<可跟踪窗口>"] = function(world, example)
      world.swarmforge_parity.backend = example["后端"]
      world.swarmforge_parity.tracks_windows = _bool(example["可跟踪窗口"])
      return true
    end,

    ["SwarmForge 打开角色终端"] = function(world)
      world.swarmforge_parity.terminal_plan = parity.plan_terminal_behavior(
        world.swarmforge_parity.backend,
        world.swarmforge_parity.can_open_sessions,
        world.swarmforge_parity.tracks_windows
      )
      return true
    end,

    ["终端行为为<终端行为>"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.terminal_plan.terminal_behavior, example["终端行为"], "terminal behavior")
    end,

    ["watchdog 行为为<watchdog行为>"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.terminal_plan.watchdog_behavior, example["watchdog行为"], "watchdog behavior")
    end,

    ["watchdog 正在跟踪 cleanup 窗口<cleanup窗口>和角色窗口<角色窗口>"] = function(world, example)
      world.swarmforge_parity.cleanup_window = example["cleanup窗口"]
      world.swarmforge_parity.role_window = example["角色窗口"]
      return true
    end,

    ["角色窗口<角色窗口>关闭"] = function(world, example)
      world.swarmforge_parity.watchdog_plan = parity.plan_watchdog_missing_window({
        cleanup_window = world.swarmforge_parity.cleanup_window,
        role_window = world.swarmforge_parity.role_window,
        missing_window = example["角色窗口"],
        replacement_window = "stable-window-id",
      })
      return true
    end,

    ["watchdog 重新打开同一 tmux 会话"] = function(world)
      return _assert_equal(world.swarmforge_parity.watchdog_plan.action, "reopen-session", "watchdog action")
    end,

    ["窗口状态文件更新为<新窗口记录>"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.watchdog_plan.window_record, example["新窗口记录"], "window record")
    end,

    ["cleanup窗口<cleanup窗口>关闭"] = function(world, example)
      world.swarmforge_parity.watchdog_plan = parity.plan_watchdog_missing_window({
        cleanup_window = world.swarmforge_parity.cleanup_window,
        role_window = world.swarmforge_parity.role_window,
        missing_window = example["cleanup窗口"],
      })
      return true
    end,

    ["watchdog 关闭所有配置的 tmux 会话"] = function(world)
      if world.swarmforge_parity.watchdog_plan.close_all_sessions ~= true then
        return nil, "watchdog did not plan to close all sessions"
      end
      return true
    end,

    ["watchdog 关闭剩余的已跟踪窗口"] = function(world)
      if world.swarmforge_parity.watchdog_plan.close_tracked_windows ~= true then
        return nil, "watchdog did not plan to close tracked windows"
      end
      return true
    end,

    ["swarmforge.conf 定义角色<角色>使用后端<后端>和工作树<工作树>"] = function(world, example)
      world.swarmforge_parity.role_config = {
        role = example["角色"],
        backend = example["后端"],
        worktree = example["工作树"],
      }
      return true
    end,

    ["swarmforge.conf 定义角色<角色>使用工作树<工作树>"] = function(world, example)
      world.swarmforge_parity.role_config = {
        role = example["角色"],
        worktree = example["工作树"],
      }
      return true
    end,

    ["项目存在角色提示文件<提示文件>"] = function(world, example)
      world.swarmforge_parity.prompt_file = example["提示文件"]
      return true
    end,

    ["SwarmForge 启动该配置"] = function(world)
      local config = world.swarmforge_parity.role_config
      local plan, err = parity.plan_role({
        role = config.role,
        backend = config.backend,
        worktree = config.worktree,
        receive_mode = config.receive_mode,
        prompt_exists = true,
      })
      if plan == nil then
        return nil, err
      end
      world.swarmforge_parity.role_plan = plan
      return true
    end,

    ["运行时创建 tmux 会话<会话>"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.role_plan.session, example["会话"], "tmux session")
    end,

    ["该角色读取<提示文件>和 layered constitution"] = function(world, example)
      local plan = world.swarmforge_parity.role_plan
      if plan.reads_layered_constitution ~= true then
        return nil, "role did not read layered constitution"
      end
      return _assert_equal(plan.prompt_file, example["提示文件"], "prompt file")
    end,

    ["该角色在<启动目录>中启动"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.role_plan.startup_dir, example["启动目录"], "startup dir")
    end,

    ["SwarmForge 校验项目配置"] = function(world)
      local config = world.swarmforge_parity.role_config
      local plan, err = parity.plan_role({
        role = config.role,
        backend = config.backend,
        worktree = config.worktree,
        receive_mode = config.receive_mode,
        prompt_exists = true,
      })
      if plan == nil then
        return nil, err
      end
      world.swarmforge_parity.role_plan = plan
      return true
    end,

    ["配置要求存在提示文件<提示文件>"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.role_plan.prompt_file, example["提示文件"], "required prompt")
    end,

    ["角色集合不限制为固定内置角色"] = function(world)
      if world.swarmforge_parity.role_plan.allows_custom_role ~= true then
        return nil, "custom role was not allowed"
      end
      return true
    end,

    ["工作目录不是 git 仓库"] = function(world)
      world.swarmforge_parity.is_git_repo = false
      world.swarmforge_parity.local_paths = {}
      return true
    end,

    ["SwarmForge 首次启动"] = function(world)
      world.swarmforge_parity.initial_repo_plan = parity.plan_initial_repository({
        is_git_repo = world.swarmforge_parity.is_git_repo,
        local_paths = world.swarmforge_parity.local_paths,
      })
      return true
    end,

    ["工作目录被初始化为 git 仓库"] = function(world)
      if world.swarmforge_parity.initial_repo_plan.init_git_repo ~= true then
        return nil, "initial startup did not initialize git"
      end
      return true
    end,

    ["初始分支名为master"] = function(world)
      return _assert_equal(world.swarmforge_parity.initial_repo_plan.initial_branch, "master", "initial branch")
    end,

    ["路径<本地运行路径>写入 git ignore"] = function(world, example)
      world.swarmforge_parity.local_paths[#world.swarmforge_parity.local_paths + 1] = example["本地运行路径"]
      world.swarmforge_parity.initial_repo_plan = parity.plan_initial_repository({
        is_git_repo = world.swarmforge_parity.is_git_repo,
        local_paths = world.swarmforge_parity.local_paths,
      })
      return true
    end,

    ["首次启动创建初始提交"] = function(world)
      if world.swarmforge_parity.initial_repo_plan.create_initial_commit ~= true then
        return nil, "initial startup did not plan initial commit"
      end
      return true
    end,

    ["SwarmForge 准备角色工作目录"] = function(world)
      local config = world.swarmforge_parity.role_config
      world.swarmforge_parity.worktree_plan = parity.plan_worktree(config.worktree)
      return true
    end,

    ["工作树创建行为为<创建行为>"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.worktree_plan.create_behavior, example["创建行为"], "worktree behavior")
    end,

    ["角色启动目录为<启动目录>"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.worktree_plan.startup_dir, example["启动目录"], "role startup dir")
    end,

    ["SwarmForge 已为角色<目标角色>记录会话<目标会话>"] = function(world, example)
      local role = example["目标角色"]
      world.swarmforge_parity.sessions = {
        {
          index = ROLE_INDEXES[role] or 1,
          role = role,
          session = example["目标会话"],
        },
      }
      return true
    end,

    ["handoff 消息保存在<消息文件>"] = function(world, example)
      world.swarmforge_parity.message_file = example["消息文件"]
      return true
    end,

    ["发送通知到<目标>"] = function(world, example)
      local plan, err = parity.plan_handoff_delivery({
        sessions = world.swarmforge_parity.sessions,
        target = example["目标"],
        draft_file = world.swarmforge_parity.message_file,
        tmux_socket = ".swarmforge/tmux-socket",
        window_index = world.swarmforge_parity.window_index or 0,
        pane_index = world.swarmforge_parity.pane_index or 0,
      })
      if plan == nil then
        return nil, err
      end
      world.swarmforge_parity.notification_plan = plan
      return true
    end,

    ["handoff daemon 从项目本地 tmux socket 唤醒角色"] = function(world)
      if world.swarmforge_parity.notification_plan.uses_project_local_socket ~= true then
        return nil, "handoff daemon did not use project local socket"
      end
      return true
    end,

    ["消息内容来自<消息文件>"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.notification_plan.draft_file, example["消息文件"], "message file")
    end,

    ["目标解析为<目标会话>"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.notification_plan.target_session, example["目标会话"], "target session")
    end,

    ["项目路径为<项目路径>"] = function(world, example)
      world.swarmforge_parity.project_path = example["项目路径"]
      return true
    end,

    ["tmux 配置使用窗口索引<窗口索引>和 pane 索引<pane索引>"] = function(world, example)
      world.swarmforge_parity.window_index = number_utils.to_integer(example["窗口索引"])
      world.swarmforge_parity.pane_index = number_utils.to_integer(example["pane索引"])
      return true
    end,

    ["SwarmForge 向角色<角色>发送启动或通知命令"] = function(world, example)
      local role = example["角色"]
      local session = _session_for_role(role)
      local plan, err = parity.plan_notification({
        sessions = {
          { index = ROLE_INDEXES[role] or 1, role = role, session = session },
        },
        target = role,
        message_file = "tmp/" .. role .. "-handoff.txt",
        tmux_socket = ".swarmforge/tmux-socket",
        window_index = world.swarmforge_parity.window_index,
        pane_index = world.swarmforge_parity.pane_index,
      })
      if plan == nil then
        return nil, err
      end
      world.swarmforge_parity.notification_plan = plan
      return true
    end,

    ["命令使用项目专属 tmux socket"] = function(world)
      if world.swarmforge_parity.notification_plan.uses_project_local_socket ~= true then
        return nil, "command did not use project tmux socket"
      end
      return true
    end,

    ["tmux 目标地址为<目标地址>"] = function(world, example)
      return _assert_equal(world.swarmforge_parity.notification_plan.target_address, example["目标地址"], "tmux target")
    end,
  }
end

return swarmforge_parity_steps
