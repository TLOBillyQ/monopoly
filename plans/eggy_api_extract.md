# 拆分 EggyAPI 文档以加速查询

本 ExecPlan 是一个持续更新的文档。必须维护 `Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 四个章节的实时状态。  
本仓库已有 `.agent/PLANS.md`，本计划必须严格遵守该文件要求。

## Purpose / Big Picture

目标是把 `docs/eggy/EggyAPI.lua` 按功能拆分成多个 API 文档，以更快定位接口，同时保证 API 完整性不丢失。完成后，使用者可以在 `docs/eggy/api/` 下按类别快速查找，还能通过一条校验命令确认新文档和原始 API 列表一致。

## Progress

- [x] (2026-01-23 05:20Z) 梳理现有 API 源文件与索引文件，确定拆分结构与命名规则。
- [x] (2026-01-23 06:05Z) 编写抽取/校验脚本，能从 `docs/eggy/EggyAPI.lua` 生成接口清单并进行一致性对比。
- [x] (2026-01-23 06:10Z) 生成拆分后的文档并更新入口索引，完成一致性校验。
- [x] (2026-01-23 06:12Z) 记录验收结果与回退方式，收尾整理。
- [x] (2026-01-23 06:20Z) 补充拆分文档生成脚本，支持一键重建目录。

## Surprises & Discoveries

- Observation: 目前无。
  Evidence: 校验输出显示拆分与源一致。

## Decision Log

- Decision: 拆分以“功能域 + 类型”双层结构组织文档，不依赖外部网页内容。
  Rationale: 外部参考不可直接嵌入计划，自包含要求需要以仓内信息为准。
  Date/Author: 2026-01-23 / Codex

## Outcomes & Retrospective

完成拆分文档与校验脚本，接口总数与原始 API 一致（1198/1198），无缺失无多余。后续维护只需更新拆分文档并运行校验脚本即可快速确认完整性。

## Context and Orientation

当前 API 源是 `docs/eggy/EggyAPI.lua`，内容包含类型定义、别名、枚举、全局 API、组件 API、单位/角色 API、事件常量等，文件极长。  
`docs/eggy/EggyAPI.md` 是按行列出的“模块|函数|参数”索引，已用于检索，但不可读性高。  
本任务要“拆分文档”，不改 Lua 行为，只整理文档。所有 API 的完整性以 `docs/eggy/EggyAPI.lua` 为唯一事实来源。

## Plan of Work

首先阅读 `docs/eggy/EggyAPI.lua` 的结构标记，识别以下可稳定分组的来源标记：  
`---@class` 与 `---@enum`：类型与枚举定义。  
`---@alias`：别名与类型说明。  
`function <Name>`：函数定义，按表名/类名前缀分组（例如 `GlobalAPI:xxx`、`GameAPI:xxx`、`Unit:xxx`）。  
`EVENT.` 常量：事件定义。

然后设计拆分目标目录与文件命名。建议采用 `docs/eggy/api/` 目录，并用“编号 + 主题名”的文件名保持排序稳定，例如：  
`docs/eggy/api/00_index.md`（入口总览与目录）  
`docs/eggy/api/01_types.md`（Vector3/Quaternion/dict/math 等基础类型）  
`docs/eggy/api/02_aliases.md`（所有 `---@alias`）  
`docs/eggy/api/03_enums.md`（所有 `---@enum`）  
`docs/eggy/api/04_global_api.md`（GlobalAPI）  
`docs/eggy/api/05_game_api.md`（GameAPI）  
`docs/eggy/api/06_lua_api.md`（LuaAPI）  
`docs/eggy/api/07_unit_entities.md`（Unit/Character/Creature/Role/Obstacle/Equipment 等实体类）  
`docs/eggy/api/08_components.md`（*Comp 组件类）  
`docs/eggy/api/09_events.md`（EVENT 常量与示例）

拆分逻辑必须确保“原始 API 全覆盖”，因此需要一个抽取/校验脚本。脚本从 `docs/eggy/EggyAPI.lua` 解析 API 清单，输出标准化列表；再从拆分文档解析列表，二者对比并输出差异。  
为了避免引入不可维护的新依赖，使用现有 Python 或 Lua 直接解析文本即可；脚本放在 `scripts/` 下，并在完成后保留，用于将来更新。

## Concrete Steps

在仓库根目录执行以下步骤。  
第一步，创建目标目录并准备入口文档草稿。  
  mkdir docs/eggy/api  
  手工创建 `docs/eggy/api/00_index.md`，先写目标分组标题和简短说明。

第二步，实现抽取与校验脚本，建议新建 `scripts/eggy_api_split_check.py`。脚本功能包括：  
1) 解析 `docs/eggy/EggyAPI.lua`，生成“模块|函数|参数”标准清单。  
2) 解析 `docs/eggy/api/*.md`，生成同格式清单。  
3) 输出差集（缺失/多余/改名）。

第三步，按前述分组规则拆分文档。每个文档保留原始中文注释与参数说明，保证可读性。`docs/eggy/EggyAPI.md` 可作为旧索引保留不动，或改为指向新入口。

第四步，运行校验脚本并在 `Progress` 中记录结果。  
  python scripts/eggy_api_split_check.py  
示例输出应包含：  
  Source count: 1198  
  Split docs count: 1198  
  Missing: 0  
  Extra: 0

## Validation and Acceptance

验收通过的条件是：  
新文档位于 `docs/eggy/api/` 且包含入口索引与分类文档。  
校验脚本显示源 API 数量与拆分文档数量一致，无缺失、无多余。  
随机抽查 2-3 个 API（例如 `GlobalAPI.debug`、`Unit:get_position`、`Role:show_tips`）在新文档中能快速定位且说明完整。

## Idempotence and Recovery

拆分工作可重复执行。若分类规则调整，只需重新生成拆分文档并再次运行校验脚本。  
若脚本或拆分内容出现误差，回退方式为：删除 `docs/eggy/api/` 并重新按脚本生成；源文件 `docs/eggy/EggyAPI.lua` 不被修改，保证安全。

## Artifacts and Notes

已保留关键证据（校验脚本输出）：  
  Source count: 1198  
  Split docs count: 1198  
  Missing: 0  
  Extra: 0

## Interfaces and Dependencies

脚本依赖仅限 Python 标准库或 Lua（任选其一）。  
如果使用 Python，脚本对外接口为：  
  python scripts/eggy_api_split_check.py

脚本内部需要输出结构化清单，格式固定为：  
  <ModuleName>|<FunctionName>|<Params>  
其中 `ModuleName` 与 `FunctionName` 对齐 `docs/eggy/EggyAPI.md` 的格式，便于复用现有索引对照。

Change Note: 初次创建 ExecPlan，基于现有 `docs/eggy/EggyAPI.lua` 与 `docs/eggy/EggyAPI.md` 设计拆分与校验流程。
Change Note: 已完成源文件结构与可分组标记梳理，更新 Progress 状态。
Change Note: 生成拆分文档与校验脚本，并记录验收输出。
Change Note: 新增一键生成拆分文档脚本，便于后续更新。
