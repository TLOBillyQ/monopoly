---@diagnostic disable: undefined-global
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")

local arch_policy = require("packages.arch_policy")
local policy_scan = require("packages.arch_policy.scan")
local guard = require("test.guards.lib.arch_policy_guard")

-- #92:层边界门禁吃 `tools/packages/arch_policy/policy.json` 这一份 policy。
-- 真实仓库恒为绿(没有违规就是没有),所以合法与违规两侧一律用合成图喂给
-- guard 自己的判定接缝 check_graph,证明规则真的会拦。
local POLICY = assert(arch_policy.load(arch_policy.DEFAULT_POLICY_PATH))

local function _check(modules, edges, policy)
  return guard.check_graph(policy or POLICY, { modules = modules, edges = edges })
end

local LEGAL_MODULES = {
  "src.app.init",
  "src.foundation.number",
  "src.player.actions.balance",
  "src.rules.bootstrap",
  "src.state.game",
  "src.turn.loop",
  "src.ui.panel",
}

local LEGAL_EDGES = {
  { from = "src.app.init", to = "src.ui.panel" },
  { from = "src.app.init", to = "src.rules.bootstrap" },
  { from = "src.ui.panel", to = "src.turn.loop" },
  { from = "src.ui.panel", to = "src.foundation.number" },
  { from = "src.turn.loop", to = "src.player.actions.balance" },
  { from = "src.turn.loop", to = "src.rules.bootstrap" },
  { from = "src.rules.bootstrap", to = "src.state.game" },
  { from = "src.state.game", to = "src.foundation.number" },
}

local function _violations(modules, edges, policy)
  local result = arch_policy.check(policy or POLICY, { modules = modules, edges = edges })
  return result.violations
end

