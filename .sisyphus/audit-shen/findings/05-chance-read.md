# T5 — 机会卡翻倍与天使豁免读取站静态审计

> 范围：`src/rules/chance/handlers/*` 与 `src/config/content/chance_cards.lua`
> 目的：审计富/穷神翻倍通道在所有 chance handler 中的覆盖情况，并核对天使豁免（`card.negative` 标注）的覆盖率。
> 不修改任何代码。

---

## 1. 关键读取站速览

### 1.1 `adjust_chance_delta`（统一翻倍入口）
- **定义**：`src/rules/chance/handlers/common.lua:40-48`
  ```lua
  function common.adjust_chance_delta(game, player, delta)
    if delta > 0 and game:player_has_deity(player, "rich") then
      return delta * 2
    end
    if delta < 0 and game:player_has_deity(player, "poor") then
      return delta * 2
    end
    return delta
  end
  ```
- 语义：正向（收入）受 **rich** 翻倍；负向（支出）受 **poor** 翻倍（更亏）。

### 1.2 `cash.lua` 专用翻倍通道（不走 `adjust_chance_delta`）
- `pay_others`：`src/rules/chance/handlers/cash.lua:97-121`，第 104-106 行：
  ```lua
  if game:player_has_deity(player, "poor") then
    fee = fee * 2
  end
  ```
- `collect_from_others`：`src/rules/chance/handlers/cash.lua:123-155`，第 128-130 行：
  ```lua
  if game:player_has_deity(player, "rich") then
    fee = fee * 2
  end
  ```
- 语义：按 player 视角对每个 other 重复结算，不走统一通道。

### 1.3 天使豁免读取点
- `src/rules/chance/resolver.lua:8`：
  ```lua
  if card.negative and game:player_has_angel(player) then
    ... return nil
  end
  ```
- 仅当 `card.negative == true` 且当前抽卡 player 持有 angel，整张卡跳过 handler。

---

## 2. 翻倍通道清单（adjust_chance_delta 调用 vs 专用 cash 通道）

| Handler 文件 | Effect | 调用 `adjust_chance_delta`? | 自带翻倍? | 覆盖分类 |
|---|---|---|---|---|
| `cash.lua:16-39`  | `add_cash`           | ✅ L19、L31  | — | **WORKING**（rich 翻收入） |
| `cash.lua:41-66`  | `pay_cash`           | ✅ L44、L57  | — | **WORKING**（poor 翻支出） |
| `cash.lua:68-95`  | `percent_pay_cash`   | ✅ L72、L86  | — | **WORKING**（按比例后再 poor 翻倍） |
| `cash.lua:97-121` | `pay_others`         | ❌            | ✅ L104-106（仅 poor）| **WORKING / SUSPICIOUS**：见 §4.1 |
| `cash.lua:123-155`| `collect_from_others`| ❌            | ✅ L128-130（仅 rich）| **WORKING / SUSPICIOUS**：见 §4.1 |
| `asset.lua:10-25` | `destroy_buildings_on_path` | ❌  | ❌（无金币流） | **N/A**（无 delta） |
| `asset.lua:27-48` | `reset_tiles_on_path`       | ❌  | ❌                 | **N/A** |
| `asset.lua:50-52` | `grant_item`                | ❌  | ❌                 | **N/A**（道具非金币） |
| `asset.lua:54-85` | `discard_items`             | ❌  | ❌                 | **N/A** |
| `asset.lua:87-134`| `discard_properties`        | ❌  | ❌                 | **N/A** |
| `movement.lua:11-25` | `move_backward`           | ❌  | ❌                 | **N/A**（无金币流） |
| `movement.lua:27-29` | `move_forward`            | ❌  | ❌                 | **N/A** |
| `movement.lua:31-48` | `forced_move`             | ❌  | ❌                 | **N/A**（落地由 landing 自行处理） |

> 没有"应该翻倍但漏调用"的 cash handler；唯一非 `adjust_chance_delta` 的金币通道是 `pay_others` / `collect_from_others`，已显式自带各自的 deity 判断。

---

## 3. `chance_cards.lua` negative 标注覆盖率分析

### 3.1 统计
- **卡牌总数**：32（id 3001-3034，无 3014/3015/3016）
- **`negative = true`**：13 张
  - id 3005, 3006, 3007, 3008（self pay_cash）
  - id 3010（all pay_cash）
  - id 3011（all percent_pay_cash）
  - id 3012（self pay_others）
  - id 3028, 3029（discard_items）
  - id 3030（discard_properties）
  - id 3031, 3032, 3033（forced_move 到医院/深山/税务局）
- **`negative = false`**：19 张

### 3.2 显式声明完整度
- `chance_cards.lua` 全部 32 张卡均显式带 `negative` 字段（无遗漏）。
  → 不存在 nil 漏标导致 angel 永远拦不到的隐患。

### 3.3 可疑分类（SUSPICIOUS）
> 以下卡牌实际效果对玩家可能不利，但 `negative = false` → angel 不会阻挡。

