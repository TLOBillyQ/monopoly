-- Regenerate every gitignored acceptance spec from its feature.
--
-- The generated specs under tools/packages/acceptance/generated/ are gitignored
-- build outputs; this tool deterministically re-derives them from the features
-- listed in tools/packages/acceptance/acceptance_features.lua. It is the
-- regenerate step behind the `lua tools/cli.lua acceptance` entrypoint.

local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")):match("^(.*)/[^/]+$") .. "/../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)

local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local registry = require("packages.acceptance.acceptance_features")

local regenerate = {}

-- Re-derive one feature's generated spec. ir_path is a transient JSON IR under
-- build/ (gitignored); generated_path is the standalone suite script to run.
-- gherkin_parser / entrypoint 依赖 acceptance4lua rock,惰性 require:
-- 只能在 run() 自举判定通过之后装载,否则断网时模块加载就先炸成退 1(#114)。
local function _regenerate_one(feature, generated_path, ir_path)
  local gherkin_parser = require("acceptance4lua.gherkin_parser")
  local entrypoint = require("packages.acceptance.entrypoint")
  local ok, err = fs_lib.ensure_dir(path_lib.parent_dir(ir_path))
  if not ok then
    return nil, err
  end
  ok, err = fs_lib.ensure_dir(path_lib.parent_dir(generated_path))
  if not ok then
    return nil, err
  end
  ok, err = gherkin_parser.write_json_file(feature, ir_path)
  if not ok then
    return nil, err
  end
  ok, err = entrypoint.generate_file(ir_path, generated_path)
  if not ok then
    return nil, err
  end
  return true
end

-- Regenerate the whole suite. Returns true or (nil, error) on the first failure
-- so a broken feature surfaces immediately rather than silently dropping a spec.
-- options.generated_dir / options.entries override the registry defaults so the
-- suite can be regenerated into an isolated directory under test.
--
-- 自举三态(#114):acceptance4lua 装不上时按失败原因分类——网络/下载类失败
-- 多回一个 foundation.tool_availability 不可用记录作为第三返回值(环境不可用,
-- 不是 regenerate 结论);仓内缺陷(锁文件缺项等)照旧 (nil, err) 真实失败。
-- options.ensure_tool 是注入缝(默认 foundation.bootstrap.ensure_tool),
-- 测试喂三态即可,不碰网络。
function regenerate.run(options)
  options = options or {}
  local ensure_tool = options.ensure_tool or bootstrap.ensure_tool
  local ensured, ensure_err, unavailable = ensure_tool("acceptance4lua", env)
  if not ensured then
    return nil, ensure_err, unavailable
  end
  local report = options.report or function(_) end
  local generated_dir = options.generated_dir or registry.generated_dir
  local entries = options.entries or registry.select(report)
  if type(entries) ~= "table" or #entries == 0 then return nil, "no acceptance entries selected" end
  local total = #entries
  for index, entry in ipairs(entries) do
    local generated_path = path_lib.join_path(generated_dir, entry.generated)
    -- gsub 返回 (串, 次数);作为末位实参会整组展开,须加括号截到单值,否则替换次数
    -- 会被 join_path 当成又一段路径拼进去。
    local ir_path = path_lib.join_path("build/acceptance", (entry.generated:gsub("%.lua$", ".json")))
    local ok, err = _regenerate_one(entry.feature, generated_path, ir_path)
    if not ok then
      return nil, string.format("%s: %s", entry.feature, tostring(err))
    end
    report(string.format("[%d/%d] %s -> %s", index, total, entry.feature, entry.generated))
  end
  return true, total
end

-- 跑一次重生成,不写终端:返回 { code, stdout, stderr },由 main 统一写出。
-- 进度行与原 stderr 口径一致(每条一行),不可用诊断(#114)经
-- foundation.tool_availability 渲染:退 3、status=unavailable 点名工具与步骤。
function regenerate.execute(options)
  options = options or {}
  local progress = {}
  local ok, result, unavailable = regenerate.run({
    generated_dir = options.generated_dir,
    entries = options.entries,
    ensure_tool = options.ensure_tool,
    report = function(line)
      progress[#progress + 1] = line .. "\n"
    end,
  })
  local prefix = table.concat(progress)
  if unavailable ~= nil then
    local verdict = require("foundation.tool_availability").verdict(unavailable, "acceptance")
    return { code = verdict.exit_code, stdout = "", stderr = prefix .. verdict.message,
      status = verdict.status }
  end
  if not ok then
    return { code = 1, stdout = "", stderr = prefix .. "regenerate failed: " .. tostring(result) .. "\n" }
  end
  return { code = 0, stdout = string.format("regenerated %d acceptance specs\n", result),
    stderr = prefix }
end

function regenerate.main(options)
  local result = regenerate.execute(options)
  io.stdout:write(result.stdout)
  io.stderr:write(result.stderr)
  return result.code
end

if arg ~= nil and tostring(arg[0] or ""):match("tools/packages/acceptance/regenerate%.lua$") then
  os.exit(regenerate.main())
end

return regenerate
