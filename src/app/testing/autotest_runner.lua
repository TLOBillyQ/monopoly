local autotest_results = require("src.app.testing.autotest_results")

-- 一次宿主启动内逐个跑完 autotest 名单里全部 profile 的编排器。
-- 每个 profile 一局全新对局（全员托管，规则/结算/中断真实端到端演练），
-- 结束条件按优先级：tick 崩溃 > expect 满足 > 对局结束 > 回合/时间预算。
-- 单个 profile 崩溃只记该条 fail，不中断整批。
--
-- 驱动模型：外部（宿主帧回调守护或 headless spec）在每个 tick 后调
-- runner:step(dt)；runner 内部按 poll_seconds 节流观察。不依赖宿主定时器，
-- 宿主与 headless 走同一条路径。
--
-- deps 注入全部环境能力：
--   plan                 有序 profile 名单
--   selector             原始选择器（进 begin 行）
--   start_profile_game   fn(name) -> game，建局+bootstrap+接管+首回合 prime
--   is_ready             fn() -> boolean，运行时是否已就绪（首局已存在）
--   log                  fn(line) 输出结果行
--   expect_for           fn(name) -> expect|nil
--   evaluate             fn(game, expect) -> { ok, failures }
--   count_warns          fn() -> 当前 profile 累计 warn 数
--   poll_seconds / max_player_turns / max_seconds  节奏与预算
local runner_class = {}
runner_class.__index = runner_class

local runner = {}

local DEFAULT_POLL_SECONDS = 0.5
local DEFAULT_MAX_PLAYER_TURNS = 12
local DEFAULT_MAX_SECONDS = 45

local REQUIRED_DEPS = {
  "plan", "selector", "start_profile_game", "is_ready",
  "log", "expect_for", "evaluate", "count_warns",
}

function runner.new(deps)
  assert(type(deps) == "table", "missing autotest runner deps")
  for _, key in ipairs(REQUIRED_DEPS) do
    assert(deps[key] ~= nil, "missing autotest runner dep: " .. key)
  end
  assert(type(deps.plan) == "table" and #deps.plan > 0, "autotest plan must be non-empty")

  local self = setmetatable({}, runner_class)
  self.deps = deps
  self.recorder = autotest_results.new_recorder()
  self.poll_seconds = deps.poll_seconds or DEFAULT_POLL_SECONDS
  self.max_player_turns = deps.max_player_turns or DEFAULT_MAX_PLAYER_TURNS
  self.max_seconds = deps.max_seconds or DEFAULT_MAX_SECONDS
  self.index = 0
  self.game = nil
  self.profile_elapsed = 0
  self.poll_acc = 0
  self.crash_message = nil
  self.started = false
  self.done = false
  return self
end

function runner_class:start()
  assert(not self.started, "autotest runner already started")
  self.started = true
  self.deps.log(autotest_results.begin_line(self.deps.selector, #self.deps.plan))
end

-- 帧守护在 tick 抛错时调用；只影响当前在跑的 profile。
function runner_class:on_tick_error(message)
  if self.done or self.game == nil then
    return
  end
  if self.crash_message == nil then
    self.crash_message = tostring(message)
  end
end

-- 每个 tick 后调用；按 poll_seconds 节流做一次观察/推进。
function runner_class:step(dt)
  if self.done or not self.started then
    return
  end
  if self.game ~= nil then
    self.profile_elapsed = self.profile_elapsed + dt
  end
  self.poll_acc = self.poll_acc + dt
  if self.poll_acc < self.poll_seconds then
    return
  end
  self.poll_acc = 0

  if self.game == nil then
    if self.deps.is_ready() then
      self:_advance()
    end
  else
    self:_observe()
  end
end

-- 顺序尝试启动下一个 profile；建局失败记 fail 并继续，直到有局在跑或收尾。
function runner_class:_advance()
  while true do
    self.index = self.index + 1
    if self.index > #self.deps.plan then
      self:_finish_run()
      return
    end
    local profile_name = self.deps.plan[self.index]
    local ok, game_or_err = pcall(self.deps.start_profile_game, profile_name)
    if ok then
      self.game = game_or_err
      self.profile_elapsed = 0
      self.crash_message = nil
      return
    end
    self:_record({
      profile = profile_name,
      result = "fail",
      reason = "boot_error",
      turns = 0,
      message = tostring(game_or_err),
    })
  end
end

local function _join_failures(failures)
  return table.concat(failures or {}, "; ")
end

function runner_class:_observe()
  if self.crash_message ~= nil then
    self:_finish_profile("fail", "tick_error", self.crash_message)
    return
  end

  local game = self.game
  local profile_name = self.deps.plan[self.index]
  local expect = self.deps.expect_for(profile_name)
  local verdict = self.deps.evaluate(game, expect)

  if expect ~= nil and verdict.ok then
    self:_finish_profile("pass", "expect_met", nil)
    return
  end

  local turns = game.turn and game.turn.turn_count or 0
  local end_reason = nil
  if game.finished then
    end_reason = "game_finished"
  elseif turns >= self.max_player_turns then
    end_reason = "budget_turns"
  elseif self.profile_elapsed >= self.max_seconds then
    end_reason = "budget_seconds"
  end
  if end_reason == nil then
    return
  end

  if expect ~= nil then
    self:_finish_profile("fail", "expect_unmet", _join_failures(verdict.failures))
  else
    self:_finish_profile("pass", end_reason, nil)
  end
end

function runner_class:_finish_profile(result, reason, message)
  local turns = self.game and self.game.turn and self.game.turn.turn_count or 0
  self:_record({
    profile = self.deps.plan[self.index],
    result = result,
    reason = reason,
    turns = turns,
    seconds = self.profile_elapsed,
    warns = self.deps.count_warns(),
    message = message,
  })
  self.game = nil
  self:_advance()
end

function runner_class:_record(entry)
  entry.index = self.index
  entry.seconds = entry.seconds or 0
  entry.warns = entry.warns or 0
  self.recorder:record(entry)
  self.deps.log(autotest_results.profile_line(entry))
end

function runner_class:_finish_run()
  self.done = true
  self.game = nil
  self.deps.log(autotest_results.summary_line(self.recorder))
end

return runner
