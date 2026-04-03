# update_api.lua 重构：git 对比替换 EggyAPI copy 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构 `tools/ops/update_api.lua`，删除对 `EggyAPI copy.lua` 的依赖，改为通过 `git show HEAD` 获取旧版本，当 API 无变化时直接跳过所有写操作。

**Architecture:** 在 `main()` 中提前调用 `_read_git_head()` 获取旧版文本，用 `_parse_symbols()` 对比符号；若无变化则 exit 0；有变化时按原流程生成文档和 changelog。移除 `DEFAULT_OLD`、`--old` 参数、`_delete_old_api()` 函数。

**Tech Stack:** Lua 5.5，`common.run_command`（已有），git CLI

---

## 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `tools/ops/update_api.lua` | 修改 | 核心重构 |
| `tests/suites/architecture/script_tools_contract.lua` | 修改 | 重写 update_api 相关测试 |

---

## Task 1：重写集成测试（先失败）

**Files:**
- Modify: `tests/suites/architecture/script_tools_contract.lua:571-632`

- [ ] **Step 1：用新的 git-aware 辅助函数替换 `_run_update_api_with_paths`**

找到并替换（约 571-579 行）：

```lua
local function _run_update_api_with_paths(old_path, new_path, doc_dir, changelog_path)
  return _run_lua({
    "tools/ops/update_api.lua",
    "--old", old_path,
    "--new", new_path,
    "--doc-dir", doc_dir,
    "--changelog", changelog_path,
  })
end
```

替换为：

```lua
local function _run_update_api_git(new_path, doc_dir, changelog_path)
  return _run_lua({
    "tools/ops/update_api.lua",
    "--new", new_path,
    "--doc-dir", doc_dir,
    "--changelog", changelog_path,
    "--skip-meta",
  })
end
```

- [ ] **Step 2：重写 `_test_update_api_deletes_old_baseline_when_only_diff_fails`**

找到并替换（约 581-604 行）：

```lua
local function _test_update_api_updates_docs_and_changelog_when_api_changes()
  _with_ascii_tmp("update_api_api_changes", function(tmp_root)
    local fixture_root = common.join_path(tmp_root, "update_api_api_changes")
    local new_path = common.join_path(fixture_root, "EggyAPI.lua")
    local doc_dir = common.join_path(fixture_root, "docs/eggy/api")
    local changelog_path = common.join_path(doc_dir, "changelog.md")

    _init_git_repo(fixture_root)
    _write_update_api_fixture(new_path, "legacy_call")
    _commit_all(fixture_root, "init")
    _write_update_api_fixture(new_path, "current_call")

    local result = _run_update_api_git(new_path, doc_dir, changelog_path)

    assert(result.ok == false, "update_api should exit non-zero when API diff exists")
    assert(common.path_exists(common.join_path(doc_dir, "04_global_api.md")) == true,
      "update_api should generate split docs")
    assert(common.path_exists(changelog_path) == true,
      "update_api should write changelog")
    _assert_contains(result.output, "新增 / Added: 1",
      "update_api should report the added API")
    _assert_contains(result.output, "删除 / Removed: 1",
      "update_api should report the removed API")
    _assert_contains(result.output, "缺失项 / Missing: 0",
      "update_api should keep doc entries aligned with source entries")
    _assert_contains(result.output, "多余项 / Extra: 0",
      "update_api should keep doc entries aligned with source entries")
  end)
end
```

- [ ] **Step 3：重写 `_test_update_api_keeps_old_baseline_when_check_fails`**

找到并替换（约 606-632 行）：

```lua
local function _test_update_api_reports_extra_doc_entries_when_check_fails()
  _with_ascii_tmp("update_api_extra_doc", function(tmp_root)
    local fixture_root = common.join_path(tmp_root, "update_api_extra_doc")
    local new_path = common.join_path(fixture_root, "EggyAPI.lua")
    local doc_dir = common.join_path(fixture_root, "docs/eggy/api")
    local changelog_path = common.join_path(doc_dir, "changelog.md")
    local extra_doc_path = common.join_path(doc_dir, "zz_extra.md")

    _init_git_repo(fixture_root)
    _write_update_api_fixture(new_path, "old_call")
    _commit_all(fixture_root, "init")
    _write_update_api_fixture(new_path, "new_call")
    _write_fixture_file(extra_doc_path, table.concat({
      "# extra",
      "",
      "GhostAPI|ghost_call",
      "",
    }, "\n"))

    local result = _run_update_api_git(new_path, doc_dir, changelog_path)

    assert(result.ok == false,
      "update_api should exit non-zero when doc check finds extra entries")
    _assert_contains(result.output, "多余项 / Extra: 1",
      "update_api should surface the extra doc entry count")
    _assert_contains(result.output, "多余示例 / Extra sample: [GhostAPI|ghost_call]",
      "update_api should surface the offending extra doc entry")
  end)
end
```

