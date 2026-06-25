return function(policy)
  function policy.preflight_differential(target, manifest_data)
    if target == nil or tostring(target):sub(-4) ~= ".lua" then
      return { allowed = true }
    end
    if manifest_data == nil then
      return { allowed = true }
    end
    if policy.is_bootstrap_only(manifest_data) then
      return {
        allowed = false,
        reason = policy.REASON_BOOTSTRAP_ONLY,
        target = target,
      }
    end
    return { allowed = true }
  end

  function policy.manifest_write_decision(opts, result)
    opts = opts or {}
    result = result or {}

    if opts.update_manifest then
      return { write = true, reason = policy.REASON_EXPLICIT_UPDATE }
    end

    if opts.lines_mode or opts.line_set ~= nil then
      return { write = false, reason = policy.REASON_LINES_MODE }
    end

    if (tonumber(result.survived) or 0) > 0 then
      return { write = false, reason = policy.REASON_SURVIVED }
    end

    if (tonumber(result.timeout) or 0) > 0 then
      return { write = false, reason = policy.REASON_TIMEOUT }
    end

    return { write = true, reason = policy.REASON_PASS }
  end

  function policy.summarize_mutation_result(file, json)
    json = json or {}
    local summary = {
      file = file,
      total_sites = tonumber(json.total_sites) or 0,
      killed = tonumber(json.killed) or 0,
      survived = tonumber(json.survived) or 0,
      timeout = tonumber(json.timeout) or 0,
      score = tonumber(json.score) or 100,
    }
    summary.has_survived = summary.survived > 0
    summary.has_timeout = summary.timeout > 0
    summary.write_decision = policy.manifest_write_decision({}, summary)
    return summary
  end
end
