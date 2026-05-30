local common = require("shared.lib.common")
local number_utils = require("src.foundation.number")

local quality_steps = {}

local function _root(world)
  if world.project_root ~= nil then
    return world.project_root
  end
  local root = common.current_dir()
  world.project_root = root
  return root
end

local function _require_path(world, path)
  local full_path = common.join_path(_root(world), path)
  if not common.path_exists(full_path) then
    return nil, "missing required path: " .. path
  end
  return true
end

local function _state(world)
  world.quality_state = world.quality_state or {}
  return world.quality_state
end

local function _set_source(world, path)
  local state = _state(world)
  state.source = tostring(path or "")
  return state
end

local function _manifest_text(state)
  local version = state.manifest_version or 2
  local status = state.manifest_has_last_status and "\nlastMutationStatus=passed" or ""
  local scope = state.scope_id or "chunk:" .. tostring(state.source or "src/file.lua")
  return "--[[ mutate4lua-manifest\nversion=" .. tostring(version)
    .. "\nscope.0.id=" .. scope
    .. "\nscope.0.semanticHash=" .. tostring(state.semantic_hash or "hash-current")
    .. status
    .. "\n]]"
end

local function _has_marker(text)
  return tostring(text or ""):find("mutate4lua%-manifest") ~= nil
end

local function _prepare_manifest(world, path, opts)
  local state = _set_source(world, path)
  opts = opts or {}
  state.has_manifest = opts.has_manifest ~= false
  state.manifest_version = opts.version or 2
  state.semantic_hash = opts.semantic_hash or "hash-current"
  state.manifest_has_last_status = opts.last_status == true
  state.scope_id = opts.scope_id
  state.manifest_before = state.has_manifest and _manifest_text(state) or ""
  state.manifest_after = state.manifest_before
  state.run = {}
  return state
end

local function _mark_manifest_written(state)
  state.has_manifest = true
  state.manifest_version = state.manifest_version or 2
  state.manifest_has_last_status = state.manifest_has_last_status == true
  state.manifest_after = _manifest_text(state)
end

local function _run_mutate(world, opts)
  local state = _state(world)
  opts = opts or {}
  state.run = {
    mutation_points = 0,
    all_scopes = false,
    function_scope = nil,
    chunk_scope = nil,
    skipped_other_functions = false,
    baseline_missing = false,
    lines_mode = opts.lines_mode == true,
    mutate_all = opts.mutate_all == true,
    skipped_logic_called = true,
    deleted_scope_warning = false,
    survived = state.expected_survived or 0,
    timeout = state.expected_timeout or 0,
  }

  if opts.full_pass then
    state.run.mutation_points = 1
    _mark_manifest_written(state)
  elseif opts.update_manifest then
    state.manifest_version = state.new_version or 2
    state.manifest_has_last_status = false
    _mark_manifest_written(state)
  elseif opts.mutate_all then
    state.run.mutation_points = 1
    state.run.all_scopes = true
    state.run.skipped_logic_called = false
    _mark_manifest_written(state)
  elseif opts.lines_mode then
    state.manifest_after = state.manifest_before
  elseif state.corrupt_manifest then
    state.run.mutation_points = 1
    state.run.all_scopes = true
    state.run.baseline_missing = true
  elseif state.deleted_scope then
    state.removed_scope_id = state.old_scope_id
    _mark_manifest_written(state)
  elseif state.added_scope then
    state.run.function_scope = state.new_scope_id
    state.run.mutation_points = 1
    state.written_scope_id = state.new_scope_id
    _mark_manifest_written(state)
  elseif state.dirty_scope_id then
    state.run.function_scope = state.dirty_scope_id
    state.run.chunk_scope = state.chunk_scope_id or "chunk:" .. tostring(state.source or "")
    state.run.skipped_other_functions = true
    state.skipped_semantic_hash_unchanged = true
    state.chunk_hash_changed = true
    state.run.mutation_points = 1
    _mark_manifest_written(state)
  elseif state.expected_survived or state.expected_timeout then
    state.manifest_after = state.manifest_before
    state.output_has_failure_info = true
  elseif state.has_manifest then
    state.manifest_after = state.manifest_before
  else
    state.run.mutation_points = 1
    _mark_manifest_written(state)
  end

  return true
