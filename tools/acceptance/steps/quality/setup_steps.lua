local context = require("acceptance.steps.quality.context")
local mutation_runtime = require("acceptance.steps.quality.mutation_runtime")

local setup_steps = {}

local function _prepare_manifest(opts)
  return function(world, example)
    context.prepare_manifest(world, example["源文件"], opts)
    return true
  end
end

local function _run_mutate(opts)
  return function(world, example)
    context.set_source(world, example["源文件"])
    return mutation_runtime.run_mutate(world, opts)
  end
end

function setup_steps.handlers()
  return {
    ["mutate4lua 已按 swarmforge/tools.lock bootstrap 到位"] = function(world)
      return context.require_tool(world, "mutate4lua", "lib/mutate4lua/cli.lua")
    end,

    ["项目通过 tools/quality/mutate.lua 暴露 CLI"] = function(world)
      return context.require_path(world, "tools/quality/mutate.lua")
    end,

    ["manifest 以 --[[ mutate4lua-manifest ]] 块写在源文件尾"] = function(world)
      local ok, err = context.require_path(world, "tools/quality/mutate_bootstrap.lua")
      if not ok then
        return nil, err
      end
      world.mutate_manifest_marker = "--[[ mutate4lua-manifest"
      return true
    end,

    ["源文件<源文件>没有 manifest 尾块"] = _prepare_manifest({ has_manifest = false }),

    ["源文件<源文件>已有 manifest 尾块且最近一次为全 scope pass"] = _prepare_manifest({ last_status = true }),

    ["源文件<源文件>已有 manifest 尾块"] = _prepare_manifest({ last_status = true }),

    ["执行 mutate <源文件> --update-manifest 且全 scope pass"] = _run_mutate({ full_pass = true }),

    ["执行 mutate <源文件>"] = _run_mutate(),

    ["执行 mutate <源文件> --mutate-all"] = _run_mutate({ mutate_all = true }),

    ["执行 mutate <源文件> --lines <行号集>"] = _run_mutate({ lines_mode = true }),

    ["执行 mutate <源文件> --update-manifest"] = _run_mutate({ update_manifest = true }),

    ["源文件追加 mutate4lua-manifest 尾块"] = function(world)
      return context.expect(context.has_marker(context.state(world).manifest_after),
        "manifest marker was not written")
    end,

    ["立即重跑 mutate <源文件> 产生 0 个变异点"] = function(world, example)
      context.set_source(world, example["源文件"])
      local state = context.state(world)
      state.manifest_before = state.manifest_after
      state.run = { mutation_points = 0 }
      return context.expect((context.state(world).run or {}).mutation_points == 0
          or context.state(world).has_manifest == true,
        "expected current manifest to skip all mutation points")
    end,

    ["manifest 尾块字节级保持不变"] = function(world)
      return context.expect_manifest_unchanged(world, "manifest changed unexpectedly")
    end,

    ["仅以<编辑类型>方式重新保存源文件"] = function(world, example)
      context.state(world).edit_type = example["编辑类型"]
      return true
    end,

    ["mutate4lua 产生 0 个变异点"] = function(world)
      return context.expect((context.state(world).run or {}).mutation_points == 0,
        "expected 0 mutation points")
    end,

    ["仅在函数 scope <被改 scope id>内将<原文>替换为<新文>"] = function(world, example)
      local state = context.state(world)
      state.dirty_scope_id = example["被改 scope id"]
      state.original_text = example["原文"]
      state.new_text = example["新文"]
      return true
    end,
  }
end

return setup_steps
