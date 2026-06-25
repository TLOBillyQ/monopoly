return function(policy)
  local function _outcome(path, action, extra)
    local result = extra or {}
    result.path = path
    result.action = action
    return result
  end

  function policy.categorize_bootstrap(file_path, runtime)
    local source, read_err = runtime.read_source(file_path)
    if source == nil then
      return _outcome(file_path, policy.BOOTSTRAP_SKIPPED, {
        reason = read_err or "cannot read",
      })
    end

    local source_classification = policy.classify_source(source)
    if source_classification.state == policy.STATE_CORRUPT then
      return _outcome(file_path, policy.BOOTSTRAP_SKIPPED, {
        reason = source_classification.reason,
        classification = source_classification,
      })
    end

    local current_data, scan_err = runtime.scan_file(file_path)
    if current_data == nil then
      return _outcome(file_path, policy.BOOTSTRAP_SKIPPED, {
        reason = scan_err or "scan failed",
      })
    end

    if source_classification.state == policy.STATE_MISSING then
      return _outcome(file_path, policy.BOOTSTRAP_WRITTEN, {
        data = current_data,
        classification = source_classification,
      })
    end

    local existing_data = runtime.read_manifest(file_path)
    if existing_data == nil then
      return _outcome(file_path, policy.BOOTSTRAP_WRITTEN, {
        data = current_data,
        classification = source_classification,
      })
    end

    local classification = policy.classify_source(source, existing_data, current_data)
    if classification.state == policy.STATE_V1 then
      return _outcome(file_path, policy.BOOTSTRAP_MIGRATED, {
        data = current_data,
        classification = classification,
      })
    end

    if classification.state == policy.STATE_DRIFTED then
      return _outcome(file_path, policy.BOOTSTRAP_WRITTEN, {
        data = current_data,
        classification = classification,
      })
    end

    return _outcome(file_path, policy.BOOTSTRAP_UNCHANGED, {
      classification = classification,
    })
  end
end
