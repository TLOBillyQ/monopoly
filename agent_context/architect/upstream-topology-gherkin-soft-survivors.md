# upstream_topology.feature soft Gherkin 变异 — example-value survivor【全 benign，关闭】

## 当前测量：HEAD `0697452f`（final-branch-parity 收敛后）

```
./gherkin-mutator --feature features/swarmforge/upstream_topology.feature \
  --work-dir ./tmp/aps-soft-topology \
  --runner-worker "lua tools/acceptance/runner_worker.lua" --level soft --json
→ Total=65 Killed=42 Survived=23 Errors=0
```

裸 soft（未传 `--implementation-hash`）退化为全量 example-cell 变异，给出完整 survivor 画像。

## survivor 清单（场景 + 字段，判据读 `tools/acceptance/steps/swarmforge_parity.lua` + `tools/swarmforge/lib/upstream_parity.lua`）

| 字段 | 场景 | 数量 | 判定 |
|------|------|------|------|
| 后端 | 001 / 002 | 6 | dead arrange：存入 `role_config.backend` 透传 `plan_role`，但 Then 只断言 会话/提示文件/启动目录/allows_custom_role，皆不依赖 backend |
| 工作树 | 002 | 3 | 场景内 dead：worktree 的后果（startup_dir/session）只在 001/004 断言，002 仅断言 提示文件 + 角色集合不限制 |
| 本地运行路径 | 003 | 5 | 纯 arrange：`路径写入 git ignore` handler 只 append 到 `local_paths` 重算 plan，从不断言 `gitignore_paths`；即便断言也是 `gitignore_paths = opts.local_paths` 透传 tautology |
| 角色 | 004 | 3 | dead input：`plan_worktree(config.worktree)` 只吃 worktree，忽略 role；断言 创建行为/启动目录 均由 worktree 派生 |
| 消息文件 | 005 | 2 | pass-through tautology：`plan_notification.message_file = opts.message_file` 透传，断言 `==example["消息文件"]`，expected 与 actual 同列同行同步变 |
| 目标会话 | 005 | 2 | pass-through tautology：`target_session = entry.session`（arrange 存 `example["目标会话"]`），断言回 `example["目标会话"]`，同步变 |
| 项目路径 | 006 | 2 | dead input：step 340 的 `plan_notification` 硬编码 `tmux_socket=".swarmforge/tmux-socket"`，从不传 project_path；目标地址 = session:win.pane 与 project_path 无关 |

## 结论：全部 benign，无可分离 assert-only 缺口

23 个 survivor 结构上对 example-value 变异不可杀，两类成因：
1. **dead/never-asserted arrange 输入**（后端 ×6、工作树 ×3、路径 ×5、角色 ×3、项目路径 ×2 = 19）——该列在其场景不驱动任何断言；
2. **pass-through tautology**（消息文件 ×2、目标会话 ×2 = 4）——断言目标是同列输入的透传，expected 与 actual 同步迁移。

真正承载上游 README 行为契约的列**全部被杀**：001 会话（派生自 `角色` ≠ 被断言列 → killable，killed）、004 创建行为/启动目录（派生自 worktree，killed）、006 目标地址（killed）。

按 [[project_contract_features_gherkin_mutation_resistant]]：swarmforge/* 是契约/parity feature，非落 world state 的 gameplay feature，example-value 残留为 benign，不是覆盖债。不补 change-detector、不写 false-closure spec、不路由 specifier。

若日后要消减纯展示性 survivor（后端/角色/项目路径 dead input），手段是 [[project_gherkin_validation_column]] 的硬编码验证列 + assert-only handler；当前对契约 feature 属 gold-plating，不做。

后续 `upstream_topology.feature` / `swarmforge_parity.lua` / `upstream_parity.lua` 有 delta 时复跑 soft 复核。

参考：[[project_gherkin_survivor_measurement_staleness]]、[[reference_mutate_no_specs_cover_attribution]]。
