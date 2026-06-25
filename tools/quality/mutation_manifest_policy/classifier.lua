return function(policy)
  local _START_MARKER_PATTERN = "%-%-%[%[ mutate4lua%-manifest\n"
  local _END_MARKER = "]]"

  local function _normalize_newlines(text)
    return tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  end

  local function _trim(text)
    return tostring(text or ""):match("^%s*(.-)%s*$")
  end

  function policy.is_bootstrap_only(manifest_data)
    if manifest_data == nil then
      return false
    end
    local scopes = manifest_data.scopes
    if scopes == nil or #scopes == 0 then
      return false
    end
    for _, scope in ipairs(scopes) do
      if scope.last_mutation_status ~= nil then
        return false
      end
    end
    return true
  end

  function policy.detect_drift(existing_scopes, current_scopes)
    if existing_scopes == nil or current_scopes == nil then
      return true
    end
    if #existing_scopes ~= #current_scopes then
      return true
    end
    for i = 1, #existing_scopes do
      local existing = existing_scopes[i] or {}
      local current = current_scopes[i] or {}
      if existing.id ~= current.id then return true end
      if existing.semantic_hash ~= current.semantic_hash then return true end
    end
    return false
  end

  function policy.classify_source(source, manifest_data, current_data)
    if source == nil or source == "" then
      return { state = policy.STATE_MISSING }
    end

    source = _normalize_newlines(source)
    local start_at = source:match("()" .. _START_MARKER_PATTERN)
    if not start_at then
      return { state = policy.STATE_MISSING }
    end

    local tail = source:sub(start_at)
    if _trim(tail):sub(-2) ~= _END_MARKER then
      return { state = policy.STATE_CORRUPT, reason = "missing end marker" }
    end

    if manifest_data == nil then
      return { state = policy.STATE_V2 }
    end

    local version = tonumber(manifest_data.version) or 1
    if version < 2 then
      return { state = policy.STATE_V1, version = version }
    end

    if current_data ~= nil and policy.detect_drift(manifest_data.scopes, current_data.scopes) then
      return { state = policy.STATE_DRIFTED, version = version }
    end

    if policy.is_bootstrap_only(manifest_data) then
      return { state = policy.STATE_BOOTSTRAP_ONLY, version = version }
    end

    if current_data ~= nil then
      return { state = policy.STATE_CURRENT, version = version }
    end

    return { state = policy.STATE_V2, version = version }
  end
end