- [ ] **Step 4：添加 no-op 测试**

在 `_test_update_api_reports_extra_doc_entries_when_check_fails` 之后插入：

```lua
local function _test_update_api_skips_all_writes_when_api_unchanged()
  _with_ascii_tmp("update_api_no_change", function(tmp_root)
    local fixture_root = common.join_path(tmp_root, "update_api_no_change")
    local new_path = common.join_path(fixture_root, "EggyAPI.lua")
    local doc_dir = common.join_path(fixture_root, "docs/eggy/api")
    local changelog_path = common.join_path(doc_dir, "changelog.md")

    _init_git_repo(fixture_root)
    _write_update_api_fixture(new_path, "stable_call")
    _commit_all(fixture_root, "init")
    -- 不覆盖文件，内容与 git HEAD 相同

    local result = _run_update_api_git(new_path, doc_dir, changelog_path)

    assert(result.ok == true, "update_api should exit 0 when API unchanged")
    assert(common.path_exists(changelog_path) == false,
      "update_api should not write changelog when API unchanged")
    assert(common.path_exists(common.join_path(doc_dir, "04_global_api.md")) == false,
      "update_api should not generate docs when API unchanged")
  end)
end
```

- [ ] **Step 5：更新测试注册表（约 1218-1220 行）**

找到：
```lua
  { name = "update_api_writes_changelog_into_docs_eggy_api_dir", run = _test_update_api_writes_changelog_into_docs_eggy_api_dir },
  { name = "update_api_deletes_old_baseline_when_only_diff_fails", run = _test_update_api_deletes_old_baseline_when_only_diff_fails },
  { name = "update_api_keeps_old_baseline_when_check_fails", run = _test_update_api_keeps_old_baseline_when_check_fails },
```

替换为：
```lua
  { name = "update_api_writes_changelog_into_docs_eggy_api_dir", run = _test_update_api_writes_changelog_into_docs_eggy_api_dir },
  { name = "update_api_updates_docs_and_changelog_when_api_changes", run = _test_update_api_updates_docs_and_changelog_when_api_changes },
  { name = "update_api_reports_extra_doc_entries_when_check_fails", run = _test_update_api_reports_extra_doc_entries_when_check_fails },
  { name = "update_api_skips_all_writes_when_api_unchanged", run = _test_update_api_skips_all_writes_when_api_unchanged },
```

- [ ] **Step 6：运行测试，确认新测试失败、旧测试已移除**

```bash
lua tests/contract.lua 2>&1 | grep -E "update_api|PASS|FAIL"
```

预期：三个 update_api 测试失败（`_read_git_head` 不存在 / `--old` 参数缺失），静态文本测试通过。

- [ ] **Step 7：提交测试变更**

```bash
git add tests/suites/architecture/script_tools_contract.lua
git commit -m "test: rewrite update_api contract tests for git-aware workflow"
```

---

## Task 2：实现 `_read_git_head()` 并重构 `main()`

**Files:**
- Modify: `tools/ops/update_api.lua`

- [ ] **Step 1：删除 `DEFAULT_OLD` 常量（约第 27 行）**

找到：
```lua
local DEFAULT_OLD = common.join_path(env.repo_root, "EggyAPI copy.lua")
```

删除该行（直接删除，不替换）。

- [ ] **Step 2：删除 `_delete_old_api()` 函数（约第 630-642 行）**

找到并删除：
```lua
local function _delete_old_api(path)
  if not common.path_exists(path) then
    return
  end

  local ok = common.remove_path(path)
  if not ok then
    _fail(_text(
      "无法删除旧文件: " .. tostring(path),
      "Cannot delete old file: " .. tostring(path)
    ))
  end
end
```

- [ ] **Step 3：在 `_cleanup_deprecated_api` 之前添加 `_read_git_head()`**

在 `_cleanup_deprecated_api` 函数定义之前插入：

```lua
local function _read_git_head(new_path)
  local dir = new_path:match("^(.*)/[^/]+$") or "."

  local rev_result = common.run_command(
    { "git", "rev-parse", "--show-toplevel" },
    { cwd = dir }
  )
  if not rev_result.ok then
    _fail(_text(
      "无法找到 git 仓库，请在 git 仓库中运行此脚本",
      "Cannot find git repository; run this script inside a git repo"
    ))
  end

  local git_root = _trim(rev_result.output)
  local norm_root = git_root:gsub("\\", "/"):gsub("/$", "")
  local norm_new  = new_path:gsub("\\", "/")

  local rel_path
  if norm_new:sub(1, #norm_root + 1) == norm_root .. "/" then
    rel_path = norm_new:sub(#norm_root + 2)
  else
    rel_path = norm_new:match("([^/]+)$") or "EggyAPI.lua"
  end

  local show_result = common.run_command(
    { "git", "show", "HEAD:" .. rel_path },
    { cwd = git_root }
  )
  if not show_result.ok then
    return ""
  end

  return show_result.output
end
```

