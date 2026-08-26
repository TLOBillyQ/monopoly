-- 内圈可达目标的 seat+roll 规划查询口（#163）：给定经内圈入口才可达的目标格，
-- 算出「外环落座格 + 骰值」使真实移动路径恰好落在 / 途经该目标。
-- 入口门控合法性一律问 direction.parity_allows_inner——本模块不自带 parity 知识，
-- 消费方（验收 driver 等）也不必复述。
local direction = require("src.rules.board.direction")

local route_plan = {}

local MAX_INNER_HOPS = 64
-- 搜索窗按谓词黑盒设计:窗口恰为 8 个连续 roll,凡「roll mod k」型门控且
-- k ≤ 8 都必在窗内命中,无冗余裕量。
local MAX_ROLL_SEARCH = 8

-- 沿内圈前进链从 start 走到 target，返回步数（start 本身为第 1 步）；断链或超出
-- 步数窗仍未及 target 时返回 nil。
local function _chain_hops_to(fresh_forward_next, start_id, target_id)
  local hops, cur = 1, start_id
  while cur ~= target_id and hops < MAX_INNER_HOPS do
    local next_id = fresh_forward_next[cur]
    -- 断链即止；break 不能独占一行:Lua 5.4 line hook 不汇报 break 行,覆盖率会永远缺口。
    if next_id == nil then break end
    hops = hops + 1
    cur = next_id
  end
  if cur == target_id then
    return hops
  end
  return nil
end

-- 找到内圈路径可达 target 的入口：返回入口外环格 id 与「入口格下一步起到 target」
-- 的内圈步数（入口拐入为第 1 步）。
local function _inner_route_to(map, target_id)
  local fresh_forward_next = map.fresh_forward_next or {}
  for entry_id, entry in pairs(map.entry_points or {}) do
    local hops = _chain_hops_to(fresh_forward_next, entry.inner_id, target_id)
    if hops ~= nil then
      return entry_id, hops
    end
  end
  return nil
end

local function _seat_back_from(map, entry_id, back)
  local id = entry_id
  for _ = 1, back do
    id = map.outer_prev[id]
    if id == nil then
      return nil
    end
  end
  return id
end

local function _build_plan(map, entry_id, back, roll)
  local seat_id = _seat_back_from(map, entry_id, back)
  if seat_id == nil then
    return nil, "outer ring too short before entry " .. tostring(entry_id)
  end
  return { seat_id = seat_id, entry_id = entry_id, back = back, roll = roll }
end

-- 落点方案：seat 于入口前 back 格，掷 roll 恰好停在 target（最后一步落格）。
function route_plan.plan_land_on(map, target_id)
  local entry_id, hops = _inner_route_to(map, target_id)
  if entry_id == nil then
    return nil, "no entry_point routes to " .. tostring(target_id)
  end
  for back = 1, MAX_ROLL_SEARCH do
    local roll = back + hops
    if direction.parity_allows_inner(roll) then
      return _build_plan(map, entry_id, back, roll)
    end
  end
  return nil, "no legal roll lands on " .. tostring(target_id)
end

-- 途经方案：seat 于入口前 1 格，掷 roll 中途经过 target 且至少剩 1 步。
function route_plan.plan_pass_through(map, target_id)
  local entry_id, hops = _inner_route_to(map, target_id)
  if entry_id == nil then
    return nil, "no entry_point routes to " .. tostring(target_id)
  end
  local target_step = 1 + hops
  for roll = target_step + 1, target_step + MAX_ROLL_SEARCH do
    if direction.parity_allows_inner(roll) then
      local plan, err = _build_plan(map, entry_id, 1, roll)
      if plan ~= nil then
        plan.target_step = target_step
      end
      return plan, err
    end
  end
  return nil, "no legal roll passes through " .. tostring(target_id)
end

return route_plan

--[[ mutate4lua-manifest
version=4
projectHash=464f83af86d954cb
scope.0.id=chunk:src/rules/board/route_plan.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=98
scope.0.semanticHash=ec50e88e6034c8cb
scope.1.id=function:_chain_hops_to
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=29
scope.1.semanticHash=a00dee34753ce968
scope.2.id=function:_inner_route_to
scope.2.kind=function
scope.2.startLine=33
scope.2.endLine=42
scope.2.semanticHash=aa99a4542ecbc046
scope.3.id=function:_seat_back_from
scope.3.kind=function
scope.3.startLine=44
scope.3.endLine=53
scope.3.semanticHash=43420ee6583487f0
scope.4.id=function:_build_plan
scope.4.kind=function
scope.4.startLine=55
scope.4.endLine=61
scope.4.semanticHash=e75f8618d53823cc
scope.5.id=function:route_plan.plan_land_on
scope.5.kind=function
scope.5.startLine=64
scope.5.endLine=76
scope.5.semanticHash=5b1c1fd8cd569c94
scope.6.id=function:route_plan.plan_pass_through
scope.6.kind=function
scope.6.startLine=79
scope.6.endLine=95
scope.6.semanticHash=13140d2a9b527e5e
]]
