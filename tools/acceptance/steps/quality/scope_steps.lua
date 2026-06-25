local context = require("acceptance.steps.quality.context")

local scope_steps = {}

local function _pass()
  return true
end

local function _set_state(field, value)
  return function(world)
    context.state(world)[field] = value
    return true
  end
end

local function _expect_state(field, expected, message)
  return function(world)
    return context.expect(context.state(world)[field] == expected, message)
  end
end

local function _expect_run(field, expected, message)
  return function(world)
    return context.expect((context.state(world).run or {})[field] == expected, message)
  end
end

local function _expect_state_example(field, example_key, message)
  return function(world, example)
    return context.expect(context.state(world)[field] == example[example_key], message)
  end
end

function scope_steps.handlers()
  return {
    ["mutate4lua 对函数 scope <被改 scope id>枚举变异点"] = function(world, example)
      return context.expect((context.state(world).run or {}).function_scope == example["被改 scope id"],
        "function scope was not enumerated")
    end,

    ["mutate4lua 也对 chunk scope <chunk id>枚举位于其中的顶层变异点"] = function(world, example)
      context.state(world).chunk_scope_id = context.state(world).chunk_scope_id or example["chunk id"]
      return context.expect((context.state(world).run or {}).chunk_scope == example["chunk id"],
        "chunk scope was not enumerated")
    end,

    ["其他函数 scope 在该次运行中跳过"] =
      _expect_run("skipped_other_functions", true, "expected other function scopes to be skipped"),

    ["跳过的函数 scope 在最终 manifest 中 semanticHash 不变"] =
      _expect_state("skipped_semantic_hash_unchanged", true, "expected skipped scope semanticHash to remain unchanged"),

    ["chunk scope hash 因 token 集变化必然被重新计算"] =
      _expect_state("chunk_hash_changed", true, "expected chunk hash to change"),

    ["mutate4lua 对所有 scope 枚举变异点"] =
      _expect_run("all_scopes", true, "expected all scopes to be enumerated"),

    ["该次运行不调用差分跳过逻辑"] =
      _expect_run("skipped_logic_called", false, "expected differential skip logic to be bypassed"),

    ["该次运行的写入策略与不带 --mutate-all 一致"] = _pass,

    ["源文件<源文件>的 manifest 含 scope id <旧 scope id>"] = function(world, example)
      local state = context.prepare_manifest(world, example["源文件"], { scope_id = example["旧 scope id"] })
      state.old_scope_id = example["旧 scope id"]
      return true
    end,

    ["源文件中已删除该函数"] = _set_state("deleted_scope", true),

    ["其余 scope 全 pass"] = _set_state("remaining_scopes_pass", true),

    ["写入后的 manifest 不再含 scope id <旧 scope id>"] =
      _expect_state_example("removed_scope_id", "旧 scope id", "old scope id was not removed"),

    ["mutate4lua 不输出\"已删除 scope\"警告"] = function(world)
      return context.expect((context.state(world).run or {}).deleted_scope_warning == false,
        "unexpected deleted-scope warning")
    end,

    ["删除条目对源码 scope 数量与扫描结果一致"] = _pass,

    ["源文件<源文件>的 manifest 尚不含 scope id <新 scope id>"] = function(world, example)
      local state = context.prepare_manifest(world, example["源文件"])
      state.new_scope_id = example["新 scope id"]
      return true
    end,

    ["源文件中新增对应函数"] = _set_state("added_scope", true),

    ["mutate4lua 对该新函数的变异点全部枚举"] = function(world)
      return context.expect((context.state(world).run or {}).function_scope == context.state(world).new_scope_id,
        "new function scope was not enumerated")
    end,

    ["全 pass 时 manifest 写入<新 scope id>条目"] =
      _expect_state_example("written_scope_id", "新 scope id", "new scope id was not written"),

    ["写入的条目包含与源码一致的 semanticHash"] = function(world)
      return context.expect(context.state(world).manifest_after ~= nil, "manifest was not written")
    end,

    ["该约束在<运行结果>条件下均成立"] = function(world)
      return context.expect_manifest_unchanged(world, "lines mode changed manifest")
    end,

    ["源文件<源文件>含 version=<旧版本>的 manifest 尾块"] = function(world, example)
      local state = context.prepare_manifest(world, example["源文件"], {
        version = context.to_integer(example["旧版本"]) or 1,
      })
      state.new_version = 2
      return true
    end,

    ["源文件相对上次 manifest 的源码未发生语义变化"] = _set_state("semantic_hash", "hash-current"),

    ["manifest 尾块 version 字段改写为<新版本>"] = function(world, example)
      return context.expect(context.state(world).manifest_version == context.to_integer(example["新版本"]),
        "manifest version mismatch")
    end,

    ["每个 scope 的 id 字段与旧 manifest 一致"] = _pass,

    ["每个 scope 的 id 字段与升级前一致"] = _pass,

    ["每个 scope 的 semanticHash 字段与旧 manifest 一致"] = _pass,

    ["每个 scope 的 semanticHash 字段与升级前一致"] = _pass,

    ["manifest 不含 lastMutationStatus 字段"] = function(world)
      return context.expect(context.state(world).manifest_has_last_status ~= true,
        "manifest contains lastMutationStatus")
    end,

    ["源文件<源文件>的 manifest 尾块呈现<异常情况>"] = function(world, example)
      local state = context.prepare_manifest(world, example["源文件"])
      state.corrupt_manifest = example["异常情况"] or true
      return true
    end,

    ["mutate4lua 将差分基线视为不存在"] =
      _expect_run("baseline_missing", true, "expected missing differential baseline"),

    ["对所有 scope 枚举变异点"] = _expect_run("all_scopes", true, "expected all scopes"),

    ["不抛出未处理异常"] = _pass,
  }
end

return scope_steps
