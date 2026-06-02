local parity = require("swarmforge.lib.upstream_parity")

describe("swarmforge upstream parity", function()
  it("selects terminal backend from environment before host capabilities", function()
    assert.are.equal("ghostty", parity.select_terminal_backend({
      env_terminal = "ghostty",
      has_applescript = true,
      has_windows_terminal = true,
    }))
    assert.are.equal("terminal-app", parity.select_terminal_backend({
      env_terminal = "terminal",
      has_windows_terminal = true,
    }))
    assert.are.equal("windows-terminal", parity.select_terminal_backend({
      env_terminal = "wt",
      has_applescript = true,
    }))
    assert.are.equal("none", parity.select_terminal_backend({
      env_terminal = "fallback",
      has_applescript = true,
    }))
  end)

  it("selects default terminal backend from host capabilities", function()
    assert.are.equal("terminal-app", parity.select_terminal_backend({
      has_applescript = true,
      has_windows_terminal = true,
    }))
    assert.are.equal("windows-terminal", parity.select_terminal_backend({
      has_windows_terminal = true,
    }))
    assert.are.equal("none", parity.select_terminal_backend({}))
  end)

  it("plans terminal launch and watchdog behavior from backend capabilities", function()
    assert.are.same({
      terminal_behavior = "每个角色打开可跟踪窗口",
      watchdog_behavior = "启动watchdog",
    }, parity.plan_terminal_behavior("terminal-app", true, true))

    assert.are.same({
      terminal_behavior = "每个角色打开可跟踪标签",
      watchdog_behavior = "启动watchdog",
    }, parity.plan_terminal_behavior("ghostty", true, true))

    assert.are.same({
      terminal_behavior = "每个角色打开窗口",
      watchdog_behavior = "跳过watchdog",
    }, parity.plan_terminal_behavior("windows-terminal", true, false))

    assert.are.same({
      terminal_behavior = "当前 shell 附加 cleanup",
      watchdog_behavior = "跳过watchdog",
    }, parity.plan_terminal_behavior("none", false, false))
  end)

  it("models watchdog recovery and cleanup shutdown", function()
    local role_result = parity.plan_watchdog_missing_window({
      cleanup_window = "win-1",
      role_window = "win-2",
      missing_window = "win-2",
      replacement_window = "win-3",
    })
    assert.are.equal("reopen-session", role_result.action)
    assert.are.equal("角色窗口使用新稳定窗口id", role_result.window_record)

    local cleanup_result = parity.plan_watchdog_missing_window({
      cleanup_window = "win-1",
      role_window = "win-2",
      missing_window = "win-1",
    })
    assert.are.equal("shutdown-swarm", cleanup_result.action)
    assert.is_true(cleanup_result.close_all_sessions)
    assert.is_true(cleanup_result.close_tracked_windows)
  end)

  it("derives role topology from local config without built-in role restrictions", function()
    assert.are.same({
      role = "coder",
      backend = "codex",
      worktree = "coder",
      prompt_file = "swarmforge/coder.prompt",
      session = "swarmforge-coder",
      startup_dir = ".worktrees/coder",
      reads_layered_constitution = true,
      allows_custom_role = true,
    }, parity.plan_role({
      role = "coder",
      backend = "codex",
      worktree = "coder",
      prompt_exists = true,
    }))

    local research = parity.plan_role({
      role = "research",
      backend = "grok",
      worktree = "research",
      prompt_exists = true,
    })
    assert.are.equal("swarmforge/research.prompt", research.prompt_file)
    assert.is_true(research.allows_custom_role)
  end)

  it("plans first startup repository initialization", function()
    local plan = parity.plan_initial_repository({
      is_git_repo = false,
      local_paths = { ".swarmforge/", ".worktrees/", "swarmtools/" },
    })
    assert.is_true(plan.init_git_repo)
    assert.are.equal("master", plan.initial_branch)
    assert.is_true(plan.create_initial_commit)
    assert.are.same({ ".swarmforge/", ".worktrees/", "swarmtools/" }, plan.gitignore_paths)
  end)

  it("creates worktrees only for named worktree roles", function()
    assert.are.same({
      create_behavior = "创建.worktrees/coder",
      startup_dir = ".worktrees/coder",
    }, parity.plan_worktree("coder"))

    assert.are.same({
      create_behavior = "不创建.worktrees/master",
      startup_dir = "主工作目录",
    }, parity.plan_worktree("master"))

    assert.are.same({
      create_behavior = "不创建.worktrees/none",
      startup_dir = "主工作目录",
    }, parity.plan_worktree("none"))
  end)

  it("uses project-local tmux state for notification targets", function()
    local plan = parity.plan_notification({
      sessions = {
        { index = 1, role = "specifier", session = "swarmforge-specifier" },
        { index = 2, role = "coder", session = "swarmforge-coder" },
      },
      target = "2",
      message_file = "tmp/coder-handoff.txt",
      tmux_socket = ".swarmforge/tmux.sock",
      window_index = 1,
      pane_index = 1,
    })

    assert.are.equal("swarmforge-coder", plan.target_session)
    assert.are.equal("swarmforge-coder:1.1", plan.target_address)
    assert.are.equal("tmp/coder-handoff.txt", plan.message_file)
    assert.are.equal(".swarmforge/tmux.sock", plan.tmux_socket)
    assert.is_true(plan.uses_project_local_socket)
  end)
end)
