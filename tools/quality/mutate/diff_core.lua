local util = require("mutate4lua.util")
local manifest_policy = require("quality.mutation_manifest_policy")

local M = {}

local _SRC_LUA_PATTERN = "^src/.+%.lua$"
local _DEFAULT_BASE = "main"

local function _split_lines(text)
  local lines = {}
  for line in (text or ""):gmatch("([^\n]+)") do
    lines[#lines + 1] = line
  end
  return lines
end

function M.parse_name_status(text)
  local entries = {}
  for _, line in ipairs(_split_lines(text)) do
    if line ~= "" then
      local status_letter = line:sub(1, 1)
      if status_letter == "R" or status_letter == "C" then
        local _, dest = line:match("\t([^\t]+)\t([^\t]+)$")
        if dest then
          entries[#entries + 1] = { status = status_letter, path = dest }
        end
      else
        local path = line:match("\t(.+)$")
        if path then
          entries[#entries + 1] = { status = status_letter, path = path }
        end
      end
    end
  end
  return entries
end

function M.filter_changed_src(entries)
  local kept = {}
  for _, entry in ipairs(entries or {}) do
    if entry.status ~= "D" and entry.path:find(_SRC_LUA_PATTERN) then
      kept[#kept + 1] = entry
    end
  end
  return kept
end

local function _format_warning(file, json)
  return string.format(
    "[verify-mutation-diff] %s: survived=%d killed=%d total=%d score=%.1f\n",
    file,
    json.survived or 0,
    json.killed or 0,
    json.total_sites or 0,
    tonumber(json.score) or 0
  )
end

function M.run(opts, runtime)
  opts = opts or {}
  local base = opts.base or _DEFAULT_BASE
  local diff_text, diff_err = runtime.diff_name_status(base)
  if diff_text == nil then
    runtime.err_write(string.format(
      "[verify-mutation-diff] git diff failed: %s\n", tostring(diff_err)
    ))
    return { exit_code = 1, processed = {} }
  end

  local changed = M.filter_changed_src(M.parse_name_status(diff_text))
  if #changed == 0 then
    runtime.err_write("[verify-mutation-diff] 无 src 变更，跳过\n")
    return { exit_code = 0, processed = {} }
  end

  local processed = {}
  local survived_count = 0
  for _, entry in ipairs(changed) do
    local file = entry.path
    local result = runtime.mutate_file(file)
    if result.exit_code == 1 then
      runtime.err_write(string.format(
        "[verify-mutation-diff] baseline failure for %s — aborting\n", file
      ))
      if result.stderr and result.stderr ~= "" then
        runtime.err_write(result.stderr)
        if result.stderr:sub(-1) ~= "\n" then runtime.err_write("\n") end
      end
      return { exit_code = 1, processed = processed }
    end

    local summary = manifest_policy.summarize_mutation_result(file, result.json or {})
    processed[#processed + 1] = {
      file = summary.file,
      total_sites = summary.total_sites,
      killed = summary.killed,
      survived = summary.survived,
      timeout = summary.timeout,
      score = summary.score,
    }
    if summary.has_survived then
      survived_count = survived_count + 1
      runtime.err_write(_format_warning(file, summary))
    end
  end

  if opts.json then
    runtime.out_write(util.encode_json({ files = processed }))
    runtime.out_write("\n")
  end

  if survived_count > 0 then
    runtime.err_write(string.format(
      "[verify-mutation-diff] %d file(s) had survived mutants — review above\n",
      survived_count
    ))
  end

  return { exit_code = 0, processed = processed }
end

return M
