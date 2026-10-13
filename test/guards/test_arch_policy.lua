---@diagnostic disable: undefined-global
require("test.bootstrap").install_package_paths()

-- luacheck: ignore 143 (genuine busted injects luassert)
local luassert = assert

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
  luassert.is.equal(1, #violations, guard.describe(violations[1] or {}))
  return violations[1]
end

describe("TestArchPolicy", function()
  local pending_root

  after_each(function()
    if pending_root then
      local root = pending_root
      pending_root = nil
      assert(require("foundation.fs").remove_path(root))
    end
  end)


it("test_declared_layers_match_the_registry", function()
  luassert.is.equal(1, arch_policy.declared_layer(POLICY, "src.app.init"))
  luassert.is.equal(2, arch_policy.declared_layer(POLICY, "src.host.units"))
  luassert.is.equal(3, arch_policy.declared_layer(POLICY, "src.ui.panel"))
  luassert.is.equal(4, arch_policy.declared_layer(POLICY, "src.turn.loop"))
  luassert.is.equal(5, arch_policy.declared_layer(POLICY, "src.player.actions.balance"))
  luassert.is.equal(5, arch_policy.declared_layer(POLICY, "src.computer.strategy"))
  luassert.is.equal(6, arch_policy.declared_layer(POLICY, "src.rules.bootstrap"))
  luassert.is.equal(7, arch_policy.declared_layer(POLICY, "src.state.game"))
  luassert.is.equal(7, arch_policy.declared_layer(POLICY, "src.config.game"))
  luassert.is.equal("substrate", arch_policy.declared_layer(POLICY, "src.foundation.number"))
  luassert.is_nil(arch_policy.declared_layer(POLICY, "src.mystery.thing"))
end)

it("test_legal_graph_passes", function()
  local result = _check(LEGAL_MODULES, LEGAL_EDGES)
  luassert.is_true(result.ok, tostring(result.error))
end)

it("test_downward_skip_is_a_layer_violation", function()
  local violation = _only({ "src.rules.bootstrap", "src.app.init" }, {
    { from = "src.rules.bootstrap", to = "src.app.init" },
  })
  luassert.is.equal("layer_violation", violation.kind)
  luassert.is.equal(6, violation.from_layer)
  luassert.is.equal(1, violation.to_layer)
end)

it("test_substrate_must_not_depend_on_a_layered_component", function()
  local violation = _only({ "src.foundation.number", "src.rules.bootstrap" }, {
    { from = "src.foundation.number", to = "src.rules.bootstrap" },
  })
  luassert.is.equal("layer_violation", violation.kind)
  luassert.is.equal("substrate", violation.from_layer)
end)

it("test_any_layer_may_depend_on_substrate", function()
  local result = _check({ "src.foundation.number", "src.rules.bootstrap" }, {
    { from = "src.rules.bootstrap", to = "src.foundation.number" },
  })
  luassert.is_true(result.ok, tostring(result.error))
end)

it("test_ui_must_not_depend_on_player_computer_or_rules", function()
  local expected = {
    { to = "src.player.actions.balance", rule = "ui_no_player" },
    { to = "src.computer.strategy", rule = "ui_no_computer" },
    { to = "src.rules.bootstrap", rule = "ui_no_rules" },
  }
  for _, case in ipairs(expected) do
    local violation = _only({ "src.ui.panel", case.to }, {
      { from = "src.ui.panel", to = case.to },
    })
    luassert.is.equal("forbidden_dependency", violation.kind)
    luassert.is.equal(case.rule, violation.rule)
  end
end)

it("test_ui_schema_stays_pure", function()
  local violation = _only({ "src.ui.schema.node", "src.ui.coord.layout" }, {
    { from = "src.ui.schema.node", to = "src.ui.coord.layout" },
  })
  luassert.is.equal("forbidden_dependency", violation.kind)
  luassert.is.equal("ui_schema_pure", violation.rule)
end)

it("test_ui_state_must_not_depend_on_ui_coord", function()
  local violation = _only({ "src.ui.state.turn", "src.ui.coord.host" }, {
    { from = "src.ui.state.turn", to = "src.ui.coord.host" },
  })
  luassert.is.equal("forbidden_dependency", violation.kind)
  luassert.is.equal("ui_state_no_coord", violation.rule)
end)

it("test_unclassified_module_is_reported", function()
  local violation = _only({ "src.mystery.thing" }, {})
  luassert.is.equal("unclassified_module", violation.kind)
  luassert.is.equal("src.mystery.thing", violation.module_id)
end)

it("test_cycle_is_reported_and_waivable", function()
  local modules = { "src.rules.a", "src.rules.b" }
  local edges = {
    { from = "src.rules.a", to = "src.rules.b" },
    { from = "src.rules.b", to = "src.rules.a" },
  }
  local violation = _only(modules, edges)
  luassert.is.equal("projection_cycle", violation.kind)
  luassert.is.same({ "rules.a", "rules.b" }, violation.nodes)
  luassert.is.equal("rules.a->rules.b->rules.a", violation.cycle)

  local waived = {
    component_rules = POLICY.component_rules,
    forbidden_dependency_rules = POLICY.forbidden_dependency_rules,
    allowed_cycles = {
      { view = "rules", nodes = { "rules.a", "rules.b" }, reason = "synthetic waiver" },
    },
  }
  luassert.is_true(arch_policy.check(waived, { modules = modules, edges = edges }).ok)
  -- 白名单按参与者集合匹配,不认遍历顺序。
  local reversed = {
    component_rules = POLICY.component_rules,
    allowed_cycles = { { view = "rules", nodes = { "rules.b", "rules.a" }, reason = "synthetic waiver" } },
  }
  luassert.is_true(arch_policy.check(reversed, { modules = modules, edges = edges }).ok)
  -- 参与者集合不同就不豁免。
  local narrowed = {
    component_rules = POLICY.component_rules,
    allowed_cycles = { { view = "rules", nodes = { "rules.a" }, reason = "synthetic waiver" } },
  }
  luassert.is_false(arch_policy.check(narrowed, { modules = modules, edges = edges }).ok)
end)

it("test_namespace_projection_cycle_without_module_cycle_is_rejected", function()
  local modules = { "src.rules.a.first", "src.rules.a.second", "src.rules.b.first", "src.rules.b.second" }
  local edges = {
    { from = "src.rules.a.first", to = "src.rules.b.first" },
    { from = "src.rules.b.second", to = "src.rules.a.second" },
  }
  luassert.is_false(_check(modules, edges).ok)
  local violation = _only(modules, edges)
  luassert.is.equal("rules", violation.view)
  luassert.is.same({ "rules.a", "rules.b" }, violation.nodes)
end)

it("test_complex_scc_path_waivers_match_legacy_public_analyzer", function()
  local fs = require("foundation.fs")
  local json = require("foundation.json_writer")
  local legacy = require("arch_view")
  local root = require("foundation.env").make_temp_path("monopoly_76_arch_policy_cycle")
  pending_root = root
  local graph = {
    modules = { "src.rules.a", "src.rules.b", "src.rules.c" },
    edges = {
      { from = "src.rules.a", to = "src.rules.b" },
      { from = "src.rules.b", to = "src.rules.a" },
      { from = "src.rules.b", to = "src.rules.c" },
      { from = "src.rules.c", to = "src.rules.b" },
    },
  }
  assert(fs.write_file(root .. "/src/rules/a.lua", 'require("src.rules.b")'))
  assert(fs.write_file(root .. "/src/rules/b.lua", 'require("src.rules.a")\nrequire("src.rules.c")'))
  assert(fs.write_file(root .. "/src/rules/c.lua", 'require("src.rules.b")'))
  for _, waivers in ipairs({
    {},
    { { view = "rules", nodes = { "rules.b", "rules.a" }, reason = "first path" } },
    { { view = "rules", nodes = { "rules.a", "rules.b" }, reason = "first path" },
      { view = "rules", nodes = { "rules.b", "rules.c" }, reason = "second path" } },
    { { view = "wrong", nodes = { "rules.a", "rules.b" }, reason = "wrong view" } },
    { { view = "rules", nodes = { "rules.a", "rules.b", "rules.c" }, reason = "SCC is not a path" } },
  }) do
    local policy = {
      source_roots = POLICY.source_roots,
      abstract_rules = POLICY.abstract_rules,
      component_rules = POLICY.component_rules,
      forbidden_dependency_rules = POLICY.forbidden_dependency_rules,
      allowed_cycles = waivers,
    }
    assert(fs.write_file(root .. "/config.json", json.encode(arch_policy.project_arch_view_config(policy))))
    local old = legacy.analyze({ project_root = root, config_path = root .. "/config.json" }).check
    local current = arch_policy.check(policy, graph)
    luassert.is.equal(old.ok, current.ok)
    luassert.is.equal(#old.violations, #current.violations)
    luassert.is.equal(#old.projection_cycles, #current.all_violations)
    for index, cycle in ipairs(old.projection_cycles) do
      local actual = current.all_violations[index]
      luassert.is.equal(cycle.view, actual.view)
      luassert.is.equal(cycle.cycle, actual.cycle)
      luassert.is.same(cycle.nodes, actual.nodes)
      luassert.is.equal(cycle.waived, actual.waived)
      luassert.is.equal(cycle.reason, actual.reason)
    end
  end
  assert(fs.remove_path(root))
  pending_root = nil
end)

it("test_large_scc_greedy_paths_match_legacy_public_analyzer", function()
  local fs = require("foundation.fs")
  local json = require("foundation.json_writer")
  local root = require("foundation.env").make_temp_path("monopoly_76_arch_policy_greedy")
  pending_root = root
  local graph = { modules = {}, edges = {} }
  for index = 1, 9 do
    local id = "src.rules.n" .. index
    graph.modules[#graph.modules + 1] = id
    local source = {}
    for _, offset in ipairs({ 1, 3 }) do
      local target = "src.rules.n" .. ((index - 1 + offset) % 9 + 1)
      graph.edges[#graph.edges + 1] = { from = id, to = target }
      source[#source + 1] = 'require("' .. target .. '")'
    end
    assert(fs.write_file(root .. "/src/rules/n" .. index .. ".lua", table.concat(source, "\n")))
  end
  assert(fs.write_file(root .. "/config.json", json.encode(arch_policy.project_arch_view_config(POLICY))))
  local old = require("arch_view").analyze({ project_root = root, config_path = root .. "/config.json" }).check
  local current = arch_policy.check(POLICY, graph)
  luassert.is_false(current.ok)
  luassert.is.equal(#old.projection_cycles, #current.all_violations)
  for index, cycle in ipairs(old.projection_cycles) do
    luassert.is.equal(cycle.cycle, current.all_violations[index].cycle)
    luassert.is.same(cycle.nodes, current.all_violations[index].nodes)
    luassert.is.equal(cycle.view, current.all_violations[index].view)
  end
  assert(fs.remove_path(root))
  pending_root = nil
end)

it("test_external_and_self_edges_are_outside_the_graph", function()
  local result = _check({ "src.rules.bootstrap" }, {
    { from = "src.rules.bootstrap", to = "lfs" },
    { from = "src.rules.bootstrap", to = "src.rules.bootstrap" },
  })
  luassert.is_true(result.ok, tostring(result.error))
end)

-- 扫描面:注释与字符串里的 require 不造边,`.init` 折叠与旧工具同口径。
it("test_requires_ignores_comments_and_strings", function()
  local source = table.concat({
    "-- require(\"src.app.commented\")\n",
    "--[[\nrequire(\"src.app.long_comment\")\n]]\n",
    "local quoted = \"require(\\\"src.app.quoted\\\")\"\n",
    "local chunk = [==[ require(\"src.app.long_string\") ]==]\n",
    "local real = require(\"src.app.real\")\n",
    "local bare = require 'src.app.bare'\n",
  }, "")
  luassert.is.same({ "src.app.bare", "src.app.real" }, policy_scan.requires(source))
end)

-- 名字里的下划线是模块名的一部分。截断成 `src.app.event` 会让一条真实依赖
-- 落进「外部模块」桶,门禁就漏判了(`src/app/init.lua` 的 event_bridge 就是这样)。
it("test_requires_keeps_underscores_in_module_names", function()
  local source = "local a = require(\"src.app.event_bridge\")\n"
    .. "local b = require(\"src.turn.output.player_control_snapshot\")\n"
  luassert.is.same({
    "src.app.event_bridge",
    "src.turn.output.player_control_snapshot",
  }, policy_scan.requires(source))
end)

-- `require` 出现在字段/方法位不是指令,与 uml-viewer 的 keyword-at? 同口径。
it("test_requires_ignores_field_access", function()
  local source = "loader.require(\"src.app.field\")\nlocal x = loader:require(\"src.app.method\")\n"
  luassert.is.same({}, policy_scan.requires(source))
end)

it("test_module_id_folds_init_and_separators", function()
  luassert.is.equal("src.rules", policy_scan.module_id("src/rules/init.lua"))
  luassert.is.equal("src.ui.panel", policy_scan.module_id("src/ui/panel.lua"))
end)
end)