| id | desc | effect | negative | 备注 |
|---|---|---|---|---|
| 3017 | 台风过境，摧毁本回合你经过地块上的所有建筑 | `destroy_buildings_on_path` | false | **SUSPICIOUS**：会把"自己经过地块"的建筑摧毁，若玩家路过自有地，等于损毁自有资产；天使无法豁免。 |
| 3018 | 强制征地，本回合你经过的所有地块恢复初始状态 | `reset_tiles_on_path` | false | **SUSPICIOUS**：同样会把"自己经过的自有地"重置归零；天使无法豁免。 |
| 3013 | 今天是你的生日，每个其他玩家给你3000金币 | `collect_from_others` | false | **WORKING（按当前规则）**：从抽卡 player 视角是正向，故 `negative=false` 合理；其他玩家持有 angel 也无法阻挡（angel 仅检查抽卡者）——这是设计选择，非 bug，但在文档里值得记录。 |
| 3019-3024 | 后退/前进 1-3 格 | `move_backward` / `move_forward` | false | **WORKING**：纯位移、无强制金币惩罚，落地结果决定盈亏，标 false 合理。 |
| 3034 | 你发现密道，到达黑市 | `forced_move` (39) | false | **WORKING**：黑市为正向收益地，标 false 合理。 |
| 3025-3027 | 获得财神/穷神/天使道具 | `grant_item` | false | **WORKING**：纯收益。 |

### 3.4 翻倍 + 豁免组合矩阵（cash 类）

| effect | rich 翻倍 | poor 翻倍 | angel 可阻？ | 评估 |
|---|---|---|---|---|
| `add_cash`（self/all） | ✅ 收入×2 | — | ❌（negative=false） | **WORKING** |
| `pay_cash`（self/all） | — | ✅ 支出×2（更亏） | ✅（negative=true） | **WORKING** |
| `percent_pay_cash`（all） | — | ✅ | ✅ | **WORKING** |
| `pay_others` (3012) | — | ✅（`cash.lua:104`） | ✅（negative=true） | **WORKING** |
| `collect_from_others` (3013) | ✅（`cash.lua:128`） | — | ❌（negative=false） | **WORKING**（设计选择） |

---

## 4. 结论

### 4.1 翻倍通道
- 所有金币通道均覆盖了 deity 翻倍：`adjust_chance_delta` 处理 add_cash/pay_cash/percent_pay_cash，`pay_others` 与 `collect_from_others` 各自显式翻倍。
- **非金币 handler 不需要翻倍通道**（资产/道具/位移）。
- ⚠️ `pay_others` / `collect_from_others` 的翻倍逻辑是手写在 handler 内，与 `adjust_chance_delta` 的统一抽象不一致——属 **SUSPICIOUS（一致性风险）**：未来若新增 deity（如"中庸神"减半），需多点修改。

### 4.2 天使豁免覆盖
- 13/32 卡显式 `negative=true`，覆盖了所有显式金币罚款（pay_cash/percent_pay_cash/pay_others）、强制位移到惩罚性地块（3031-3033）、资产/道具丢失（3028-3030）。
- ⚠️ **id 3017/3018 path-asset 卡片标 `negative=false`**（**SUSPICIOUS**）：若玩家路过自有地，会损毁自有建筑/重置自有地，但天使豁免不生效。建议确认设计意图（是否应改为 `negative=true`，或新增更细分类如 `negative_to_owners`）。
- ✅ 不存在 negative 字段缺失（nil）的卡牌，不会出现 angel 永远失效的低级问题。

### 4.3 分类汇总
- **WORKING**：所有 cash handler 翻倍 + angel 豁免在 cash 类卡上行为一致正确。
- **SUSPICIOUS**：
  1. `pay_others` / `collect_from_others` 翻倍逻辑游离于 `adjust_chance_delta` 之外（一致性风险）。
  2. id 3017/3018 path 类卡 `negative=false` 与"摧毁自有资产"的实际效果存在语义鸿沟。
- **DEAD-CONFIG**：未发现。
- **BROKEN**：未发现。

---

## 文件:行 引用索引
- `src/rules/chance/handlers/common.lua:40-48` — `adjust_chance_delta`
- `src/rules/chance/handlers/cash.lua:19,31,44,57,72,86` — adjust 调用点
- `src/rules/chance/handlers/cash.lua:104-106` — `pay_others` poor 翻倍
- `src/rules/chance/handlers/cash.lua:128-130` — `collect_from_others` rich 翻倍
- `src/rules/chance/resolver.lua:8` — angel 豁免门
- `src/config/content/chance_cards.lua:2-32` — 32 张卡 negative 标注

---

## 未审查清单

以下相关代码本次未覆盖：

- `src/rules/chance/handlers/` 除 `cash.lua` / `common.lua` 外的其余 handler（如 move、property、special 等）是否也有 deity 读取
- `src/rules/chance/resolver.lua` 完整流程（仅审查了 line 8 的 angel 豁免门）
- 机会卡 id 3017/3018 的 path-asset 具体实现代码（仅从配置推断效果，未读实现）
- cheat / debug 入口是否有直接触发机会卡效果的路径
- 测试 fixture 中机会卡相关 stub 是否与真实行为一致