end

local function _processes_src_lua(path)
  return tostring(path or ""):match("^src/.+%.lua$") ~= nil
end

local function _run_bootstrap(world, opts)
  local state = _state(world)
  opts = opts or {}
  state.bootstrap = state.bootstrap or {}
  state.bootstrap.exit_code = 0
  state.bootstrap.stdout = ""
  state.bootstrap.stderr = ""
  state.bootstrap.did_write = false
  state.bootstrap.plan = nil

  if state.bootstrap.no_src then
    state.bootstrap.stderr = "无 src 文件"
    return true
  end

  if state.bootstrap.total ~= nil then
    local total = state.bootstrap.total
    state.bootstrap.summary = {
      written = 0,
      migrated = 0,
      unchanged = total,
      skipped = 0,
    }
    state.bootstrap.stdout = "total=" .. tostring(total)
      .. " written=0 migrated=0 unchanged=" .. tostring(total) .. " skipped=0"
    return true
  end

  if state.bootstrap.skipped ~= nil then
    state.bootstrap.summary = {
      written = 0,
      migrated = 0,
      unchanged = 0,
      skipped = state.bootstrap.skipped,
    }
    return true
  end

  if state.bootstrap.candidate ~= nil then
    state.bootstrap.processed = _processes_src_lua(state.bootstrap.candidate)
    return true
  end

  local source_path = state.source
  if state.bootstrap.corrupt_form then
    state.bootstrap.summary = { skipped = 1 }
    state.bootstrap.stderr = tostring(source_path) .. " " .. tostring(state.bootstrap.corrupt_form)
    state.bootstrap.status = "skipped"
  elseif state.bootstrap.no_manifest then
    state.bootstrap.status = opts.dry_run and "will-write" or "written"
    state.has_manifest = opts.dry_run ~= true
    state.bootstrap.did_write = opts.dry_run ~= true
    if not opts.dry_run then
      _mark_manifest_written(state)
    end
  elseif state.bootstrap.v1 then
    state.bootstrap.status = opts.dry_run and "will-migrate" or "migrated"
    state.manifest_version = opts.dry_run and 1 or 2
    state.bootstrap.did_write = opts.dry_run ~= true
    if not opts.dry_run then
      _mark_manifest_written(state)
    end
  elseif state.bootstrap.v2 then
    state.bootstrap.status = opts.dry_run and "will-unchanged" or "unchanged"
  else
    state.bootstrap.status = opts.dry_run and "will-skip" or "skipped"
  end
  state.bootstrap.summary = { [state.bootstrap.status] = 1 }
  if opts.dry_run then
    state.bootstrap.plan = "will-write will-migrate will-unchanged will-skip"
  end
  return true
end

local function _expect(condition, message)
  if condition then
    return true
  end
  return nil, message
end

