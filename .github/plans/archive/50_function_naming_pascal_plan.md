# 函数命名改为 PascalCase + 私有下划线前缀计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.github/agent/PLANS.md`。


## 目的 / 全局视角


目标是将仓库内 Lua 代码（不含 `Data/`、`Library/` 与 `EggyAPI.lua`）的函数命名统一为 PascalCase，并用命名区分 public/private：对外可调用的函数使用 PascalCase，私有函数使用 `_` 前缀 + PascalCase。完成后可观察的结果是：除 `Data/`、`Library/` 与 `EggyAPI.lua` 外的函数定义与调用均符合新命名规则，`rg` 检查不再命中这些范围内的蛇形命名函数，且回归脚本通过。


## 进度


- [ ] (2026-02-02 19:40Z) 盘点 `Data/`、`Library/` 与 `EggyAPI.lua` 之外的 Lua 函数定义与跨文件引用，明确 public/private 判定与改名清单。
- [ ] (2026-02-02 19:40Z) 按目录分批完成函数重命名与调用点更新（不含 `Data/`、`Library/` 与 `EggyAPI.lua`），保证每批次可独立运行回归脚本。
- [ ] (2026-02-02 19:40Z) 统一补齐私有函数 `_` 前缀，清理残留蛇形命名函数（不含 `Data/`、`Library/` 与 `EggyAPI.lua`）。
- [ ] (2026-02-02 19:40Z) 完成回归脚本与命名扫描验证，补充日志与复盘。


## 意外与发现


暂无，实施中补充。


## 决策日志


- 决策：public 函数以“模块/类对外导出的函数”为准，命名使用 PascalCase；private 函数限定为文件内使用的本地函数，命名使用 `_` 前缀 + PascalCase。
  理由：Lua 没有访问控制，采用导出表与 local 作用域作为可执行、可检查的判定规则。
  日期/作者：2026-02-02 / Codex
- 决策：方法形式 `function X:foo()` 同样按 PascalCase 统一为 `function X:Foo()`。
  理由：方法调用属于函数命名的一部分，必须与公开 API 一致。
  日期/作者：2026-02-02 / Codex
- 决策：本次重命名范围排除 `Data/` 与 `Library/` 目录。
  理由：用户明确要求不改动这两个目录。
  日期/作者：2026-02-02 / Codex
- 决策：本次重命名范围排除 `EggyAPI.lua`。
  理由：该文件为引擎 API 存根，改名会破坏外部约定。
  日期/作者：2026-02-02 / Codex


## 结果与复盘


尚未开始，完成后补充。


## 背景与导读


仓库以 Lua 模块为主，模块通常返回一个表或类对象，外部通过 `require` 获得后调用其函数。当前函数命名以蛇形命名（如 `make_candidate`、`is_enabled`、`build_choice_spec`）为主，缺少 public/private 的视觉区分。此次改动不触及 `Data/`、`Library/` 与 `EggyAPI.lua`，主要集中于 `Manager/`、`Components/`、`Globals/`、`Config/` 等目录。

关键示例文件：

  Manager/ItemManager/ItemRoadblock.lua
  Manager/ItemManager/ItemPhase.lua
  Manager/EffectManager/Effect.lua
  Components/Board.lua
  Manager/TurnManager/TurnManager.lua
  main.lua

这些文件中既有模块对外函数（如 `ItemPhase.run`、`Effect.execute`），也有仅限本文件使用的 local helper（如 `build_ctx`、`forward_indices`），需要按规则区分并统一命名。


## 工作计划


先在仓库根目录盘点 `Data/`、`Library/` 与 `EggyAPI.lua` 之外的函数定义与调用点，依据“是否导出/是否 local”判定 public/private，并输出一份改名清单。然后按目录分批执行改名（建议顺序：`Components/` -> `Globals/` -> `Manager/` -> `main.lua` / `init.lua`），每批次完成后立即更新所有引用并运行回归脚本，避免一次性大改导致回滚成本过高。每个文件内的 local helper 函数统一改为 `_` 前缀 + PascalCase，并同步更新本文件内的调用点。模块对外函数与类方法统一改为 PascalCase，并更新跨文件引用。最后进行命名扫描，确保范围内没有残留蛇形命名函数。


