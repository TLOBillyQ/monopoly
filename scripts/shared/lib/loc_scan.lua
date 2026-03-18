local common = require("shared.lib.common")
local json_reader = require("shared.lib.json_reader")
local json_writer = require("shared.lib.json_writer")
local loc_counter = require("shared.lib.loc_counter")

local loc_scan = {}

local _blob_stats_cache = {}
local _engine_binary_cache = {
  resolved = false,
  path = nil,
  err = nil,
}

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@scripts/shared/lib/loc_scan.lua"
  local normalized = common.normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "scripts/shared/lib"
end

local bootstrap = dofile(_module_dir() .. "/../bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
local REPO_ROOT = env.repo_root
local LOC_ENGINE_ROOT = common.join_path(REPO_ROOT, "tools/loc_engine")
local LOC_TOOLCHAIN_ROOT = common.join_path(REPO_ROOT, ".loc/toolchain/current")

local function _text(zh, en)
  return common.bilingual(zh, en)
end

local function _trim(text)
  local source = tostring(text or "")
  source = source:gsub("^%s+", "")
  source = source:gsub("%s+$", "")
  return source
end

local function _split_lines(text)
  local lines = {}
  for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

local function _binary_name()
  if common.is_windows() then
    return "monopoly-loc.exe"
  end
  return "monopoly-loc"
end

local function _binary_path()
  return common.join_path(LOC_TOOLCHAIN_ROOT, _binary_name())
end

local function _copy_array(values)
  local copied = {}
  for index, value in ipairs(values or {}) do
    copied[index] = value
  end
  return copied
end

local function _run_command(command, options, env)
  if env ~= nil and type(env.run_command) == "function" then
    return env.run_command(command, options)
  end
  return common.run_command(command, options)
end

local function _read_file_bytes_fast(path)
  local file, open_err = io.open(path, "rb")
  if file == nil then
    return nil, open_err
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function _count_file_bytes(path)
  local content, err = _read_file_bytes_fast(path)
  if content == nil then
    return nil, err
  end
  return loc_counter.count_effective_lines(content)
end

local function _counted_bucket(bucket)
  return bucket == "src" or bucket == "tests"
end

local function _classify_bucket(path)
  local normalized = common.normalize_path(path)
  if normalized:match("%.lua$") == nil then
    return nil
  end
  if normalized:match("^src/") ~= nil then
    return "src"
  end
  if normalized:match("^tests/") ~= nil then
    return "tests"
  end
  return nil
end

local function _is_zero_object_id(object_id)
  return tostring(object_id or ""):match("^0+$") ~= nil
end

local function _collect_git_lua_files(project_root, relative_root, env)
  local git_root = common.normalize_path(project_root)
  local result = _run_command({ "git", "-C", git_root, "ls-files", "--", relative_root }, nil, env)
  if result.ok ~= true then
    return nil
  end

  local files = {}
  for _, line in ipairs(_split_lines(result.output)) do
    local relative_path = common.normalize_path(_trim(line))
    if relative_path ~= "" and relative_path:match("%.lua$") ~= nil then
      files[#files + 1] = common.join_path(project_root, relative_path)
    end
  end
  table.sort(files)
  return files
end

local function _collect_directory_lua_files(project_root, directory_path, env)
  local absolute_root = common.join_path(project_root, directory_path)
  local git_files = nil
  if common.command_exists("git") then
    git_files = _collect_git_lua_files(project_root, directory_path, env)
    if git_files ~= nil then
      return git_files
    end
  end

  if common.path_exists(absolute_root) ~= true then
    return {}
  end
  return common.collect_lua_files(absolute_root)
end

local function _count_directory_lua_lines(project_root, directory_path, env)
  local files, files_err = _collect_directory_lua_files(project_root, directory_path, env)
  if files == nil then
    return nil, files_err
  end

  local total = 0
  for _, path in ipairs(files) do
    local count, count_err = _count_file_bytes(path)
    if count == nil then
      return nil, _text(
        "统计文件失败: " .. tostring(path) .. " | " .. tostring(count_err),
        "Failed to count file: " .. tostring(path) .. " | " .. tostring(count_err)
      )
    end
    total = total + count
  end
  return total
end

local function _count_file_entry(project_root, file_entry)
  local absolute_path = common.join_path(project_root, file_entry.path)
  local content, open_err = _read_file_bytes_fast(absolute_path)
  if content == nil then
    if common.path_exists(absolute_path) ~= true then
      return 0
    end
    return nil, _text(
      "统计文件失败: " .. tostring(absolute_path) .. " | " .. tostring(open_err),
      "Failed to count file: " .. tostring(absolute_path) .. " | " .. tostring(open_err)
    )
  end

  local count = 0
  if absolute_path:match("%.lua$") ~= nil then
    count = loc_counter.count_effective_lines(content)
  end
  return count + (file_entry.extra_lines_if_exists or 0)
end

local function _write_json_file(path, payload)
  local ok, err = common.write_file(path, json_writer.encode(payload))
  if not ok then
    return nil, err
  end
  return true
end

local function _parse_json_response(text)
  local ok, decoded = pcall(json_reader.decode, text)
  if not ok then
    return nil
  end
  if type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

local function _run_go_engine(command_name, payload, env)
  local binary_path, build_err = loc_scan.ensure_binary(env)
  if binary_path == nil then
    return nil, build_err
  end

  local request_path = common.make_temp_path("loc_engine_request", ".json")
  local ok, write_err = _write_json_file(request_path, payload)
  if not ok then
    return nil, write_err
  end

  local result = _run_command({
    binary_path,
    command_name,
    "--request-json",
    request_path,
  }, {
    cwd = REPO_ROOT,
  }, env)
  common.remove_path(request_path)
  if result.ok ~= true then
    return nil, result.output
  end

  return _parse_json_response(result.output), nil
end

local function _git_result_or_err(args, git_root, env)
  local command = { "git", "-C", git_root }
  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end

  local result = _run_command(command, nil, env)
  if result.ok == true then
    return result.output, nil
  end
  local output = _trim(result.output)
  if output == "" then
    output = _text("git 命令执行失败", "git command failed")
  end
  return nil, output
end

local function _get_commits(git_root, since, env)
  local output, err = _git_result_or_err({
    "log",
    "--since=" .. tostring(since or "3 days ago"),
    "--format=%H|%ci|%s",
    "--reverse",
  }, git_root, env)
  if output == nil then
    return nil, err
  end

  local commits = {}
  for _, line in ipairs(_split_lines(output)) do
    local normalized = _trim(line)
    if normalized ~= "" and normalized:find("|", 1, true) ~= nil then
      local full_hash, date_text, message = normalized:match("^([^|]+)|([^|]+)|(.+)$")
      if full_hash ~= nil then
        commits[#commits + 1] = {
          hash = full_hash:sub(1, 8),
          full_hash = full_hash,
          date = date_text,
          message = message,
        }
      end
    end
  end
  return commits
end

local function _list_commit_lua_entries(commit_hash, git_root, env)
  local output, err = _git_result_or_err({ "ls-tree", "-r", commit_hash, "src", "tests" }, git_root, env)
  if output == nil then
    return nil, err
  end

  local entries = {}
  for _, line in ipairs(_split_lines(output)) do
    local object_type, object_id, file_path = line:match("^%d+%s+(%S+)%s+([0-9a-f]+)%s+(.+)$")
    local bucket = _classify_bucket(file_path)
    if object_type == "blob" and bucket ~= nil then
      entries[#entries + 1] = {
        bucket = bucket,
        object_id = object_id,
        file_path = file_path,
      }
    end
  end
  return entries
end

local function _parse_cat_file_batch(output, object_ids)
  local stats_by_id = {}
  local cursor = 1

  for _, object_id in ipairs(object_ids or {}) do
    local header_end = output:find("\n", cursor, true)
    if header_end == nil then
      return nil, "git cat-file batch output ended unexpectedly"
    end

    local header = output:sub(cursor, header_end - 1)
    local actual_id, object_type, size_text = header:match("^([0-9a-f]+)%s+(%S+)%s+(%d+)$")
    if actual_id == nil then
      return nil, "unexpected git cat-file header: " .. tostring(header)
    end
    if actual_id ~= object_id then
      return nil, "git cat-file batch order mismatch: expected " .. tostring(object_id) .. " got " .. tostring(actual_id)
    end
    if object_type ~= "blob" then
      return nil, "git cat-file returned non-blob object: " .. tostring(actual_id)
    end

    local size = common.to_integer(size_text)
    if size == nil then
      return nil, "invalid git cat-file blob size: " .. tostring(size_text)
    end

    local content_start = header_end + 1
    local content_end = content_start + size - 1
    local content = ""
    if size > 0 then
      content = output:sub(content_start, content_end)
    end

    stats_by_id[object_id] = {
      line_count = loc_counter.count_effective_lines(content),
      has_content = size > 0,
    }
    cursor = content_end + 2
  end

  return stats_by_id
end

local function _populate_blob_stats_cache(object_ids, git_root, env)
  if #object_ids == 0 then
    return true
  end

  local ids_path = common.make_temp_path("git_blob_batch", ".txt")
  local ok, err = common.write_file(ids_path, table.concat(object_ids, "\n") .. "\n")
  if not ok then
    return nil, err
  end

  local result = _run_command({ "git", "-C", git_root, "cat-file", "--batch" }, {
    stdin_path = ids_path,
  }, env)
  common.remove_path(ids_path)
  if result.ok ~= true then
    local output = _trim(result.output)
    if output == "" then
      output = _text("git cat-file --batch 执行失败", "git cat-file --batch failed")
    end
    return nil, output
  end

  local stats_by_id, parse_err = _parse_cat_file_batch(result.output, object_ids)
  if stats_by_id == nil then
    return nil, parse_err
  end

  for object_id, stats in pairs(stats_by_id) do
    _blob_stats_cache[object_id] = stats
  end
  return true
end

local function _populate_blob_stats_cache_slow(entries, commit_hash, git_root, env)
  for _, entry in ipairs(entries or {}) do
    if _blob_stats_cache[entry.object_id] == nil then
      local output, _ = _git_result_or_err({ "show", commit_hash .. ":" .. entry.file_path }, git_root, env)
      if output ~= nil then
        _blob_stats_cache[entry.object_id] = {
          line_count = loc_counter.count_effective_lines(output),
          has_content = output ~= "",
        }
      else
        _blob_stats_cache[entry.object_id] = {
          line_count = 0,
          has_content = false,
        }
      end
    end
  end
end

local function _new_history_state()
  return {
    path_to_entry = {},
    src_loc = 0,
    src_files = 0,
    tests_loc = 0,
    tests_files = 0,
  }
end

local function _remove_state_entry(state, path)
  local entry = state.path_to_entry[path]
  if entry == nil then
    return
  end

  local stats = _blob_stats_cache[entry.object_id]
  if stats ~= nil and stats.has_content then
    if entry.bucket == "src" then
      state.src_loc = state.src_loc - (stats.line_count or 0)
      state.src_files = state.src_files - 1
    elseif entry.bucket == "tests" then
      state.tests_loc = state.tests_loc - (stats.line_count or 0)
      state.tests_files = state.tests_files - 1
    end
  end
  state.path_to_entry[path] = nil
end

local function _add_state_entry(state, path, bucket, object_id)
  local stats = _blob_stats_cache[object_id]
  state.path_to_entry[path] = {
    bucket = bucket,
    object_id = object_id,
  }
  if stats ~= nil and stats.has_content then
    if bucket == "src" then
      state.src_loc = state.src_loc + (stats.line_count or 0)
      state.src_files = state.src_files + 1
    elseif bucket == "tests" then
      state.tests_loc = state.tests_loc + (stats.line_count or 0)
      state.tests_files = state.tests_files + 1
    end
  end
end

local function _build_state_from_entries(entries, commit_hash, git_root, env)
  local missing_ids = {}
  local seen_ids = {}
  for _, entry in ipairs(entries or {}) do
    if _blob_stats_cache[entry.object_id] == nil and not seen_ids[entry.object_id] then
      seen_ids[entry.object_id] = true
      missing_ids[#missing_ids + 1] = entry.object_id
    end
  end

  if #missing_ids > 0 then
    local batch_ok = _populate_blob_stats_cache(missing_ids, git_root, env)
    if not batch_ok then
      _populate_blob_stats_cache_slow(entries, commit_hash, git_root, env)
    end
  end

  local state = _new_history_state()
  for _, entry in ipairs(entries or {}) do
    _add_state_entry(state, entry.file_path, entry.bucket, entry.object_id)
  end
  return state
end

local function _make_history_row(commit, state)
  return {
    hash = commit.hash,
    date = commit.date,
    message = commit.message,
    src_loc = state.src_loc,
    src_files = state.src_files,
    tests_loc = state.tests_loc,
    tests_files = state.tests_files,
    total_loc = state.src_loc + state.tests_loc,
    total_files = state.src_files + state.tests_files,
  }
end

local function _list_diff_entries(previous_hash, current_hash, git_root, env)
  local output, err = _git_result_or_err({
    "diff-tree",
    "-r",
    "--raw",
    "--no-commit-id",
    "-M",
    previous_hash,
    current_hash,
    "--",
    "src",
    "tests",
  }, git_root, env)
  if output == nil then
    return nil, err
  end

  local entries = {}
  for _, line in ipairs(_split_lines(output)) do
    local normalized = _trim(line)
    if normalized ~= "" then
      local old_object_id, new_object_id, status, path_data = normalized:match(
        "^:%d+%s+%d+%s+([0-9a-f]+)%s+([0-9a-f]+)%s+([A-Z][0-9]*)\t(.+)$"
      )
      if old_object_id == nil then
        return nil, "unexpected git diff-tree raw line: " .. tostring(normalized)
      end

      local old_path = nil
      local new_path = nil
      local status_code = status:sub(1, 1)
      if status_code == "R" or status_code == "C" then
        old_path, new_path = path_data:match("^(.-)\t(.+)$")
      else
        old_path = path_data
        new_path = path_data
      end

      entries[#entries + 1] = {
        old_object_id = old_object_id,
        new_object_id = new_object_id,
        old_path = common.normalize_path(old_path),
        new_path = common.normalize_path(new_path),
        status_code = status_code,
      }
    end
  end

  return entries
end

local function _apply_diff_to_state(state, diff_entries, git_root, env)
  local pending_additions = {}
  local missing_ids = {}
  local seen_ids = {}

  for _, diff_entry in ipairs(diff_entries or {}) do
    if diff_entry.old_path ~= nil then
      _remove_state_entry(state, diff_entry.old_path)
    end

    local bucket = _classify_bucket(diff_entry.new_path)
    if _counted_bucket(bucket) and not _is_zero_object_id(diff_entry.new_object_id) then
      pending_additions[#pending_additions + 1] = {
        path = diff_entry.new_path,
        bucket = bucket,
        object_id = diff_entry.new_object_id,
      }
      if _blob_stats_cache[diff_entry.new_object_id] == nil and not seen_ids[diff_entry.new_object_id] then
        seen_ids[diff_entry.new_object_id] = true
        missing_ids[#missing_ids + 1] = diff_entry.new_object_id
      end
    end
  end

  if #missing_ids > 0 then
    local ok, err = _populate_blob_stats_cache(missing_ids, git_root, env)
    if not ok then
      return nil, err
    end
  end

  for _, addition in ipairs(pending_additions) do
    _add_state_entry(state, addition.path, addition.bucket, addition.object_id)
  end

  return state
end

local function _count_worktree_lua(request, env)
  local project_root = common.normalize_path(request.project_root or REPO_ROOT)
  local breakdown = {}

  for _, directory in ipairs(request.directories or {}) do
    local effective_line_count, err = _count_directory_lua_lines(project_root, directory.path, env)
    if effective_line_count == nil then
      return nil, err
    end
    breakdown[#breakdown + 1] = {
      name = directory.name,
      kind = "Directory",
      effective_lua_line_count = effective_line_count,
    }
  end

  for _, file_entry in ipairs(request.files or {}) do
    local effective_line_count, err = _count_file_entry(project_root, file_entry)
    if effective_line_count == nil then
      return nil, err
    end
    breakdown[#breakdown + 1] = {
      name = file_entry.name,
      kind = "File",
      effective_lua_line_count = effective_line_count,
    }
  end

  local total_effective_line_count = 0
  for _, entry in ipairs(breakdown) do
    total_effective_line_count = total_effective_line_count + (entry.effective_lua_line_count or 0)
  end

  return {
    breakdown = breakdown,
    total_effective_line_count = total_effective_line_count,
  }
end

local function _count_history_lua(request, env)
  local git_root = common.normalize_path(request.git_root or request.project_root or REPO_ROOT)
  local commits, commits_err = _get_commits(git_root, request.since, env)
  if commits == nil then
    return nil, commits_err
  end

  local rows = {}
  if #commits == 0 then
    return { rows = rows }
  end

  local baseline_entries, baseline_err = _list_commit_lua_entries(commits[1].full_hash, git_root, env)
  if baseline_entries == nil then
    return nil, baseline_err
  end
  local state = _build_state_from_entries(baseline_entries, commits[1].full_hash, git_root, env)
  rows[#rows + 1] = _make_history_row(commits[1], state)

  for index = 2, #commits do
    local previous_commit = commits[index - 1]
    local current_commit = commits[index]
    local diff_entries = nil
    local diff_err = nil

    diff_entries, diff_err = _list_diff_entries(previous_commit.full_hash, current_commit.full_hash, git_root, env)
    if diff_entries == nil then
      local rebuild_entries, rebuild_err = _list_commit_lua_entries(current_commit.full_hash, git_root, env)
      if rebuild_entries == nil then
        return nil, rebuild_err or diff_err
      end
      state = _build_state_from_entries(rebuild_entries, current_commit.full_hash, git_root, env)
    else
      local next_state, apply_err = _apply_diff_to_state(state, diff_entries, git_root, env)
      if next_state == nil then
        local rebuild_entries, rebuild_err = _list_commit_lua_entries(current_commit.full_hash, git_root, env)
        if rebuild_entries == nil then
          return nil, rebuild_err or apply_err
        end
        state = _build_state_from_entries(rebuild_entries, current_commit.full_hash, git_root, env)
      else
        state = next_state
      end
    end

    rows[#rows + 1] = _make_history_row(current_commit, state)
  end

  return { rows = rows }
end

function loc_scan.ensure_binary(env)
  env = env or {}
  local binary_path = _binary_path()
  if type(env.ensure_binary) == "function" then
    return env.ensure_binary(binary_path)
  end
  if _engine_binary_cache.resolved then
    return _engine_binary_cache.path, _engine_binary_cache.err
  end
  if common.path_exists(binary_path) == true then
    _engine_binary_cache.resolved = true
    _engine_binary_cache.path = binary_path
    return binary_path, nil
  end
  if common.command_exists("go") ~= true then
    _engine_binary_cache.resolved = true
    _engine_binary_cache.err = _text("未找到 go 命令", "go command not found")
    return nil, _engine_binary_cache.err
  end

  local ok, err = common.ensure_parent_dir(binary_path)
  if not ok then
    _engine_binary_cache.resolved = true
    _engine_binary_cache.err = err
    return nil, err
  end

  local result = _run_command({ "go", "build", "-o", binary_path, "./cmd/monopoly-loc" }, {
    cwd = LOC_ENGINE_ROOT,
  }, env)
  if result.ok ~= true then
    _engine_binary_cache.resolved = true
    _engine_binary_cache.err = _trim(result.output)
    return nil, _engine_binary_cache.err
  end

  _engine_binary_cache.resolved = true
  _engine_binary_cache.path = binary_path
  _engine_binary_cache.err = nil
  return binary_path, nil
end

function loc_scan.count_worktree(request, env)
  env = env or request.env or {}
  local normalized_request = {
    project_root = common.normalize_path(request.project_root or REPO_ROOT),
    directories = _copy_array(request.directories),
    files = _copy_array(request.files),
  }

  local go_result, go_err = _run_go_engine("worktree", normalized_request, env)
  if go_result == nil then
    return nil, go_err
  end
  return go_result
end

function loc_scan.count_history(request, env)
  env = env or request.env or {}
  local normalized_request = {
    git_root = common.normalize_path(request.git_root or request.project_root or REPO_ROOT),
    since = request.since or "3 days ago",
  }

  local go_result, go_err = _run_go_engine("history", normalized_request, env)
  if go_result == nil then
    return nil, go_err
  end
  return go_result
end

function loc_scan.reset_caches()
  _blob_stats_cache = {}
  _engine_binary_cache = {
    resolved = false,
    path = nil,
    err = nil,
  }
end

return loc_scan
