# 统一 Lua 命名为 snake_case 的多代理审计与改名计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本仓库存在 `.agent/PLANS.md`，本计划必须遵循其维护要求。

## 目的 / 全局视角


目标是在 `main.lua`、`src/`、`Config/`、`Data/` 范围内统一 Lua 标识符为 snake_case，解决大小写混用导致的调用失效。改动完成后，仓库内可被本项目控制的 Lua 标识符统一为 snake_case，避免调用方误用大小写导致运行时错误。可观察结果是：仓库中同一语义的命名不再出现多种大小写版本，`lua .agent/tests/regression.lua` 全量通过，并且 `main.lua` 能正常加载 `src/app/init.lua`。

## 进度


- [x] (2025-02-14 00:00Z) 初始化计划与范围确定
- [x] (2025-02-14 01:10Z) 目录分工与多代理审计完成
- [x] (2025-02-14 02:10Z) 统一命名映射、冲突清单与外部 API 例外清单完成
- [x] (2025-02-14 03:20Z) 一次性替换完成并通过回归测试
- [x] (2025-02-14 03:25Z) 结果与复盘完成

## 意外与发现


- 观察：自动改名后出现十六进制字面量语法错误（`0x_cfcfcf`）。
  证据：回归失败提示 `TileRenderer.lua:10: malformed number near '0x_cfcfcf'`。
- 观察：字符串转义被破坏导致 `UIChoice` 与回归脚本出现未闭合字符串。
  证据：回归失败提示 `UIChoice.lua:7: unfinished string near '\"")'`。

## 决策日志


- 决策：范围覆盖 `main.lua`、`src/`、`Config/`、`Data/`，不改 `Config/Generated`。
  理由：用户要求源码+配置；生成物由导表流程维护，避免手改漂移。
  日期/作者：2025-02-14 / Codex
- 决策：只统一 Lua 标识符，不改文件名与模块路径。
  理由：降低影响面，避免 require 路径连锁重命名。
  日期/作者：2025-02-14 / Codex
- 决策：一次性全量替换。
  理由：用户偏好一次性完成，便于一次回归确认。
  日期/作者：2025-02-14 / Codex
- 决策：常量也改为小写 snake_case。
  理由：用户明确要求统一为 snake_case。
  日期/作者：2025-02-14 / Codex
- 决策：对带 “AUTTO EXPORT BY EGGITOR PLUGIN, PLEASE DO NOT EDIT” 标记的 `Data/` 文件视为导出产物，不做改名处理。
  理由：生成物直接编辑会被导表覆盖且可能破坏编辑器约定。
  日期/作者：2025-02-14 / Codex
- 决策：外部 API 的字段名保持原始大小写（例如 `UIManager.Builder`、`UIManager.EVENT.CLICK`、`Enums.BuffState`、`EVENT.GAME_INIT`、`ALLROLES`）。
  理由：这些标识符由引擎或第三方库定义，改名会导致运行时找不到字段。
  日期/作者：2025-02-14 / Codex

## 结果与复盘


已完成批量改名并修复外部 API 字段、十六进制字面量和字符串转义问题；`main.lua`、`src/`、`Config/`（不含 `Config/Generated`）已统一为 snake_case，`Data/` 中带导出标记的文件保持不变。回归脚本通过，未发现新增运行时错误。

## 背景与导读


入口为 `main.lua`，直接加载 `src/app/init.lua`。核心逻辑集中在 `src/`，配置与数据在 `Config/` 和 `Data/`。当前仓库中混用 CamelCase、PascalCase、snake_case，且存在同一概念多种大小写写法，导致调用失效。本计划仅改 Lua 标识符，不动文件名与模块路径，且不改 `Config/Generated` 生成物。第三方代码在 `vendor/` 维持原样。带 “AUTTO EXPORT BY EGGITOR PLUGIN, PLEASE DO NOT EDIT” 标记的 `Data/` 文件按导出产物处理，保持不变。

关键目录与入口：
- `main.lua`
- `src/app/init.lua`
- `src/runtime/`
- `src/core/`
- `src/game/`
- `src/ui/`
- `Config/`（不含 `Config/Generated`）
- `Data/`

## 工作计划


先用多 agent 分目录并行审计，产出“非 snake_case 标识符清单 + 使用点 + 建议新名 + 冲突风险”。汇总后生成统一的“改名映射表”和“外部 API 例外清单”。随后一次性替换所有命名，并在必要处调整表字段访问、函数定义与调用点，确保行为不变。最后执行回归脚本验证。所有改名仅限本仓库可控代码与配置，确保 `Config/Generated` 与外部 API 保持原样。

## 具体步骤


1. 在仓库根目录启动多 agent 分工审计，每个 agent 负责固定目录：
   - Agent A：`src/app`、`src/runtime`、`src/core`、`main.lua`
   - Agent B：`src/game`
   - Agent C：`src/ui`
   - Agent D：`Config/`（跳过 `Config/Generated`）与 `Data/`
2. 每个 agent 使用 `rg` 搜索非 snake_case 标识符，并记录：
   - 标识符原名
   - 所在文件与行号
   - 可能的 snake_case 新名
   - 明显的外部 API / 第三方 API 引用点（标记为“例外候选”）
3. 汇总各 agent 结果，生成统一映射表与冲突清单：
   - 同名不同义
   - 不同名同义
   - 可能与现有 snake_case 冲突
4. 明确外部 API 例外清单（允许保留原大小写），并按 ReadingDiscipline 只在需要时查询 `.agent/docs/eggy/api/` 或 `.agent/docs/eggy/EggyAPI.lua` 的具体符号。
5. 按映射表一次性替换：
   - 函数定义、函数调用
   - 表字段键名（包括字面量与动态访问）
   - 常量名与其所有引用
6. 运行回归测试并修复遗漏的调用点。
7. 整理变更摘要与复盘。

## 验证与验收


- 运行 `lua .agent/tests/regression.lua`，预期所有测试通过并输出 `All regression checks passed (...)`。
- 重点场景：回合推进、落地结算、机会卡触发、黑市购买、UI 模型构建均不崩溃。
- 如发现外部 API 命名导致冲突，应回退该符号的改名并记入“例外清单”。

## 可重复性与恢复


- 改名严格基于映射表，可重复执行。
- 若发现大范围问题，优先回退到改名前状态再调整映射表重新执行。
- 不修改 `Config/Generated`，避免导表覆盖造成漂移。

## 产物与备注


- 产出改名映射表（示例）：
  - `GetPlayer -> get_player`
  - `SetTileLevel -> set_tile_level`
- 产出例外清单（示例）：
  - ExternalAPI: `GameAPI.get_role`
  - ExternalAPI: `Enums.CameraBindMode`

## 接口与依赖


- 公共接口变化：`src/` 与 `Config/`/`Data/` 中导出的 Lua 模块函数与表字段名将统一为 snake_case。模块路径不变。
- 依赖：`lua` 运行环境与现有 `.agent/tests/regression.lua`。
- 外部接口保持：Eggy/Editor API 与第三方库命名不改动，仅在调用点适配。

## 变更记录


- 2025-02-14：完成多目录审计与改名替换，补充外部 API 与导出产物例外说明。
- 2025-02-14：补充回归失败修复与收尾总结，原因是需要记录修复细节并完成验收。
