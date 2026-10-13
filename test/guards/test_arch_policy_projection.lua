---@diagnostic disable: undefined-global
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")

local arch_policy = require("packages.arch_policy")
local json_reader = require("foundation.json_reader")
local json_writer = require("foundation.json_writer")
local fs_lib = require("foundation.fs")

-- #92:层边界只有一份真源 —— `tools/packages/arch_policy/policy.json`。
-- 另两处表达式都是投影,必须与它逐字段一致,否则边界可以静默漂移:
--   1. 旧 arch_view 工具的 config.json(旧工具退场由 #94 执行,退场前仍需正确);
--   2. uml-viewer 侧 policy 的 :levels(架构图的层序与门禁同源)。
local POLICY_PATH = arch_policy.DEFAULT_POLICY_PATH
local ARCH_VIEW_CONFIG_PATH = "tools/packages/arch_view/config.json"

local POLICY = assert(arch_policy.load(POLICY_PATH))

local function _decode(path)
  local raw = fs_lib.read_file(path)
  lu.assertNotNil(raw, "缺失配置文件: " .. path)
  return json_reader.decode(raw)
end

local function _canonical(value)
  return json_writer.encode(value)
end

TestArchPolicyProjection = {}

-- 投影面:旧 config.json 必须等于 policy 的投影,且投影只出这四个键。
function TestArchPolicyProjection:test_arch_view_config_is_the_policy_projection()
  local committed = _decode(ARCH_VIEW_CONFIG_PATH)
  local projected = arch_policy.project_arch_view_config(POLICY)
  lu.assertEquals(_canonical(committed), _canonical(projected),
    "tools/packages/arch_view/config.json 与 policy.json 已漂移;改边界请只改 policy.json 并重投影")
end

function TestArchPolicyProjection:test_projection_carries_every_existing_rule()
  local projected = arch_policy.project_arch_view_config(POLICY)
  lu.assertEquals(#projected.component_rules, 10)
  lu.assertEquals(#projected.forbidden_dependency_rules, 5)
  lu.assertEquals(#projected.abstract_rules, 2)
  lu.assertEquals(projected.source_roots, { "src" })
  local names = {}
  for _, rule in ipairs(projected.forbidden_dependency_rules) do
    names[rule.name] = true
  end
  for _, name in ipairs({
    "ui_no_player",
    "ui_no_computer",
    "ui_no_rules",
    "ui_schema_pure",
    "ui_state_no_coord",
  }) do
    lu.assertTrue(names[name], "policy 丢失禁向规则: " .. name)
  end
end

-- uml 侧 policy 的 :levels 是「越靠前越内层」的 rank 表:substrate 最内层,
-- 其余按层号从大到小。逐个组件核对 rank 的逆序关系,而不是只看字符串形状。
function TestArchPolicyProjection:test_uml_levels_invert_the_declared_layers()
  local groups = arch_policy.uml_level_groups(POLICY)
  local rank_of = {}
  for rank, group in ipairs(groups) do
    for _, name in ipairs(group) do
      lu.assertNil(rank_of[name], "组件在 :levels 里重复: " .. name)
      rank_of[name] = rank - 1
    end
  end

  local seen = 0
  for _, rule in ipairs(POLICY.component_rules) do
    local name = rule.component
    local rank = rank_of[name]
    lu.assertNotNil(rank, "组件未出现在 uml :levels: " .. name)
    seen = seen + 1
    if rule.substrate == true then
      lu.assertEquals(rank, 0, "substrate 必须是最内层 rank 0")
    else
      lu.assertEquals(rank, 8 - rule.layer,
        "组件 " .. name .. " 的 uml rank 必须与其声明层号互逆")
    end
  end
  lu.assertEquals(seen, #POLICY.component_rules)
end

function TestArchPolicyProjection:test_uml_policy_text_uses_the_policy_source()
  local text = arch_policy.project_uml_policy(POLICY)
  lu.assertNotNil(text:find(":prefix \"src\"", 1, true))
  lu.assertNotNil(text:find(":src \"src\"", 1, true))
  lu.assertNotNil(text:find(":levels [[:foundation] [:config :state] [:rules]"
    .. " [:computer :player] [:turn] [:ui] [:host] [:app]]", 1, true))
end

return TestArchPolicyProjection
