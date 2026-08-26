local proc_lib = require("foundation.proc")
local number_utils = require("src.foundation.number")

local M = {}

-- spec 分片工具（原名 busted_sharding，随
-- luaunit_runner 包迁改名）。file_cost 的用例计数识别两种形态——遗留 DSL 的
-- it( 子串(历史遗留,保留),与 LuaUnit 原生方法定义(冒号形/点形/括号形)。
-- 注意 it( 是普通字符串子串,wait(/split( 等也会命中,这是历史既有行为,保留。
local function _line_has_native_test_def(line)
  if line:match("[%.:]test_[%w_]*%s*%(") then
    return true
  end
  if line:match("%[%s*[\"']test_") then
    return true
  end
  return false
end

function M.discover_spec_files(root)
  if root == nil or root == "" then
    return {}
  end
  local discovered = proc_lib.collect_files(root, ".lua")
  if discovered == nil then
    return {}
  end
  local files = {}
  for _, path in ipairs(discovered) do
    -- 发现口径与 runner / spec_lane 逐字节等价(collect_files + basename 去
    -- 扩展名后子串匹配 test_):纯命名约定,不做内容嗅探——嗅探探不出
    -- suite_flatten 拍平套件这类动态生成用例的文件,曾让并行车道静默漏跑
    -- (#560)。支撑文件不冠 test_ 前缀,天然不被收集(#561 已全仓清扫)。
    local base = path:match("([^/\\]+)%.lua$")
    if base ~= nil and base:find("test_") ~= nil then
      files[#files + 1] = path
    end
  end
  table.sort(files)
  return files
end

function M.file_cost(path)
  local f = io.open(path, "r")
  if f == nil then
    return 1
  end
  local count = 0
  for line in f:lines() do
    if line:find("it(", 1, true) then
      count = count + 1
    elseif _line_has_native_test_def(line) then
      count = count + 1
    end
  end
  f:close()
  return math.max(1, count)
end

local function _ranked_entries(files)
  local ranked = {}
  for index, path in ipairs(files) do
    ranked[#ranked + 1] = {
      path = path,
      cost = M.file_cost(path),
      index = index,
    }
  end
  table.sort(ranked, function(left, right)
    if left.cost ~= right.cost then
      return left.cost > right.cost
    end
    return left.index < right.index
  end)
  return ranked
end

function M.build_lpt_lanes(files, worker_count)
  local clamped = math.max(1, math.min(worker_count or 1, math.max(1, #files)))
  local lanes = {}
  for i = 1, clamped do
    lanes[i] = { index = i, total_cost = 0, files = {} }
  end
  for _, entry in ipairs(_ranked_entries(files)) do
    local target = lanes[1]
    for i = 2, #lanes do
      if lanes[i].total_cost < target.total_cost then
        target = lanes[i]
      elseif lanes[i].total_cost == target.total_cost and lanes[i].index < target.index then
        target = lanes[i]
      end
    end
    target.total_cost = target.total_cost + entry.cost
    target.files[#target.files + 1] = entry.path
  end
  return lanes
end

function M.resolve_workers(env_var_name, file_count, default_workers)
  local capacity = math.max(1, file_count or 0)
  local resolved = default_workers or 1
  if env_var_name ~= nil then
    local env_val = os.getenv(env_var_name)
    if env_val ~= nil and env_val ~= "" then
      local parsed = number_utils.to_integer(env_val)
      if parsed ~= nil and parsed >= 1 then
        resolved = parsed
      end
    end
  end
  if resolved < 1 then
    resolved = 1
  end
  if resolved > capacity then
    resolved = capacity
  end
  return resolved
end

return M