- [ ] **Step 4：从 `_parse_args()` 删除 `--old` 处理逻辑（约第 525-598 行）**

在 `_parse_args()` 内找到并删除 options 初始化中的 `old` 字段：
```lua
    old = DEFAULT_OLD,
```

找到并删除 `--old` 的解析分支：
```lua
    if token == "--old" then
      options.old = args[index + 1]
      index = index + 2
    elseif token == "--new" then
```
改为：
```lua
    if token == "--new" then
```

找到并删除 `old` 路径 resolve：
```lua
  options.old = common.resolve_path(common.current_dir(), options.old)
```

找到 `--help` 的 usage 字符串，将其中 `[--old PATH] ` 删除：
```lua
      "用法: lua tools/ops/update_api.lua [--new PATH] [--doc-dir PATH] [--changelog PATH] [--meta PATH] [--limit NUM] [--skip-generate] [--skip-check] [--skip-diff] [--skip-meta]",
      "Usage: lua tools/ops/update_api.lua [--new PATH] [--doc-dir PATH] [--changelog PATH] [--meta PATH] [--limit NUM] [--skip-generate] [--skip-check] [--skip-diff] [--skip-meta]"
```

- [ ] **Step 5：重写 `main()` 函数（约第 1269-1325 行）**

找到并整体替换 `main()` 函数：

```lua
local function main(args)
  local options = _parse_args(args or {})

  -- 提前用 git HEAD 检测 API 变化，无变化时跳过所有写操作
  local added, removed, changed_params, type_changed = {}, {}, {}, {}
  if not options.skip_diff then
    local old_text = _read_git_head(options.new)
    local old_symbols = _parse_symbols(old_text)
    local new_symbols = _parse_path(options.new)
    added, removed, changed_params, type_changed = _diff_symbols(old_symbols, new_symbols)
    if #added == 0 and #removed == 0 and #changed_params == 0 and #type_changed == 0 then
      print(_text("无 API 变化，跳过", "No API changes, skipping"))
      return 0
    end
  end

  _cleanup_deprecated_api(options.new)

  local text = ""
  if not options.skip_generate or not options.skip_check or not options.skip_meta then
    local read_text, read_err = common.read_file(options.new)
    if read_text == nil then
      _fail(read_err)
    end
    text = read_text
  end

  if not options.skip_generate then
    _generate_docs(text, options)
  end

  if not options.skip_meta then
    _generate_meta_file(text, options.meta)
  end

  local diff_failed = false
  if not options.skip_diff then
    local diff_lines = _format_diff_report(added, removed, changed_params, type_changed, options.limit)
    _print_lines(diff_lines)
    _append_changelog(options.changelog, _format_diff_report(added, removed, changed_params, type_changed, nil))
    diff_failed = #added > 0 or #removed > 0 or #changed_params > 0 or #type_changed > 0
  end

  local check_failed = false
  if not options.skip_check then
    local source_entries = _load_source_entries(text)
    local doc_entries = _load_doc_entries(options.doc_dir)
    local check_lines, missing, extra = _build_check_report(source_entries, doc_entries)
    if not options.skip_diff then
      print("")
    end
    _print_lines(check_lines)
    check_failed = #missing > 0 or #extra > 0
  end

  if diff_failed or check_failed then
    return 1
  end

  return 0
end
```

- [ ] **Step 6：运行集成测试，确认全部通过**

```bash
lua tests/contract.lua 2>&1 | grep -E "update_api|PASS|FAIL|ERROR"
```

预期：三个 update_api 测试全部 PASS。

- [ ] **Step 7：运行 guard 检查**

```bash
lua tests/guard.lua
```

预期：全部通过（无 `EggyAPI copy` 等禁用模式残留）。

- [ ] **Step 8：提交实现**

```bash
git add tools/ops/update_api.lua
git commit -m "refactor: replace EggyAPI copy with git show HEAD in update_api"
```

---

## Task 3：验收与收尾

- [ ] **Step 1：运行完整合约测试**

```bash
lua tests/contract.lua
```

预期：全部通过，无 update_api 相关失败。

- [ ] **Step 2：运行 arch 检查**

```bash
lua tools/quality/arch.lua check
```

预期：通过。

- [ ] **Step 3：手动冒烟测试（可选，有真实 EggyAPI.lua 时）**

```bash
# 无 API 变化（当前文件已提交）
lua tools/ops/update_api.lua
# 预期输出：无 API 变化，跳过 / No API changes, skipping
# 退出码：0
```

- [ ] **Step 4：确认 `EggyAPI copy.lua` 不存在于仓库**

```bash
ls EggyAPI\ copy.lua 2>/dev/null && echo "存在（需手动删除）" || echo "已不存在，正常"
```
