local coroutine = coroutine
local debug = debug

---协程状态机，参考 deepfuture 设计
local flow = {}

local STATE
local CURRENT = {
  state = nil,
  thread = nil,
}

-- 循环保护配置
local LOOP_PROTECTION = {
  max_iterations = 1000,  -- 单次 update 最大迭代次数
  iteration_count = 0,
  state_history = {},     -- 状态历史（用于检测循环）
  history_size = 50,      -- 历史记录大小
}

---加载状态表
---@param states table 状态名到函数的映射
function flow.load(states)
  STATE = states
  -- 创建防错状态检查器
  local checker = {}
  for k in pairs(states) do
    checker[k] = k
  end
  flow.state = setmetatable(checker, {
    __index = function(_, k)
      error("Invalid state name " .. tostring(k))
    end
  })
end

---重置循环保护计数器
---在每次外部调用 update 前自动调用
local function _reset_loop_protection()
  LOOP_PROTECTION.iteration_count = 0
  LOOP_PROTECTION.state_history = {}
end

---进入指定状态
---@param state string 状态名
---@param args any 传递给状态的参数
function flow.enter(state, args)
  assert(STATE, "Call flow.load() first")
  -- 如果状态机仍在运行，强制重置（用于测试场景）
  if CURRENT.thread ~= nil then
    flow.reset()
  end
  local f = STATE[state] or error("Missing state " .. tostring(state))
  CURRENT.state = state
  -- 每个状态在独立协程中运行
  CURRENT.thread = coroutine.create(function()
    local next_state, next_args = f(args)
    return "NEXT", next_state, next_args
  end)
  -- 重置循环保护
  _reset_loop_protection()
end

---让出执行权，模拟睡眠等待
---@param ticks number 等待的帧数
function flow.sleep(ticks)
  coroutine.yield("SLEEP", ticks)
end

---内部睡眠协程
local function sleep_co(current, ticks)
  coroutine.yield()
  for _ = 1, ticks - 1 do
    coroutine.yield("YIELD")
  end
  return "RESUME", current
end

---命令处理表
local command = {}

function command.NEXT(state, args)
  CURRENT.thread = nil
  if state == nil then
    CURRENT.state = nil
    return
  end
  flow.enter(state, args)
end

function command.SLEEP(ticks)
  if ticks <= 0 then
    return
  end
  local current = CURRENT.thread
  CURRENT.thread = coroutine.create(sleep_co)
  coroutine.resume(CURRENT.thread, current, ticks)
end

function command.YIELD()
  -- 空操作，仅让出执行权
end

function command.RESUME(thread)
  CURRENT.thread = thread
end

---更新协程执行
local function update_process(thread)
  local ok, cmd, arg1, arg2 = coroutine.resume(thread)
  if ok then
    local handler = command[cmd]
    if handler then
      handler(arg1, arg2)
    end
  else
    error(tostring(cmd) .. "\n" .. debug.traceback(thread))
  end
end

---检测状态循环
---检查是否在短时间内频繁访问同一状态
local function _detect_state_loop(state)
  local history = LOOP_PROTECTION.state_history
  table.insert(history, state)
  if #history > LOOP_PROTECTION.history_size then
    table.remove(history, 1)
  end

  -- 检测最近 10 次状态转移是否都在同一状态间循环
  if #history >= 10 then
    local first = history[1]
    local cycle = true
    for i = 2, 10 do
      if history[i] ~= first then
        cycle = false
        break
      end
    end
    if cycle then
      error("状态死循环检测: 状态 '" .. tostring(first) .. "' 连续重复 10 次")
    end
  end
end

---更新状态机，每帧调用
---@return string|nil 当前状态名
function flow.update()
  if CURRENT.thread then
    LOOP_PROTECTION.iteration_count = LOOP_PROTECTION.iteration_count + 1
    if LOOP_PROTECTION.iteration_count > LOOP_PROTECTION.max_iterations then
      error("状态机迭代次数超限 (" .. LOOP_PROTECTION.max_iterations .. "), 可能存在无限循环")
    end

    update_process(CURRENT.thread)

    if CURRENT.state then
      _detect_state_loop(CURRENT.state)
    end

    return CURRENT.state
  end
  return nil
end

---重置状态机
---清除所有状态，回到初始状态
function flow.reset()
  CURRENT.thread = nil
  CURRENT.state = nil
  _reset_loop_protection()
end

---配置循环保护参数
---@param max_iterations number 最大迭代次数
---@param history_size number 历史记录大小（用于循环检测）
function flow.configure_protection(max_iterations, history_size)
  LOOP_PROTECTION.max_iterations = max_iterations or 1000
  LOOP_PROTECTION.history_size = history_size or 50
end

---获取当前状态
---@return string|nil
function flow.current()
  return CURRENT.state
end

---检查是否在运行
---@return boolean
function flow.is_running()
  return CURRENT.thread ~= nil
end

return flow
