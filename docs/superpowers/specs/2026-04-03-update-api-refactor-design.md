# update_api.lua 重构设计：去掉 EggyAPI copy，改用 git 对比

日期：2026-04-03

## 背景

`tools/ops/update_api.lua` 目前依赖 `EggyAPI copy.lua` 作为旧版基线：用户需要手动保留一份拷贝，再将新版覆盖 `EggyAPI.lua`，才能让脚本检测变化。这个步骤繁琐且容易遗忘。

目标工作流：

1. 用户从 Eggy 平台拷贝最新 `EggyAPI.lua`，直接覆盖仓库中的同名文件
2. 在 **commit 之前** 运行 `lua tools/ops/update_api.lua`（无需任何参数）
3. 脚本自动用 `git show HEAD:EggyAPI.lua` 获取旧版，与磁盘新版对比
4. 无变化 → 直接退出，不修改任何文件
5. 有变化 → 更新文档和 changelog

## 方案选择

采用**方案 B（删除 `--old`，改为 git-aware 模式）**。

理由：`--old` 参数和 `EggyAPI copy.lua` 是临时方案，无需保留；该脚本是单一用途内部工具，不需要通用抽象。

## 核心变更

### 删除

- `DEFAULT_OLD = "EggyAPI copy.lua"` 常量
- `--old PATH` CLI 参数及其解析逻辑
- `_delete_old_api(path)` 函数

### 新增

**`_read_git_head(repo_root, rel_path)`**

```
输入：仓库根目录、相对路径（如 "EggyAPI.lua"）
逻辑：common.run_command({"git", "show", "HEAD:" .. rel_path}, {cwd = repo_root})
成功：返回文件文本字符串
失败：返回空字符串（视为首次导入，所有符号均为新增）
```

**无变化提前退出**

`_diff_symbols` 后，若 `added / removed / changed_params / type_changed` 均为空：
- 打印「无 API 变化，跳过」
- `os.exit(0)`，不写任何文件

### 保持不变

- `_cleanup_deprecated_api()`（有变化时仍对新文件原地执行）
- `--new`、`--doc-dir`、`--changelog`、`--meta`、`--limit`、`--skip-*` 参数
- 文档生成、meta 生成、changelog 追加的全部逻辑

## 执行流程（默认参数）

```
1. 读取 EggyAPI.lua（磁盘 → 新版文本）
2. git show HEAD:EggyAPI.lua → 内存字符串（旧版文本）
   └── 若 git 失败 → old = ""，继续
3. _diff_symbols(old_text, new_text)
   └── 若全部为空 → 打印"无 API 变化，跳过" → exit 0
4. _cleanup_deprecated_api(EggyAPI.lua)（原地清理新文件）
5. 生成 docs/eggy/api/ 下各 .md 文件
6. 生成 meta/luals_host.lua
7. 追加 docs/eggy/api/changelog.md
8. 打印 diff 摘要到 stdout
```

## 边界处理

| 情景 | 处理方式 |
|------|---------|
| `git` 命令不存在或非 git 仓库 | `_fail()`，输出明确错误提示 |
| `EggyAPI.lua` 从未被 commit（首次导入） | old = ""，所有符号视为新增，正常生成文档和 changelog |
| `EggyAPI.lua` 磁盘文件不存在 | `_fail()`，行为与现在一致 |
| 内容与 HEAD 完全一致 | 打印「无 API 变化，跳过」，exit 0，不写任何文件 |
| 同一天多次运行（有变化） | 追加新条目，行为与现在一致 |