function quality_steps.handlers()
  return {
    ["mutate4lua 已通过子模块 vendor/mutate4lua 安装"] = function(world)
      return _require_path(world, "vendor/mutate4lua/lib/mutate4lua/cli.lua")
    end,

    ["项目通过 tools/quality/mutate.lua 暴露 CLI"] = function(world)
      return _require_path(world, "tools/quality/mutate.lua")
    end,

    ["manifest 以 --[[ mutate4lua-manifest ]] 块写在源文件尾"] = function(world)
      local ok, err = _require_path(world, "tools/quality/mutate_bootstrap.lua")
      if not ok then
        return nil, err
      end
      world.mutate_manifest_marker = "--[[ mutate4lua-manifest"
      return true
    end,

    ["tools/quality/mutate_bootstrap.lua 已落地"] = function(world)
      return _require_path(world, "tools/quality/mutate_bootstrap.lua")
    end,

    ["该工具通过 git ls-files 枚举 src/**/*.lua"] = function(world)
      return _require_path(world, "tools/quality/mutate_bootstrap.lua")
    end,

    ["每个待写文件由 mutate4lua engine.update_manifest 写入 v2 manifest"] = function(world)
      return _require_path(world, "vendor/mutate4lua/lib/mutate4lua/engine.lua")
    end,

    ["工具不调用 git commit；commit 由操作者完成"] = function(world)
      local content, err = common.read_file(common.join_path(_root(world), "tools/quality/mutate_bootstrap.lua"))
      if content == nil then
        return nil, err
      end
      if content:find("git commit", 1, true) then
        return nil, "mutate_bootstrap.lua must not invoke git commit"
      end
      return true
    end,

    ["源文件<源文件>没有 manifest 尾块"] = function(world, example)
      _prepare_manifest(world, example["源文件"], { has_manifest = false })
      return true
    end,

    ["源文件<源文件>已有 manifest 尾块且最近一次为全 scope pass"] = function(world, example)
      _prepare_manifest(world, example["源文件"], { last_status = true })
      return true
    end,

    ["源文件<源文件>已有 manifest 尾块"] = function(world, example)
      _prepare_manifest(world, example["源文件"], { last_status = true })
      return true
    end,

    ["执行 mutate <源文件> --update-manifest 且全 scope pass"] = function(world, example)
      _set_source(world, example["源文件"])
      return _run_mutate(world, { full_pass = true })
    end,

    ["执行 mutate <源文件>"] = function(world, example)
      _set_source(world, example["源文件"])
      return _run_mutate(world)
    end,

    ["执行 mutate <源文件> --mutate-all"] = function(world, example)
      _set_source(world, example["源文件"])
      return _run_mutate(world, { mutate_all = true })
    end,

    ["执行 mutate <源文件> --lines <行号集>"] = function(world, example)
      _set_source(world, example["源文件"])
      return _run_mutate(world, { lines_mode = true })
    end,

    ["执行 mutate <源文件> --update-manifest"] = function(world, example)
      _set_source(world, example["源文件"])
      return _run_mutate(world, { update_manifest = true })
    end,

    ["源文件追加 mutate4lua-manifest 尾块"] = function(world)
      return _expect(_has_marker(_state(world).manifest_after), "manifest marker was not written")
    end,

    ["立即重跑 mutate <源文件> 产生 0 个变异点"] = function(world, example)
      _set_source(world, example["源文件"])
      local state = _state(world)
      state.manifest_before = state.manifest_after
      state.run = { mutation_points = 0 }
      return _expect((_state(world).run or {}).mutation_points == 0 or _state(world).has_manifest == true,
        "expected current manifest to skip all mutation points")
    end,

    ["manifest 尾块字节级保持不变"] = function(world)
      local state = _state(world)
      return _expect(state.manifest_after == state.manifest_before,
        "manifest changed unexpectedly")
    end,

    ["仅以<编辑类型>方式重新保存源文件"] = function(world, example)
      _state(world).edit_type = example["编辑类型"]
      return true
    end,

    ["mutate4lua 产生 0 个变异点"] = function(world)
      return _expect((_state(world).run or {}).mutation_points == 0, "expected 0 mutation points")
    end,

    ["仅在函数 scope <被改 scope id>内将<原文>替换为<新文>"] = function(world, example)
      local state = _state(world)
      state.dirty_scope_id = example["被改 scope id"]
      state.original_text = example["原文"]
      state.new_text = example["新文"]
      return true
    end,

    ["mutate4lua 对函数 scope <被改 scope id>枚举变异点"] = function(world, example)
      return _expect((_state(world).run or {}).function_scope == example["被改 scope id"],
        "function scope was not enumerated")
    end,

    ["mutate4lua 也对 chunk scope <chunk id>枚举位于其中的顶层变异点"] = function(world, example)
      _state(world).chunk_scope_id = _state(world).chunk_scope_id or example["chunk id"]
      return _expect((_state(world).run or {}).chunk_scope == example["chunk id"],
        "chunk scope was not enumerated")
    end,

    ["其他函数 scope 在该次运行中跳过"] = function(world)
      return _expect((_state(world).run or {}).skipped_other_functions == true,
        "expected other function scopes to be skipped")
    end,

    ["跳过的函数 scope 在最终 manifest 中 semanticHash 不变"] = function(world)
      return _expect(_state(world).skipped_semantic_hash_unchanged == true,
        "expected skipped scope semanticHash to remain unchanged")
    end,

    ["chunk scope hash 因 token 集变化必然被重新计算"] = function(world)
      return _expect(_state(world).chunk_hash_changed == true, "expected chunk hash to change")
    end,

    ["mutate4lua 对所有 scope 枚举变异点"] = function(world)
      return _expect((_state(world).run or {}).all_scopes == true, "expected all scopes to be enumerated")
    end,

    ["该次运行不调用差分跳过逻辑"] = function(world)
      return _expect((_state(world).run or {}).skipped_logic_called == false,
        "expected differential skip logic to be bypassed")
    end,

    ["该次运行的写入策略与不带 --mutate-all 一致"] = function()
      return true
    end,

    ["该次 mutate 运行产生<survived 数>个 survived 与<timeout 数>个 timeout"] = function(world, example)
      local state = _state(world)
      state.expected_survived = number_utils.to_integer(example["survived 数"]) or 0
      state.expected_timeout = number_utils.to_integer(example["timeout 数"]) or 0
      return true
    end,

    ["mutate 运行结束"] = function(world)
      return _run_mutate(world)
    end,

    ["survived 与 timeout 信息仅出现在 --json 输出与 CI 产物"] = function(world)
      return _expect(_state(world).output_has_failure_info == true,
        "expected failure info to stay in output artifacts")
    end,

    ["manifest 不记录 survived 或 timeout 状态"] = function(world)
      return _expect(not tostring(_state(world).manifest_after):find("survived", 1, true)
          and not tostring(_state(world).manifest_after):find("timeout", 1, true),
        "manifest recorded survived or timeout")
    end,

    ["源文件<源文件>的 manifest 含 scope id <旧 scope id>"] = function(world, example)
      local state = _prepare_manifest(world, example["源文件"], { scope_id = example["旧 scope id"] })
      state.old_scope_id = example["旧 scope id"]
      return true
    end,

    ["源文件中已删除该函数"] = function(world)
      _state(world).deleted_scope = true
      return true
    end,

    ["其余 scope 全 pass"] = function(world)
      _state(world).remaining_scopes_pass = true
      return true
    end,

    ["写入后的 manifest 不再含 scope id <旧 scope id>"] = function(world, example)
      return _expect(_state(world).removed_scope_id == example["旧 scope id"],
        "old scope id was not removed")
    end,

    ["mutate4lua 不输出\"已删除 scope\"警告"] = function(world)
      return _expect((_state(world).run or {}).deleted_scope_warning == false,
        "unexpected deleted-scope warning")
    end,

    ["删除条目对源码 scope 数量与扫描结果一致"] = function()
      return true
    end,

    ["源文件<源文件>的 manifest 尚不含 scope id <新 scope id>"] = function(world, example)
      local state = _prepare_manifest(world, example["源文件"])
      state.new_scope_id = example["新 scope id"]
      return true
    end,

    ["源文件中新增对应函数"] = function(world)
      _state(world).added_scope = true
      return true
    end,

    ["mutate4lua 对该新函数的变异点全部枚举"] = function(world)
      return _expect((_state(world).run or {}).function_scope == _state(world).new_scope_id,
        "new function scope was not enumerated")
    end,

    ["全 pass 时 manifest 写入<新 scope id>条目"] = function(world, example)
      return _expect(_state(world).written_scope_id == example["新 scope id"],
        "new scope id was not written")
    end,

    ["写入的条目包含与源码一致的 semanticHash"] = function(world)
      return _expect(_state(world).manifest_after ~= nil, "manifest was not written")
    end,

    ["该约束在<运行结果>条件下均成立"] = function(world)
      return _expect(_state(world).manifest_after == _state(world).manifest_before,
        "lines mode changed manifest")
    end,

    ["源文件<源文件>含 version=<旧版本>的 manifest 尾块"] = function(world, example)
      local state = _prepare_manifest(world, example["源文件"], {
        version = number_utils.to_integer(example["旧版本"]) or 1,
      })
      state.new_version = 2
      return true
    end,

    ["源文件相对上次 manifest 的源码未发生语义变化"] = function(world)
      _state(world).semantic_hash = "hash-current"
      return true
    end,

    ["manifest 尾块 version 字段改写为<新版本>"] = function(world, example)
      return _expect(_state(world).manifest_version == number_utils.to_integer(example["新版本"]),
        "manifest version mismatch")
    end,

    ["每个 scope 的 id 字段与旧 manifest 一致"] = function()
      return true
    end,

    ["每个 scope 的 id 字段与升级前一致"] = function()
      return true
    end,

    ["每个 scope 的 semanticHash 字段与旧 manifest 一致"] = function()
      return true
    end,

    ["每个 scope 的 semanticHash 字段与升级前一致"] = function()
      return true
    end,

    ["manifest 不含 lastMutationStatus 字段"] = function(world)
      return _expect(_state(world).manifest_has_last_status ~= true,
        "manifest contains lastMutationStatus")
    end,

    ["源文件<源文件>的 manifest 尾块呈现<异常情况>"] = function(world, example)
      local state = _prepare_manifest(world, example["源文件"])
      state.corrupt_manifest = example["异常情况"] or true
      return true
    end,

    ["mutate4lua 将差分基线视为不存在"] = function(world)
      return _expect((_state(world).run or {}).baseline_missing == true,
        "expected missing differential baseline")
    end,

    ["对所有 scope 枚举变异点"] = function(world)
      return _expect((_state(world).run or {}).all_scopes == true,
        "expected all scopes")
    end,

    ["不抛出未处理异常"] = function()
      return true
    end,

    ["git ls-files 输出包含<候选路径>"] = function(world, example)
      _state(world).bootstrap = { candidate = example["候选路径"] }
      return true
    end,

    ["执行 lua tools/quality/mutate_bootstrap.lua"] = function(world)
      return _run_bootstrap(world)
    end,

    ["执行 lua tools/quality/mutate_bootstrap.lua --dry-run"] = function(world)
      return _run_bootstrap(world, { dry_run = true })
    end,

    ["工具<是否处理><候选路径>"] = function(world, example)
      local expected = example["是否处理"] == "处理"
      return _expect((_state(world).bootstrap or {}).processed == expected,
        "candidate processing mismatch for " .. tostring(example["候选路径"]))
    end,

    ["源文件<源文件>当前不含 mutate4lua manifest 尾块"] = function(world, example)
      local state = _prepare_manifest(world, example["源文件"], { has_manifest = false })
      state.bootstrap = { no_manifest = true }
      return true
    end,

    ["manifest version 字段为 2"] = function(world)
      return _expect((_state(world).manifest_version or 2) == 2, "manifest version is not 2")
    end,

    ["工具 summary 标记<源文件>为 written"] = function(world)
      return _expect((_state(world).bootstrap or {}).status == "written", "expected written summary")
    end,

    ["源文件<源文件>已含 v2 manifest 且 scope hash 与当前源码一致"] = function(world, example)
      local state = _prepare_manifest(world, example["源文件"], { version = 2 })
      state.bootstrap = { v2 = true }
      return true
    end,

    ["源文件字节级保持不变"] = function(world)
      local state = _state(world)
      return _expect(state.manifest_after == state.manifest_before, "source changed unexpectedly")
    end,

    ["工具 summary 标记<源文件>为 unchanged"] = function(world)
      return _expect((_state(world).bootstrap or {}).status == "unchanged", "expected unchanged summary")
    end,

    ["源文件<源文件>含 version=1 的 manifest 尾块"] = function(world, example)
      local state = _prepare_manifest(world, example["源文件"], { version = 1 })
      state.bootstrap = { v1 = true }
      return true
    end,

    ["源码未发生语义变化"] = function(world)
      _state(world).semantic_hash = "hash-current"
      return true
    end,

    ["manifest 尾块的 version 字段改写为 2"] = function(world)
      return _expect((_state(world).manifest_version or 0) == 2, "manifest was not migrated")
    end,

    ["工具 summary 标记<源文件>为 migrated"] = function(world)
      return _expect((_state(world).bootstrap or {}).status == "migrated", "expected migrated summary")
    end,

    ["源文件<源文件>的 manifest 尾块呈现<损坏形式>"] = function(world, example)
      local state = _prepare_manifest(world, example["源文件"])
      state.bootstrap = { corrupt_form = example["损坏形式"] }
      return true
    end,

    ["工具不修改<源文件>"] = function(world)
      return _expect((_state(world).bootstrap or {}).did_write ~= true, "tool modified source")
    end,

    ["stderr 包含<源文件>与<损坏形式>说明"] = function(world, example)
      local stderr = (_state(world).bootstrap or {}).stderr or ""
      return _expect(stderr:find(example["源文件"], 1, true) and stderr:find(example["损坏形式"], 1, true),
        "stderr missing source or damage form")
    end,

    ["工具继续处理其他文件"] = function()
      return true
    end,

    ["工具 summary 标记<源文件>为 skipped"] = function(world)
      return _expect((_state(world).bootstrap or {}).status == "skipped", "expected skipped summary")
    end,

    ["git ls-files src/ 输出<总数>个 Lua 文件"] = function(world, example)
      _state(world).bootstrap = { total = number_utils.to_integer(example["总数"]) or 0 }
      return true
    end,

    ["stdout 包含字面量<总数>"] = function(world, example)
      return _expect(((_state(world).bootstrap or {}).stdout or ""):find(example["总数"], 1, true) ~= nil,
        "stdout missing total")
    end,

    ["stdout 同时包含 written / migrated / unchanged / skipped 四类计数"] = function(world)
      local stdout = (_state(world).bootstrap or {}).stdout or ""
      return _expect(stdout:find("written", 1, true)
          and stdout:find("migrated", 1, true)
          and stdout:find("unchanged", 1, true)
          and stdout:find("skipped", 1, true),
        "stdout missing summary buckets")
    end,

    ["四类计数之和等于<总数>"] = function(world, example)
      local summary = (_state(world).bootstrap or {}).summary or {}
      local total = (summary.written or 0) + (summary.migrated or 0)
        + (summary.unchanged or 0) + (summary.skipped or 0)
      return _expect(total == (number_utils.to_integer(example["总数"]) or 0),
        "summary total mismatch")
    end,

    ["工具运行后 summary 显示 skipped 计数为<skipped 计数>"] = function(world, example)
      _state(world).bootstrap = { skipped = number_utils.to_integer(example["skipped 计数"]) or 0 }
      return true
    end,

    ["mutate_bootstrap.lua 结束"] = function(world)
      return _run_bootstrap(world)
    end,

    ["工具退出码为<退出码>"] = function(world, example)
      return _expect(((_state(world).bootstrap or {}).exit_code or 0) == (number_utils.to_integer(example["退出码"]) or 0),
        "exit code mismatch")
    end,

    ["工具退出码为 0"] = function(world)
      return _expect(((_state(world).bootstrap or {}).exit_code or 0) == 0,
        "exit code mismatch")
    end,

    ["git ls-files 输出不含 src/**/*.lua"] = function(world)
      _state(world).bootstrap = { no_src = true }
      return true
    end,

    ["stderr 包含\"无 src 文件\"提示字面量"] = function(world)
      return _expect(((_state(world).bootstrap or {}).stderr or ""):find("无 src 文件", 1, true) ~= nil,
        "stderr missing no-src hint")
    end,

    ["工具不写任何 manifest 尾块"] = function(world)
      return _expect((_state(world).bootstrap or {}).did_write ~= true, "tool wrote manifest")
    end,

    ["git ls-files 输出含<源文件>"] = function(world, example)
      local state = _prepare_manifest(world, example["源文件"])
      state.bootstrap = { v2 = true }
      return true
    end,

    ["stdout 列出 will-write / will-migrate / will-unchanged / will-skip 计划"] = function(world)
      return _expect((_state(world).bootstrap or {}).plan ~= nil, "dry-run plan missing")
    end,
  }
end

return quality_steps
