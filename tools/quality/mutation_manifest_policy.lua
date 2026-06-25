local M = {}

M.STATE_MISSING = "missing"
M.STATE_CORRUPT = "corrupt"
M.STATE_V1 = "v1"
M.STATE_V2 = "v2"
M.STATE_BOOTSTRAP_ONLY = "bootstrap_only"
M.STATE_CURRENT = "current"
M.STATE_DRIFTED = "drifted"

M.BOOTSTRAP_WRITTEN = "written"
M.BOOTSTRAP_MIGRATED = "migrated"
M.BOOTSTRAP_UNCHANGED = "unchanged"
M.BOOTSTRAP_SKIPPED = "skipped"

M.REASON_BOOTSTRAP_ONLY = "bootstrap_only"
M.REASON_EXPLICIT_UPDATE = "explicit_update"
M.REASON_LINES_MODE = "lines_mode"
M.REASON_SURVIVED = "survived"
M.REASON_TIMEOUT = "timeout"
M.REASON_PASS = "pass"

local _START_MARKER_PATTERN = "%-%-%[%[ mutate4lua%-manifest\n"
local _END_MARKER = "]]"

local function _normalize_newlines(text)
  return tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
end

local function _trim(text)
  return tostring(text or ""):match("^%s*(.-)%s*$")
end

function M.is_bootstrap_only(manifest_data)
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

function M.detect_drift(existing_scopes, current_scopes)
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

function M.classify_source(source, manifest_data, current_data)
  if source == nil or source == "" then
    return { state = M.STATE_MISSING }
  end

  source = _normalize_newlines(source)
  local start_at = source:match("()" .. _START_MARKER_PATTERN)
  if not start_at then
    return { state = M.STATE_MISSING }
  end

  local tail = source:sub(start_at)
  if _trim(tail):sub(-2) ~= _END_MARKER then
    return { state = M.STATE_CORRUPT, reason = "missing end marker" }
  end

  if manifest_data == nil then
    return { state = M.STATE_V2 }
  end

  local version = tonumber(manifest_data.version) or 1
  if version < 2 then
    return { state = M.STATE_V1, version = version }
  end

  if current_data ~= nil and M.detect_drift(manifest_data.scopes, current_data.scopes) then
    return { state = M.STATE_DRIFTED, version = version }
  end

  if M.is_bootstrap_only(manifest_data) then
    return { state = M.STATE_BOOTSTRAP_ONLY, version = version }
  end

  if current_data ~= nil then
    return { state = M.STATE_CURRENT, version = version }
  end

  return { state = M.STATE_V2, version = version }
end

function M.categorize_bootstrap(file_path, runtime)
  local source, read_err = runtime.read_source(file_path)
  if source == nil then
    return {
      path = file_path,
      action = M.BOOTSTRAP_SKIPPED,
      reason = read_err or "cannot read",
    }
  end

  local source_classification = M.classify_source(source)
  if source_classification.state == M.STATE_CORRUPT then
    return {
      path = file_path,
      action = M.BOOTSTRAP_SKIPPED,
      reason = source_classification.reason,
      classification = source_classification,
    }
  end

  local current_data, scan_err = runtime.scan_file(file_path)
  if current_data == nil then
    return {
      path = file_path,
      action = M.BOOTSTRAP_SKIPPED,
      reason = scan_err or "scan failed",
    }
  end

  if source_classification.state == M.STATE_MISSING then
    return {
      path = file_path,
      action = M.BOOTSTRAP_WRITTEN,
      data = current_data,
      classification = source_classification,
    }
  end

  local existing_data = runtime.read_manifest(file_path)
  if existing_data == nil then
    return {
      path = file_path,
      action = M.BOOTSTRAP_WRITTEN,
      data = current_data,
      classification = source_classification,
    }
  end

  local classification = M.classify_source(source, existing_data, current_data)
  if classification.state == M.STATE_V1 then
    return {
      path = file_path,
      action = M.BOOTSTRAP_MIGRATED,
      data = current_data,
      classification = classification,
    }
  end

  if classification.state == M.STATE_DRIFTED then
    return {
      path = file_path,
      action = M.BOOTSTRAP_WRITTEN,
      data = current_data,
      classification = classification,
    }
  end

  return {
    path = file_path,
    action = M.BOOTSTRAP_UNCHANGED,
    classification = classification,
  }
end

function M.preflight_differential(target, manifest_data)
  if target == nil or tostring(target):sub(-4) ~= ".lua" then
    return { allowed = true }
  end
  if manifest_data == nil then
    return { allowed = true }
  end
  if M.is_bootstrap_only(manifest_data) then
    return {
      allowed = false,
      reason = M.REASON_BOOTSTRAP_ONLY,
      target = target,
    }
  end
  return { allowed = true }
end

function M.manifest_write_decision(opts, result)
  opts = opts or {}
  result = result or {}

  if opts.update_manifest then
    return { write = true, reason = M.REASON_EXPLICIT_UPDATE }
  end

  if opts.lines_mode or opts.line_set ~= nil then
    return { write = false, reason = M.REASON_LINES_MODE }
  end

  if (tonumber(result.survived) or 0) > 0 then
    return { write = false, reason = M.REASON_SURVIVED }
  end

  if (tonumber(result.timeout) or 0) > 0 then
    return { write = false, reason = M.REASON_TIMEOUT }
  end

  return { write = true, reason = M.REASON_PASS }
end

function M.summarize_mutation_result(file, json)
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
  summary.write_decision = M.manifest_write_decision({}, summary)
  return summary
end

return M
