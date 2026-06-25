local manifest_policy = require("quality.mutation_manifest_policy")
local context = require("acceptance.steps.quality.context")

local runtime = {}

function runtime.run_mutate(world, opts)
  local state = context.state(world)
  opts = opts or {}
  local write_decision = manifest_policy.manifest_write_decision({
    update_manifest = opts.update_manifest == true,
    lines_mode = opts.lines_mode == true,
  }, {
    survived = state.expected_survived or 0,
    timeout = state.expected_timeout or 0,
  })
  state.manifest_write_decision = write_decision
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
    if write_decision.write then
      context.mark_manifest_written(state)
    end
  elseif opts.update_manifest then
    state.manifest_version = state.new_version or 2
    state.manifest_has_last_status = false
    if write_decision.write then
      context.mark_manifest_written(state)
    end
  elseif opts.mutate_all then
    state.run.mutation_points = 1
    state.run.all_scopes = true
    state.run.skipped_logic_called = false
    if write_decision.write then
      context.mark_manifest_written(state)
    end
  elseif opts.lines_mode then
    state.manifest_after = state.manifest_before
  elseif state.corrupt_manifest then
    state.run.mutation_points = 1
    state.run.all_scopes = true
    state.run.baseline_missing = true
  elseif state.deleted_scope then
    state.removed_scope_id = state.old_scope_id
    if write_decision.write then
      context.mark_manifest_written(state)
    end
  elseif state.added_scope then
    state.run.function_scope = state.new_scope_id
    state.run.mutation_points = 1
    state.written_scope_id = state.new_scope_id
    if write_decision.write then
      context.mark_manifest_written(state)
    end
  elseif state.dirty_scope_id then
    state.run.function_scope = state.dirty_scope_id
    state.run.chunk_scope = state.chunk_scope_id or "chunk:" .. tostring(state.source or "")
    state.run.skipped_other_functions = true
    state.skipped_semantic_hash_unchanged = true
    state.chunk_hash_changed = true
    state.run.mutation_points = 1
    if write_decision.write then
      context.mark_manifest_written(state)
    end
  elseif state.expected_survived or state.expected_timeout then
    state.manifest_after = state.manifest_before
    state.output_has_failure_info = true
  elseif state.has_manifest then
    state.manifest_after = state.manifest_before
  else
    state.run.mutation_points = 1
    if write_decision.write then
      context.mark_manifest_written(state)
    end
  end

  return true
end

return runtime