## 具体步骤


在仓库根目录盘点函数定义与命名风格（排除 `Data/`、`Library/` 与 `EggyAPI.lua`）：

    rg -n "^\s*local function [a-z_]" -g "*.lua" -g "!Data/**" -g "!Library/**" -g "!EggyAPI.lua"
    rg -n "^\s*function [A-Za-z_]+\.[a-z_]" -g "*.lua" -g "!Data/**" -g "!Library/**" -g "!EggyAPI.lua"
    rg -n "^\s*function [A-Za-z_]+:[a-z_]" -g "*.lua" -g "!Data/**" -g "!Library/**" -g "!EggyAPI.lua"

为每个命中的函数制定改名清单，区分 public/private 并记录在本计划“进度”中。示例规则：

    local function build_ctx -> local function _BuildCtx
    function ItemPhase.run -> function ItemPhase.Run
    function Effect:execute -> function Effect:Execute

按目录分批执行改名（排除 `Data/`、`Library/` 与 `EggyAPI.lua`）。每次改名后用 `rg -n "旧函数名" -g "*.lua" -g "!Data/**" -g "!Library/**" -g "!EggyAPI.lua"` 查找并更新所有调用点，必要时检查字符串引用：

    rg -n "\"旧函数名\"" -g "*.lua" -g "!Data/**" -g "!Library/**" -g "!EggyAPI.lua"

每完成一批目录，运行回归脚本并记录输出：

    lua .github/tests/regression.lua


## 验证与验收


运行 `lua .github/tests/regression.lua`，预期输出包含：

    All regression checks passed (N)

并执行命名扫描，确认范围内不再出现蛇形命名函数：

    rg -n "^\s*local function [a-z_]" -g "*.lua" -g "!Data/**" -g "!Library/**" -g "!EggyAPI.lua"
    rg -n "^\s*function [A-Za-z_]+\.[a-z_]" -g "*.lua" -g "!Data/**" -g "!Library/**" -g "!EggyAPI.lua"
    rg -n "^\s*function [A-Za-z_]+:[a-z_]" -g "*.lua" -g "!Data/**" -g "!Library/**" -g "!EggyAPI.lua"

如有残留，补充改名并重新运行回归脚本。


## 可重复性与恢复


改动为函数改名与调用点更新，可通过反向重命名恢复旧命名。若某批次改名失败，可仅回退该批次目录的改名并重新执行，避免全仓一次性回滚。为避免遗漏，恢复后仍需运行回归脚本确认行为不变。


## 产物与备注


保留以下证据片段：

    rg -n "^\s*function [A-Za-z_]+\.[a-z_]" -g "*.lua" -g "!Data/**" -g "!Library/**" -g "!EggyAPI.lua"
    (无输出)
    lua .github/tests/regression.lua
    All regression checks passed (N)


## 接口与依赖


本次仅调整函数命名（不含 `Data/`、`Library/` 与 `EggyAPI.lua`），不改变函数签名、参数、返回值与行为。统一规则如下：

  - public：模块返回表或类对象对外暴露的函数与方法，命名为 PascalCase，例如 `ItemPhase.Run`、`Effect.Execute`、`Board:GetTile`。
  - private：仅在当前文件使用的 local helper 函数，命名为 `_` 前缀 + PascalCase，例如 `_BuildCtx`、`_ForwardIndices`。

所有对外函数名变更必须同步更新调用点，确保 `require` 的使用方式与行为不变。`Data/`、`Library/` 与 `EggyAPI.lua` 保持不改动，即便存在不符合命名规则的函数也暂不处理。


本次修改说明：新建“函数命名改为 PascalCase + 私有下划线前缀计划”，原因是响应用户对统一函数命名风格与 public/private 区分的要求。
本次修改说明：明确排除 `Data/` 与 `Library/` 目录，更新范围描述与验证命令，原因是用户要求不改动这两个目录。
本次修改说明：明确排除 `EggyAPI.lua`，更新范围描述与验证命令，原因是该文件为引擎 API 存根不应改名。