local function _only(modules, edges, policy)
  local violations = _violations(modules, edges, policy)
  lu.assertEquals(#violations, 1, guard.describe(violations[1] or {}))
  return violations[1]
end

TestArchPolicy = {}

function TestArchPolicy:test_declared_layers_match_the_registry()
  lu.assertEquals(arch_policy.declared_layer(POLICY, "src.app.init"), 1)
  lu.assertEquals(arch_policy.declared_layer(POLICY, "src.host.units"), 2)
  lu.assertEquals(arch_policy.declared_layer(POLICY, "src.ui.panel"), 3)
  lu.assertEquals(arch_policy.declared_layer(POLICY, "src.turn.loop"), 4)
  lu.assertEquals(arch_policy.declared_layer(POLICY, "src.player.actions.balance"), 5)
  lu.assertEquals(arch_policy.declared_layer(POLICY, "src.computer.strategy"), 5)
  lu.assertEquals(arch_policy.declared_layer(POLICY, "src.rules.bootstrap"), 6)
  lu.assertEquals(arch_policy.declared_layer(POLICY, "src.state.game"), 7)
  lu.assertEquals(arch_policy.declared_layer(POLICY, "src.config.game"), 7)
  lu.assertEquals(arch_policy.declared_layer(POLICY, "src.foundation.number"), "substrate")
  lu.assertNil(arch_policy.declared_layer(POLICY, "src.mystery.thing"))
end

function TestArchPolicy:test_legal_graph_passes()
  local result = _check(LEGAL_MODULES, LEGAL_EDGES)
  lu.assertTrue(result.ok, tostring(result.error))
end

function TestArchPolicy:test_downward_skip_is_a_layer_violation()
  local violation = _only({ "src.rules.bootstrap", "src.app.init" }, {
    { from = "src.rules.bootstrap", to = "src.app.init" },
  })
  lu.assertEquals(violation.kind, "layer_violation")
  lu.assertEquals(violation.from_layer, 6)
  lu.assertEquals(violation.to_layer, 1)
end

function TestArchPolicy:test_substrate_must_not_depend_on_a_layered_component()
  local violation = _only({ "src.foundation.number", "src.rules.bootstrap" }, {
    { from = "src.foundation.number", to = "src.rules.bootstrap" },
  })
  lu.assertEquals(violation.kind, "layer_violation")
  lu.assertEquals(violation.from_layer, "substrate")
end

function TestArchPolicy:test_any_layer_may_depend_on_substrate()
  local result = _check({ "src.foundation.number", "src.rules.bootstrap" }, {
    { from = "src.rules.bootstrap", to = "src.foundation.number" },
  })
  lu.assertTrue(result.ok, tostring(result.error))
end

function TestArchPolicy:test_ui_must_not_depend_on_player_computer_or_rules()
  local expected = {
    { to = "src.player.actions.balance", rule = "ui_no_player" },
    { to = "src.computer.strategy", rule = "ui_no_computer" },
    { to = "src.rules.bootstrap", rule = "ui_no_rules" },
  }
  for _, case in ipairs(expected) do
    local violation = _only({ "src.ui.panel", case.to }, {
      { from = "src.ui.panel", to = case.to },
    })
    lu.assertEquals(violation.kind, "forbidden_dependency")
    lu.assertEquals(violation.rule, case.rule)
  end
end

function TestArchPolicy:test_ui_schema_stays_pure()
  local violation = _only({ "src.ui.schema.node", "src.ui.coord.layout" }, {
    { from = "src.ui.schema.node", to = "src.ui.coord.layout" },
  })
  lu.assertEquals(violation.kind, "forbidden_dependency")
  lu.assertEquals(violation.rule, "ui_schema_pure")
end

function TestArchPolicy:test_ui_state_must_not_depend_on_ui_coord()
  local violation = _only({ "src.ui.state.turn", "src.ui.coord.host" }, {
    { from = "src.ui.state.turn", to = "src.ui.coord.host" },
  })
  lu.assertEquals(violation.kind, "forbidden_dependency")
  lu.assertEquals(violation.rule, "ui_state_no_coord")
end

function TestArchPolicy:test_unclassified_module_is_reported()
  local violation = _only({ "src.mystery.thing" }, {})
  lu.assertEquals(violation.kind, "unclassified_module")
  lu.assertEquals(violation.module_id, "src.mystery.thing")
end

function TestArchPolicy:test_cycle_is_reported_and_waivable()
  local modules = { "src.rules.a", "src.rules.b" }
  local edges = {
    { from = "src.rules.a", to = "src.rules.b" },
    { from = "src.rules.b", to = "src.rules.a" },
  }
  local violation = _only(modules, edges)
  lu.assertEquals(violation.kind, "projection_cycle")
  lu.assertEquals(violation.nodes, { "rules.a", "rules.b" })
  lu.assertEquals(violation.cycle, "rules.a->rules.b->rules.a")

  local waived = {
    component_rules = POLICY.component_rules,
    forbidden_dependency_rules = POLICY.forbidden_dependency_rules,
    allowed_cycles = {
      { view = "rules", nodes = { "rules.a", "rules.b" }, reason = "synthetic waiver" },
    },
  }
  lu.assertTrue(arch_policy.check(waived, { modules = modules, edges = edges }).ok)
  -- 白名单按参与者集合匹配,不认遍历顺序。
  local reversed = {
    component_rules = POLICY.component_rules,
    allowed_cycles = { { view = "rules", nodes = { "rules.b", "rules.a" }, reason = "synthetic waiver" } },
  }
  lu.assertTrue(arch_policy.check(reversed, { modules = modules, edges = edges }).ok)
  -- 参与者集合不同就不豁免。
  local narrowed = {
    component_rules = POLICY.component_rules,
    allowed_cycles = { { view = "rules", nodes = { "rules.a" }, reason = "synthetic waiver" } },
  }
  lu.assertFalse(arch_policy.check(narrowed, { modules = modules, edges = edges }).ok)
end

function TestArchPolicy:test_namespace_projection_cycle_without_module_cycle_is_rejected()
  local modules = { "src.rules.a.first", "src.rules.a.second", "src.rules.b.first", "src.rules.b.second" }
  local edges = {
    { from = "src.rules.a.first", to = "src.rules.b.first" },
    { from = "src.rules.b.second", to = "src.rules.a.second" },
  }
  lu.assertFalse(_check(modules, edges).ok)
  local violation = _only(modules, edges)
  lu.assertEquals(violation.view, "rules")
  lu.assertEquals(violation.nodes, { "rules.a", "rules.b" })
end

function TestArchPolicy:test_external_and_self_edges_are_outside_the_graph()
  local result = _check({ "src.rules.bootstrap" }, {
    { from = "src.rules.bootstrap", to = "lfs" },
    { from = "src.rules.bootstrap", to = "src.rules.bootstrap" },
  })
  lu.assertTrue(result.ok, tostring(result.error))
end

-- 扫描面:注释与字符串里的 require 不造边,`.init` 折叠与旧工具同口径。
function TestArchPolicy:test_requires_ignores_comments_and_strings()
  local source = table.concat({
    "-- require(\"src.app.commented\")\n",
    "--[[\nrequire(\"src.app.long_comment\")\n]]\n",
    "local quoted = \"require(\\\"src.app.quoted\\\")\"\n",
    "local chunk = [==[ require(\"src.app.long_string\") ]==]\n",
    "local real = require(\"src.app.real\")\n",
    "local bare = require 'src.app.bare'\n",
  }, "")
  lu.assertEquals(policy_scan.requires(source), { "src.app.bare", "src.app.real" })
end

-- 名字里的下划线是模块名的一部分。截断成 `src.app.event` 会让一条真实依赖
-- 落进「外部模块」桶,门禁就漏判了(`src/app/init.lua` 的 event_bridge 就是这样)。
function TestArchPolicy:test_requires_keeps_underscores_in_module_names()
  local source = "local a = require(\"src.app.event_bridge\")\n"
    .. "local b = require(\"src.turn.output.player_control_snapshot\")\n"
  lu.assertEquals(policy_scan.requires(source), {
    "src.app.event_bridge",
    "src.turn.output.player_control_snapshot",
  })
end

-- `require` 出现在字段/方法位不是指令,与 uml-viewer 的 keyword-at? 同口径。
function TestArchPolicy:test_requires_ignores_field_access()
  local source = "loader.require(\"src.app.field\")\nlocal x = loader:require(\"src.app.method\")\n"
  lu.assertEquals(policy_scan.requires(source), {})
end

function TestArchPolicy:test_module_id_folds_init_and_separators()
  lu.assertEquals(policy_scan.module_id("src/rules/init.lua"), "src.rules")
  lu.assertEquals(policy_scan.module_id("src/ui/panel.lua"), "src.ui.panel")
end

return TestArchPolicy
