-- Memo 派生内核；当前语义由下方合同与本模块测试钉定。
-- 与 Spoke 一致的部分：派生单元是纯函数选择子（selector），输入变化才重算，
-- 派生值可再参与后续派生（transitive variable 叙事风格）。
-- 按票边界裁剪掉的部分：Signal/Effect 节点、trigger 依赖追踪、epoch 调度与级联重跑；
-- 重算触发改为调用方显式 get + 输入快照浅层比对。
-- 合同：
-- - 惰性求值：compute 只在 get 且输入快照变化时运行（Spoke 创建即首跑，本内核按票要求惰性）。
-- - 输入快照未变不重算；输入变化才重算。
-- - 快照为浅层比对：表逐字段比较，嵌套表按引用参与；get 时冻结浅拷贝，
--   防御调用方复用并原地改写的输入表（如 dirty_tracker.consume 的复用快照表）。
-- - compute 应为纯函数：不读写外部状态，产出仅由快照决定。
local memo = {}
local Memo = {}
Memo.__index = Memo

local function _shallow_freeze(snapshot)
  if type(snapshot) ~= "table" then
    return snapshot
  end
  local frozen = {}
  for key, value in pairs(snapshot) do
    frozen[key] = value
  end
  return frozen
end

-- 快照双向比对拆为小函数(CRAP 门禁 #452):a 侧字段在 b 中同值、
-- b 侧无多余字段,两段独立判定,任一不满足即不等。
local function _a_fields_match_in_b(a, b)
  for key, value in pairs(a) do
    if b[key] ~= value then
      return false
    end
  end
  return true
end

local function _b_has_no_extra_fields(a, b)
  for key in pairs(b) do
    if a[key] == nil then
      return false
    end
  end
  return true
end

local function _table_fields_match(a, b)
  return _a_fields_match_in_b(a, b) and _b_has_no_extra_fields(a, b)
end

local function _snapshots_equal(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return a == b
  end
  return _table_fields_match(a, b)
end

-- memo.new(compute, take_snapshot) -> cell
-- compute(snapshot) -> value：纯函数选择子，入参为冻结前的快照。
-- take_snapshot(input) -> 快照：可选投影；缺省时 input 本身即快照。
-- 快照应只含标量字段；含表字段时按引用比对。
function memo.new(compute, take_snapshot)
  assert(type(compute) == "function", "compute must be function")
  assert(take_snapshot == nil or type(take_snapshot) == "function", "take_snapshot must be function or nil")
  return setmetatable({
    _compute = compute,
    _take_snapshot = take_snapshot,
    _ready = false,
    _snapshot = nil,
    _value = nil,
  }, Memo)
end

function Memo:get(input)
  local snapshot = input
  if self._take_snapshot then
    snapshot = self._take_snapshot(input)
  end
  if self._ready and _snapshots_equal(self._snapshot, snapshot) then
    return self._value
  end
  self._snapshot = _shallow_freeze(snapshot)
  self._value = self._compute(snapshot)
  self._ready = true
  return self._value
end

return memo

--[[ mutate4lua-manifest
version=4
projectHash=884b659da2fb4559
scope.0.id=chunk:src/foundation/memo.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=89
scope.0.semanticHash=a58753b4acac5f72
scope.1.id=function:_shallow_freeze
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=25
scope.1.semanticHash=62f3bd2c90d427f9
scope.2.id=function:_a_fields_match_in_b
scope.2.kind=function
scope.2.startLine=29
scope.2.endLine=36
scope.2.semanticHash=edd5e0822200b8c0
scope.3.id=function:_b_has_no_extra_fields
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=45
scope.3.semanticHash=ec4806a938bd2563
scope.4.id=function:_table_fields_match
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=49
scope.4.semanticHash=eba295492822345b
scope.5.id=function:_snapshots_equal
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=56
scope.5.semanticHash=d45af7f8d06d0f74
scope.6.id=function:memo.new
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=72
scope.6.semanticHash=196450b22a16e499
scope.7.id=function:Memo:get
scope.7.kind=function
scope.7.startLine=74
scope.7.endLine=86
scope.7.semanticHash=42562298ca8fb87e
]]
