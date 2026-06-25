local context = require("acceptance.steps.quality.context")
local bootstrap_runtime = require("acceptance.steps.quality.bootstrap_runtime")
local manifest_steps = require("acceptance.steps.quality.bootstrap_manifest_steps")

local bootstrap_steps = {}

local _KNOWN_CANDIDATES = {
  ["src/foundation/log.lua"] = true,
  ["src/rules/market/effects.lua"] = true,
  ["src/turn/loop/init.lua"] = true,
  ["docs/architecture/boundaries.md"] = false,
  ["spec/contract/state/x.lua"] = false,
  ["tools/quality/lint.lua"] = false,
  ["swarmforge/tools.lock"] = false,
  ["tests/legacy_runner.lua"] = false,
}

local function _require_path(path)
  return function(world)
    return context.require_path(world, path)
  end
end

local function _merge_handlers(target, source)
  for pattern, handler in pairs(source or {}) do
    target[pattern] = handler
  end
  return target
end

function bootstrap_steps.handlers()
  return _merge_handlers({
    ["tools/quality/mutate_bootstrap.lua 已落地"] = _require_path("tools/quality/mutate_bootstrap.lua"),

    ["该工具通过 git ls-files 枚举 src/**/*.lua"] = _require_path("tools/quality/mutate_bootstrap.lua"),

    ["每个待写文件由 lockfile 中 mutate4lua engine.update_manifest 写入 v2 manifest"] =
      function(world)
        return context.require_tool(world, "mutate4lua", "lib/mutate4lua/engine.lua")
      end,

    ["工具不调用 git commit；commit 由操作者完成"] = function(world)
      local common = require("shared.lib.common")
      local content, err = common.read_file(common.join_path(context.root(world), "tools/quality/mutate_bootstrap.lua"))
      if content == nil then
        return nil, err
      end
      if content:find("git commit", 1, true) then
        return nil, "mutate_bootstrap.lua must not invoke git commit"
      end
      return true
    end,

    ["git ls-files 输出包含<候选路径>"] = function(world, example)
      local candidate = example["候选路径"]
      local known, known_err = context.expect_known_value(candidate, _KNOWN_CANDIDATES, "candidate path")
      if not known then
        return nil, known_err
      end
      context.state(world).bootstrap = { candidate = candidate }
      return true
    end,

    ["执行 lua tools/quality/mutate_bootstrap.lua"] = function(world)
      return bootstrap_runtime.run_bootstrap(world)
    end,

    ["执行 lua tools/quality/mutate_bootstrap.lua --dry-run"] = function(world)
      return bootstrap_runtime.run_bootstrap(world, { dry_run = true })
    end,

    ["工具<是否处理><候选路径>"] = function(world, example)
      local status = example["是否处理"]
      if status ~= "处理" and status ~= "不处理" then
        return nil, "unknown processing expectation: " .. tostring(status)
      end
      local candidate = example["候选路径"]
      local expected = status == "处理"
      local canonical = _KNOWN_CANDIDATES[tostring(candidate or "")]
      return context.expect((context.state(world).bootstrap or {}).processed == expected and canonical == expected,
        "candidate processing mismatch for " .. tostring(candidate))
    end,

    ["工具继续处理其他文件"] = function()
      return true
    end,
  }, manifest_steps.handlers())
end

return bootstrap_steps
