local parity = require("swarmforge.lib.upstream_parity")

local function read_file(path)
  local handle = assert(io.open(path, "r"))
  local contents = handle:read("*a")
  handle:close()
  return contents
end

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
      receive_mode = "task",
      prompt_file = "swarmforge/roles/coder.prompt",
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
    assert.are.equal("swarmforge/roles/research.prompt", research.prompt_file)
    assert.is_true(research.allows_custom_role)
  end)

  it("models the four-pack starter topology", function()
    local roles = {
      { role = "specifier", worktree = "master", startup_dir = "主工作目录" },
      { role = "coder", worktree = "coder", startup_dir = ".worktrees/coder" },
      { role = "refactorer", worktree = "refactorer", startup_dir = ".worktrees/refactorer" },
      { role = "architect", worktree = "architect", startup_dir = ".worktrees/architect", receive_mode = "batch" },
    }

    for _, expected in ipairs(roles) do
      local plan = parity.plan_role({
        role = expected.role,
        backend = "codex",
        worktree = expected.worktree,
        receive_mode = expected.receive_mode,
        prompt_exists = true,
      })

      assert.are.equal("swarmforge/roles/" .. expected.role .. ".prompt", plan.prompt_file)
      assert.are.equal("swarmforge-" .. expected.role, plan.session)
      assert.are.equal(expected.startup_dir, plan.startup_dir)
      assert.are.equal(expected.receive_mode or "task", plan.receive_mode)
    end
  end)

  it("plans first startup repository initialization", function()
    local plan = parity.plan_initial_repository({
      is_git_repo = false,
      local_paths = { ".swarmforge/", ".worktrees/" },
    })
    assert.is_true(plan.init_git_repo)
    assert.are.equal("master", plan.initial_branch)
    assert.is_true(plan.create_initial_commit)
    assert.are.same({ ".swarmforge/", ".worktrees/" }, plan.gitignore_paths)
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

  it("uses daemon-owned project-local tmux state for handoff wakeups", function()
    local plan = parity.plan_handoff_delivery({
      sessions = {
        { index = 1, role = "specifier", session = "swarmforge-specifier" },
        { index = 2, role = "coder", session = "swarmforge-coder" },
      },
      target = "2",
      draft_file = "tmp/coder-handoff.txt",
      tmux_socket = ".swarmforge/tmux.sock",
      window_index = 1,
      pane_index = 1,
    })

    assert.is_true(plan.daemon_owns_tmux_socket)
    assert.are.equal("swarmforge-coder", plan.target_session)
    assert.are.equal("swarmforge-coder:1.1", plan.target_address)
    assert.are.equal("tmp/coder-handoff.txt", plan.draft_file)
    assert.are.equal(".swarmforge/handoffs", plan.inbox_state_dir)
    assert.are.equal(".swarmforge/tmux.sock", plan.tmux_socket)
    assert.is_true(plan.uses_project_local_socket)
  end)

  it("resolves four-pack handoff wakeup targets by role and index", function()
    local sessions = {
      { index = 1, role = "specifier", session = "swarmforge-specifier" },
      { index = 2, role = "coder", session = "swarmforge-coder" },
      { index = 3, role = "refactorer", session = "swarmforge-refactorer" },
      { index = 4, role = "architect", session = "swarmforge-architect" },
    }

    local by_role = parity.plan_notification({
      sessions = sessions,
      target = "architect",
      message_file = "tmp/architect-handoff.txt",
      tmux_socket = ".swarmforge/tmux.sock",
      window_index = 1,
      pane_index = 1,
    })
    assert.are.equal("swarmforge-architect", by_role.target_session)
    assert.are.equal("swarmforge-architect:1.1", by_role.target_address)

    local by_index = parity.plan_notification({
      sessions = sessions,
      target = "4",
      message_file = "tmp/architect-handoff.txt",
      tmux_socket = ".swarmforge/tmux.sock",
      window_index = 1,
      pane_index = 1,
    })
    assert.are.equal("swarmforge-architect", by_index.target_session)
  end)

  it("uses four-pack daemon handoffs and architect batch mode", function()
    local config = read_file("swarmforge/swarmforge.conf")
    local handoffs = read_file("swarmforge/constitution/articles/handoffs.prompt")
    local specifier = read_file("swarmforge/roles/specifier.prompt")
    local architect = read_file("swarmforge/roles/architect.prompt")

    assert.truthy(config:find("window architect codex architect batch", 1, true))
    assert.truthy(handoffs:find("swarm_handoff.sh <draft-file>", 1, true))
    assert.truthy(specifier:find("When the architect notifies you that the job is complete", 1, true))
    assert.truthy(architect:find("If `ready_for_next.sh` prints `BATCH`", 1, true))
  end)
end)
