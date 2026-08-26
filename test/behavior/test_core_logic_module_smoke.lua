-- Re-requires key core_logic modules inside it() bodies so the debug hook
-- captures function-definition lines that otherwise fire before any hook.
-- The original package.loaded entry is restored after each re-require so the
-- new (hook-captured) table does not leak to other specs that hold lexically
-- captured references to the original module.
local function _refire(name)
  local saved = package.loaded[name]
  package.loaded[name] = nil
  local m = require(name)
  package.loaded[name] = saved
  assert(type(m) == "table", "expected table for " .. name)
  return m
end

-- Each entry is { module_path[, override_label] }. The default label is
-- "<rel> — fires all function definitions under hook" where <rel> is the
-- module path with the "src." prefix stripped. Two cases use override labels
-- to keep wording the coder fix established.
local _DEFAULT_HOOK_SUBJECT = "fires all function definitions under hook"
local _CASES = {
  { "src.state.runtime" },
  { "src.state.visual_hold" },
  { "src.rules.items.post_effects" },
  { "src.turn.waits.choice_timeout" },
  { "src.rules.choice_handlers.item" },
  { "src.rules.items.phase" },
  { "src.turn.phases.land" },
  { "src.turn.deadlines" },
  { "src.turn.loop.ports", "turn.loop.ports — fires module-level base_ports construction" },
  { "src.foundation.log" },
  { "src.turn.loop", "turn.loop (init) — fires module-level setup under hook" },
  { "src.app.roster" },
  { "src.rules.items.availability" },
  { "src.rules.land.landing_rules" },
  { "src.rules.land.effect_base" },
  { "src.rules.board.direction" },
}

local function _label(case)
  if case[2] then return case[2] end
  local rel = case[1]:gsub("^src%.", "")
  return rel .. " — " .. _DEFAULT_HOOK_SUBJECT
end

-- 原生 LuaUnit 迁移:describe + 场景循环(逐例注册方法)→ 单 Test*
-- 类 + 循环注册方法(方法名 = "test_" .. label,label 含破折号/括号,字符串键
-- 逐字保留;均以 test 开头,被 registry 按 test 前缀发现)。用例数与改写前
-- 一一对应(16 例)。
TestCoreLogicModuleSmoke = {}

for _, case in ipairs(_CASES) do
  TestCoreLogicModuleSmoke["test_" .. _label(case)] = function(self)
    _refire(case[1])
  end
end


return TestCoreLogicModuleSmoke
