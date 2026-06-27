local context = require("acceptance.steps.quality.context")

local manifest_steps = {}

local _KNOWN_BOOTSTRAP_SOURCES = {
  ["src/foundation/log.lua"] = true,
  ["src/rules/market/effects.lua"] = true,
  ["src/turn/loop/init.lua"] = true,
}

local _KNOWN_CORRUPT_FORMS = {
  ["缺失结尾 ]] 标记"] = true,
  ["起始标记后内容截断"] = true,
}

local function _expect_status(status)
  return function(world)
    return context.expect((context.state(world).bootstrap or {}).status == status,
      "expected " .. status .. " summary")
  end
end

local function _prepare_bootstrap_manifest(opts, bootstrap_state)
  return function(world, example)
    local known, known_err = context.expect_known_value(example["源文件"], _KNOWN_BOOTSTRAP_SOURCES, "source")
    if not known then
      return nil, known_err
    end
    local state = context.prepare_manifest(world, example["源文件"], opts)
    state.bootstrap = bootstrap_state
    return true
  end
end

function manifest_steps.handlers()
  return {
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
      if _KNOWN_CORRUPT_FORMS[tostring(example["损坏形式"] or "")] ~= true then
        return nil, "unknown corrupt manifest fixture value: " .. tostring(example["损坏形式"])
      end
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

    ["工具 summary 标记<源文件>为 skipped"] = _expect_status("skipped"),
  }
end

return manifest_steps
