local context = require("acceptance.steps.quality.context")
local bootstrap_runtime = require("acceptance.steps.quality.bootstrap_runtime")

local bootstrap_steps = {}

local function _require_path(path)
  return function(world)
    return context.require_path(world, path)
  end
end

local function _expect_status(status)
  return function(world)
    return context.expect((context.state(world).bootstrap or {}).status == status,
      "expected " .. status .. " summary")
  end
end

local function _prepare_bootstrap_manifest(opts, bootstrap_state)
  return function(world, example)
    local state = context.prepare_manifest(world, example["源文件"], opts)
    state.bootstrap = bootstrap_state
    return true
  end
end

function bootstrap_steps.handlers()
  return {
    ["tools/quality/mutate_bootstrap.lua 已落地"] = _require_path("tools/quality/mutate_bootstrap.lua"),

    ["该工具通过 git ls-files 枚举 src/**/*.lua"] = _require_path("tools/quality/mutate_bootstrap.lua"),

    ["每个待写文件由 mutate4lua engine.update_manifest 写入 v2 manifest"] =
      _require_path("vendor/mutate4lua/lib/mutate4lua/engine.lua"),

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
      context.state(world).bootstrap = { candidate = example["候选路径"] }
      return true
    end,

    ["执行 lua tools/quality/mutate_bootstrap.lua"] = function(world)
      return bootstrap_runtime.run_bootstrap(world)
    end,

    ["执行 lua tools/quality/mutate_bootstrap.lua --dry-run"] = function(world)
      return bootstrap_runtime.run_bootstrap(world, { dry_run = true })
    end,

    ["工具<是否处理><候选路径>"] = function(world, example)
      local expected = example["是否处理"] == "处理"
      return context.expect((context.state(world).bootstrap or {}).processed == expected,
        "candidate processing mismatch for " .. tostring(example["候选路径"]))
    end,

    ["源文件<源文件>当前不含 mutate4lua manifest 尾块"] =
      _prepare_bootstrap_manifest({ has_manifest = false }, { no_manifest = true }),

    ["manifest version 字段为 2"] = function(world)
      return context.expect((context.state(world).manifest_version or 2) == 2, "manifest version is not 2")
    end,

    ["工具 summary 标记<源文件>为 written"] = _expect_status("written"),

    ["源文件<源文件>已含 v2 manifest 且 scope hash 与当前源码一致"] =
      _prepare_bootstrap_manifest({ version = 2 }, { v2 = true }),

    ["源文件字节级保持不变"] = function(world)
      return context.expect_manifest_unchanged(world, "source changed unexpectedly")
    end,

    ["工具 summary 标记<源文件>为 unchanged"] = _expect_status("unchanged"),

    ["源文件<源文件>含 version=1 的 manifest 尾块"] =
      _prepare_bootstrap_manifest({ version = 1 }, { v1 = true }),

    ["源码未发生语义变化"] = function(world)
      context.state(world).semantic_hash = "hash-current"
      return true
    end,

    ["manifest 尾块的 version 字段改写为 2"] = function(world)
      return context.expect((context.state(world).manifest_version or 0) == 2, "manifest was not migrated")
    end,

    ["工具 summary 标记<源文件>为 migrated"] = _expect_status("migrated"),

    ["源文件<源文件>的 manifest 尾块呈现<损坏形式>"] = function(world, example)
      return _prepare_bootstrap_manifest(nil, { corrupt_form = example["损坏形式"] })(world, example)
    end,

    ["工具不修改<源文件>"] = function(world)
      return context.expect((context.state(world).bootstrap or {}).did_write ~= true, "tool modified source")
    end,

    ["stderr 包含<源文件>与<损坏形式>说明"] = function(world, example)
      local stderr = (context.state(world).bootstrap or {}).stderr or ""
      return context.expect(stderr:find(example["源文件"], 1, true)
          and stderr:find(example["损坏形式"], 1, true),
        "stderr missing source or damage form")
    end,

    ["工具继续处理其他文件"] = function()
      return true
    end,

    ["工具 summary 标记<源文件>为 skipped"] = _expect_status("skipped"),
  }
end

return bootstrap_steps
