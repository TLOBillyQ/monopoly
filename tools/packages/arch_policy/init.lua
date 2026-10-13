-- packages/arch_policy —— 层边界的唯一 policy 真源(工单 #92)。
--
-- 为什么存在:层边界此前有两处可独立漂移的配置——旧 `arch_view` 工具的
-- `tools/packages/arch_view/config.json`,和散落在 `test/guards/` 里的规则
-- 断言。本模块把边界收敛成一份数据(`policy.json`),并让三件事消费同一份:
--   1. `test/guards/lib/arch_policy_guard.lua` 执行门禁(层方向/环/未分类/
--      禁向边),不再依赖外部 rock 的分析器;
--   2. `project_arch_view_config` 投影出旧工具仍需要的 config.json,由
--      `test/guards/test_arch_policy_projection.lua` 钉住两者语义一致,
--      旧工具退场(#94)前不可能静默漂移;
--   3. `project_uml_policy` 投影出 uml-viewer 侧 policy(EDN),架构图的层序
--      与门禁同源,不构成第二真源。
--
-- 规则语义与 ADR 0001/0002、ADR 0039 D2 一致:L1 最高、数字越大层越低;
-- foundation 是 substrate(谁都能依赖它,它不依赖任何整型层)。环检测契约保留:
-- 每个视图的反馈边闭合路径逐条判定,白名单按 view 和路径参与者集合豁免。
local json_reader = require("foundation.json_reader")

local M = {}

M.DEFAULT_POLICY_PATH = "tools/packages/arch_policy/policy.json"

local function _matches_any(module_id, patterns)
  for _, pattern in ipairs(patterns or {}) do
    if tostring(module_id or ""):match(pattern) ~= nil then
      return true
    end
  end
  return false
end

-- module_id 命中的 component 规则;未命中即未分类模块。
function M.component_rule(policy, module_id)
  for _, rule in ipairs(policy.component_rules or {}) do
    if _matches_any(module_id, rule.match) then
      return rule
    end
  end
  return nil
end

-- 门禁口径的声明层:整型层号、substrate,或 nil(未分类)。
-- substrate 故意没有整型值,从而永不进入数值不等式。
function M.declared_layer(policy, module_id)
  local rule = M.component_rule(policy, module_id)
  if rule == nil then
    return nil
  end
  if rule.substrate == true then
    return "substrate"
  end
  return rule.layer
end

local function _is_layer_upward(from_layer, to_layer)
  if from_layer == nil or to_layer == nil then
    return false
  end
  if from_layer == "substrate" then
    return to_layer ~= "substrate"
  end
  if to_layer == "substrate" then
    return false
  end
  return from_layer > to_layer
end

-- 强连通分量:每个分量即一条环。返回按分量内最小模块名排序的分量表,
-- 分量内模块名升序,整体确定。
local function _cycles(module_ids, adjacency)
  local index_of = {}
  local low = {}
  local on_stack = {}
  local stack = {}
  local components = {}
  local counter = 0

  local function strongconnect(node)
    counter = counter + 1
    index_of[node] = counter
    low[node] = counter
    stack[#stack + 1] = node
    on_stack[node] = true
    for _, to in ipairs(adjacency[node] or {}) do
      if index_of[to] == nil then
        strongconnect(to)
        low[node] = math.min(low[node], low[to])
      elseif on_stack[to] then
        low[node] = math.min(low[node], index_of[to])
      end
    end
    if low[node] == index_of[node] then
      local component = {}
      repeat
        local member = stack[#stack]
        stack[#stack] = nil
        on_stack[member] = false
        component[#component + 1] = member
      until member == node
      if #component > 1 then
        table.sort(component)
        components[#components + 1] = component
      end
    end
  end

  for _, module_id in ipairs(module_ids) do
    if index_of[module_id] == nil then
      strongconnect(module_id)
    end
  end
  table.sort(components, function(a, b) return a[1] < b[1] end)
  return components
end

local function _same_members(component, waiver_nodes)
  if #component ~= #waiver_nodes then
    return false
  end
  local members = {}
  for _, member in ipairs(component) do
    members[member] = true
  end
  for _, node in ipairs(waiver_nodes) do
    if not members[node] then
      return false
    end
  end
  return true
end

local function _waiver_for(policy, component, view)
  for _, waiver in ipairs(policy.allowed_cycles or {}) do
    if waiver.view == view and _same_members(component, waiver.nodes or {}) then
      return waiver
    end
  end
  return nil
end

-- 图形态:{ modules = {"src.app", ...}, edges = {{from=, to=}, ...} }
-- 只判定两张表都在 modules 里的边;外部 require 不进图。
function M.check(policy, graph)
  local modules = graph.modules or {}
  local known = {}
  for _, module_id in ipairs(modules) do
    known[module_id] = true
  end

  local violations = {}
  local sorted_modules = {}
  for _, module_id in ipairs(modules) do
    sorted_modules[#sorted_modules + 1] = module_id
  end
  table.sort(sorted_modules)

  for _, module_id in ipairs(sorted_modules) do
    if M.component_rule(policy, module_id) == nil then
      violations[#violations + 1] = { kind = "unclassified_module", module_id = module_id }
    end
  end

  local edges = {}
  for _, edge in ipairs(graph.edges or {}) do
    if known[edge.from] and known[edge.to] and edge.from ~= edge.to then
      edges[#edges + 1] = edge
    end
  end
  table.sort(edges, function(a, b)
    if a.from ~= b.from then return a.from < b.from end
    return a.to < b.to
  end)

  for _, edge in ipairs(edges) do
    for _, rule in ipairs(policy.forbidden_dependency_rules or {}) do
      if _matches_any(edge.from, rule.from) and _matches_any(edge.to, rule.to) then
        violations[#violations + 1] = {
          kind = "forbidden_dependency",
          rule = rule.name,
          description = rule.description,
          from = edge.from,
          to = edge.to,
        }
      end
    end
    local from_layer = M.declared_layer(policy, edge.from)
    local to_layer = M.declared_layer(policy, edge.to)
    if _is_layer_upward(from_layer, to_layer) then
      violations[#violations + 1] = {
        kind = "layer_violation",
        from = edge.from,
        to = edge.to,
        from_layer = from_layer,
        to_layer = to_layer,
      }
    end
  end

  -- 每个命名空间视图把后代折叠为直接子节点;模块图无环也可能投影成环。
  local namespaces, views = {}, { root = "" }
  for _, id in ipairs(sorted_modules) do
    local ns = id:gsub("^src%.", "")
    namespaces[id] = ns
    local prefix = ""
    local parts = {}
    for part in ns:gmatch("[^.]+") do parts[#parts + 1] = part end
    for index = 1, #parts - 1 do
      prefix = prefix == "" and parts[index] or prefix .. "." .. parts[index]
      views[prefix] = prefix
    end
  end
  local view_keys = {}
  for view in pairs(views) do view_keys[#view_keys + 1] = view end
  table.sort(view_keys)
  for _, view in ipairs(view_keys) do
    local prefix = views[view]
    local children, node_set, projected = {}, {}, {}
    for id, ns in pairs(namespaces) do
      local rest = prefix == "" and ns or
        (ns:sub(1, #prefix + 1) == prefix .. "." and ns:sub(#prefix + 2) or nil)
      if rest then
        local child = rest:match("^[^.]+")
        if child then
          local full = prefix == "" and child or prefix .. "." .. child
          children[id], node_set[full] = full, true
        end
      end
    end
    for _, edge in ipairs(edges) do
      local from, to = children[edge.from], children[edge.to]
      if from and to and from ~= to then
        projected[from] = projected[from] or {}
        projected[from][to] = true
      end
    end
    local nodes, links = {}, {}
    for node in pairs(node_set) do nodes[#nodes + 1] = node end
    table.sort(nodes)
    for from, targets in pairs(projected) do
      links[from] = {}
      for to in pairs(targets) do links[from][#links[from] + 1] = to end
      table.sort(links[from])
    end
    local paths = require("packages.arch_policy.cycles").paths(nodes, links, _cycles(nodes, links))
    for _, cycle in ipairs(paths) do
      local component = {}
      for index = 1, #cycle - 1 do component[#component + 1] = cycle[index] end
      local waiver = _waiver_for(policy, component, view)
      violations[#violations + 1] = {
        kind = "projection_cycle",
        view = view,
        cycle = table.concat(component, "->") .. "->" .. component[1],
        nodes = component,
        waived = waiver ~= nil,
        reason = waiver and waiver.reason or nil,
      }
    end
  end

  local failing = {}
  for _, violation in ipairs(violations) do
    if violation.waived ~= true then
      failing[#failing + 1] = violation
    end
  end

  return { ok = #failing == 0, violations = failing, all_violations = violations }
end

-- 旧 arch_view 工具的 config.json 是同一份 policy 的投影:四个键逐一对应,
-- 不放宽也不新增。旧工具退场前由投影测试钉住两者语义一致。
function M.project_arch_view_config(policy)
  local config = {
    abstract_rules = policy.abstract_rules or {},
    component_rules = policy.component_rules or {},
    forbidden_dependency_rules = policy.forbidden_dependency_rules or {},
    source_roots = policy.source_roots or {},
  }
  if #(policy.allowed_cycles or {}) > 0 then config.allowed_cycles = policy.allowed_cycles end
  return config
end

local function _edn_string(value)
  local escaped = tostring(value or ""):gsub("\\", "\\\\"):gsub("\"", "\\\"")
  return "\"" .. escaped .. "\""
end

-- uml-viewer 的 :levels 是「越靠前越内层」的 rank 表:substrate 排最前(rank 0),
-- 其余按层号从大到小(从最内层到最外层)。同层按名字升序,输出确定。
function M.uml_level_groups(policy)
  local ranked = {}
  local substrate = {}
  for _, rule in ipairs(policy.component_rules or {}) do
    local entry = { name = rule.component or rule.name, layer = rule.layer }
    if rule.substrate == true then
      substrate[#substrate + 1] = entry
    else
      ranked[#ranked + 1] = entry
    end
  end
  table.sort(substrate, function(a, b) return a.name < b.name end)
  table.sort(ranked, function(a, b)
    if a.layer ~= b.layer then return a.layer > b.layer end
    return a.name < b.name
  end)

  local groups = {}
  for _, entry in ipairs(substrate) do
    groups[#groups + 1] = { entry.name }
  end
  local index = 1
  while index <= #ranked do
    local layer = ranked[index].layer
    local group = {}
    while index <= #ranked and ranked[index].layer == layer do
      group[#group + 1] = ranked[index].name
      index = index + 1
    end
    groups[#groups + 1] = group
  end
  return groups
end

function M.project_uml_policy(policy)
  local groups = {}
  for _, group in ipairs(M.uml_level_groups(policy)) do
    groups[#groups + 1] = "[:" .. table.concat(group, " :") .. "]"
  end
  local foreign = {}
  for _, name in ipairs(policy.foreign or {}) do
    foreign[#foreign + 1] = ":" .. tostring(name)
  end
  return table.concat({
    "{:title " .. _edn_string(policy.title or "UML"),
    " :lang :lua",
    " :src " .. _edn_string((policy.source_roots or {})[1] or "src"),
    " :prefix " .. _edn_string(policy.module_prefix or ""),
    " :hierarchical true",
    " :levels [" .. table.concat(groups, " ") .. "]",
    " :foreign [" .. table.concat(foreign, " ") .. "]}",
    "",
  }, "\n")
end

function M.load(path)
  local fs_lib = require("foundation.fs")
  local raw = fs_lib.read_file(path)
  if raw == nil then
    return nil, "cannot read arch policy: " .. tostring(path)
  end
  local ok, policy = pcall(json_reader.decode, raw)
  if not ok then
    return nil, "cannot decode arch policy " .. tostring(path) .. ": " .. tostring(policy)
  end
  return policy
end

return M
