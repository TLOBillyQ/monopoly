--- Backend-neutral file discovery and deterministic LPT allocation.
local proc = require("foundation.proc")
local number = require("src.foundation.number")
local M = {}
function M.discover_spec_files(root)
  if root == nil or root == "" then return {} end
  local files = {}
  for _, path in ipairs(proc.collect_files(root, ".lua") or {}) do
    local base = path:match("([^/\\]+)%.lua$")
    if base and base:find("test_") then files[#files + 1] = path end
  end
  table.sort(files)
  return files
end
function M.file_cost(path)
  local file = io.open(path, "r")
  if not file then return 1 end
  local count = 0
  for line in file:lines() do
    if line:find("it(", 1, true) or line:match("[%.:]test_[%w_]*%s*%(")
      or line:match("%[%s*[\"']test_") then count = count + 1 end
  end
  file:close()
  return math.max(1, count)
end
function M.build_lpt_lanes(files, worker_count)
  local lanes, ranked = {}, {}
  for i = 1, math.max(1, math.min(worker_count or 1, math.max(1, #files))) do
    lanes[i] = { index = i, total_cost = 0, files = {} }
  end
  for index, path in ipairs(files) do
    ranked[#ranked + 1] = { path = path, cost = M.file_cost(path), index = index }
  end
  table.sort(ranked, function(a, b)
    if a.cost ~= b.cost then return a.cost > b.cost end
    return a.index < b.index
  end)
  for _, entry in ipairs(ranked) do
    local target = lanes[1]
    for i = 2, #lanes do
      if lanes[i].total_cost < target.total_cost then target = lanes[i] end
    end
    target.total_cost = target.total_cost + entry.cost
    target.files[#target.files + 1] = entry.path
  end
  return lanes
end
function M.resolve_workers(env_var_name, file_count, default_workers)
  local capacity = math.max(1, file_count or 0)
  local resolved = default_workers or 1
  local raw = env_var_name and os.getenv(env_var_name)
  local parsed = raw and number.to_integer(raw)
  if parsed and parsed >= 1 then resolved = parsed end
  return math.max(1, math.min(resolved, capacity))
end
return M
