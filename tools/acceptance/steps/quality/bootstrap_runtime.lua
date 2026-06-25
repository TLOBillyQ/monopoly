local manifest_policy = require("quality.mutation_manifest_policy")
local context = require("acceptance.steps.quality.context")

local runtime = {}

local function _processes_src_lua(path)
  return tostring(path or ""):match("^src/.+%.lua$") ~= nil
end

local function _policy_runtime(state)
  return {
    read_source = function()
      if state.bootstrap.corrupt_form then
        return "local M = {}\n" .. "--[[ mutate4lua-manifest\nversion=2\n"
      end
      if state.has_manifest == false then
        return "local M = {}\nreturn M\n"
      end
      return "local M = {}\nreturn M\n" .. context.manifest_text(state)
    end,
    read_manifest = function()
      return context.manifest_data_from_state(state)
    end,
    scan_file = function()
      return {
        scopes = {
          {
            id = state.scope_id or "chunk:" .. tostring(state.source or "src/file.lua"),
            semantic_hash = state.semantic_hash or "hash-current",
          },
        },
      }
    end,
  }
end

function runtime.run_bootstrap(world, opts)
  local state = context.state(world)
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
  local outcome = manifest_policy.categorize_bootstrap(source_path, _policy_runtime(state))
  state.bootstrap.policy_outcome = outcome
  state.bootstrap.status = opts.dry_run and ("will-" .. outcome.action) or outcome.action
  state.bootstrap.summary = { [outcome.action] = 1 }
  if outcome.action == manifest_policy.BOOTSTRAP_SKIPPED then
    state.bootstrap.stderr = tostring(source_path) .. " " ..
      tostring(state.bootstrap.corrupt_form or outcome.reason or "skipped")
  elseif outcome.action == manifest_policy.BOOTSTRAP_WRITTEN
      or outcome.action == manifest_policy.BOOTSTRAP_MIGRATED then
    state.bootstrap.did_write = opts.dry_run ~= true
    if not opts.dry_run then
      state.has_manifest = true
      state.manifest_version = 2
      context.mark_manifest_written(state)
    end
  end
  if opts.dry_run then
    state.bootstrap.plan = "will-write will-migrate will-unchanged will-skip"
  end
  return true
end

return runtime
