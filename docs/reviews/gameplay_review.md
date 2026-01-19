# 代码评审：src/gameplay

**日期**：2026-01-19  
**范围**：`src/gameplay/`  
**目标**：评审玩法层代码质量、重复与风险，并给出改进路线图（不改变现有行为）。

---

## 一、总体结论

- 玩法层主流程与效果链条清晰，但道具与选择逻辑出现重复模式与硬编码扩散。
- 若继续扩展道具体系，当前“分散式常量 + 重复分支”将放大维护成本。
- 关键风险集中在：**魔法数散落**、**选择/道具处理重复**、**状态/契约不一致**。

---

## 二、问题与证据

### 1) 道具 ID 魔法数散落（高）
- **现象**：道具 ID 大量硬编码，分布在玩法逻辑、选择处理与策略中。
- **影响**：改动/新增道具时需全局搜索，易漏改。
- **证据**：
  - `src\gameplay\item_executor.lua:139-160`（2002/2004/2008/2013）
  - `src\gameplay\item_post_effects.lua:103-120`（2001/2003/2005/2006/2007/2009/2010/2017/2019）
  - `src\gameplay\item_strategy.lua:96-128`（2002/2003/2004/2005/2006/2008/2013/2017/2019）
  - `src\gameplay\land.lua:108-123`（2001/2009）
  - `src\gameplay\land_actions.lua:118-192`（2001/2009/2010）
  - `src\gameplay\movement_service.lua:54`（2007）
  - `src\gameplay\choice_handlers\item_choice_handler.lua:157-180`（2007）

### 2) 道具执行流程重复（三处近似分支）（中）
- **现象**：`item_executor.lua` 中 `handle_target_player_item`、`handle_remote_dice`、`handle_roadblock` 结构一致（候选 -> AI/手动 -> 生成 choice）。
- **影响**：新增类似道具会复制粘贴，易产生差异 bug。
- **证据**：`src\gameplay\item_executor.lua:12-137`

### 3) Choice meta 字段名不一致（中）
- **现象**：`meta` 中混用 `player_id/user_id/stealer_id` 等字段。
- **影响**：Choice 归属判断依赖多分支，增加兼容成本。
- **证据**：`src\gameplay\agent.lua:191-203`

### 4) 状态清理与错误处理风格不统一（中）
- **现象**：有些路径会显式 `clear_choice`，有些依赖返回值；对无效输入的处理风格不统一。
- **影响**：引发“残留等待态”或选择丢失的隐患。
- **证据**：
  - `src\gameplay\choice_service.lua:151-171`（cancel/unknown path）
  - `src\gameplay\choice_handlers\item_choice_handler.lua:20-205`（多分支显式 clear）
  - `src\gameplay\choice_handlers\market_choice_handler.lua:11-50`（finish_choice/intent 混用）

### 5) Game/service 访问风格混杂（中）
- **现象**：有的模块做防御性空值检查，有的直接使用。
- **影响**：测试/脚本场景容易出现 nil 崩溃。
- **证据**：
  - `src\gameplay\land_actions.lua:167-179`（防御性获取 bankruptcy）
  - `src\gameplay\choice_service.lua:12-25`（game/store 存在时才能清理）
  - `src\gameplay\landing.lua:84-93`（对 market nil 早退）

### 6) “等待态返回协议”风格不一致（中）
- **现象**：有的返回 `waiting=true` + `intent`，有的先 `dispatch` 再返回 `stay`。
- **影响**：外层处理方式复杂、难以统一测试。
- **证据**：
  - `src\gameplay\effect_pipeline.lua:35-79`（等待态返回）
  - `src\gameplay\choice_handlers\item_choice_handler.lua:34-79`（先 dispatch 后返回 stay）

### 7) 集合型操作缺少统一入口（中）
- **现象**：Inventory 既有 gameplay 封装，又有直接操作 `player.inventory`。
- **影响**：容器行为分散，不利于统一约束/日志。
- **证据**：
  - `src\gameplay\item_inventory.lua:22-35`
  - `src\gameplay\land.lua:108-123`（直接 `player.inventory:find_index/remove_by_index`）
  - `src\gameplay\land_actions.lua:118-193`（直接 `player.inventory:find_index/remove_by_index`）

### 8) BFS/队列实现重复与潜在低效点（低）
- **现象**：`contiguous_rent` 与 `clear_obstacles_ahead` 均实现 BFS/队列逻辑。
- **影响**：重复逻辑、可读性下降；若地图变复杂，维护成本增加。
- **证据**：
  - `src\gameplay\land_actions.lua:73-105`
  - `src\gameplay\item_post_effects.lua:183-228`

---

## 三、改进路线图（不改行为前提）

### P1（低风险，高收益）
1. **集中道具 ID 常量**
   - 在 `src\gameplay\constants.lua` 或 `item_inventory.lua` 中增加 `ITEM_IDS` 映射。
   - gameplay 代码改用常量引用，替代硬编码数字。
2. **统一 Choice meta 字段**
   - 统一使用 `player_id`，并在 `agent.choice_owner` 里保留一次性兼容。
3. **Choice 清理与等待态规范**
   - 明确“返回 waiting/intent”与“先 dispatch 再 stay”两种模式的适用边界，整理为一处说明或 helper。

### P2（中风险，收益明显）
1. **抽取通用“道具选择器”流程**
   - 以 `item_executor.lua` 的三类 handler 为模板合并为一个可配置流程（候选、AI、choice spec）。
2. **Inventory 入口收敛**
   - 玩法层统一经 `item_inventory.lua` 操作（find/consume/remove），减少直接操作底层容器。
3. **BFS/队列逻辑复用**
   - 抽出轻量遍历 helper（局部模块），避免重复算法散布。

### P3（需评估）
1. **服务获取与 nil 防御规范**
   - 明确 gameplay 模块在无 UI/无 services 的运行边界。
2. **等待态返回协议统一**
   - 为 choice/intent 的返回结构设定单一约定，减少多形态返回值。

---

## 四、备注

本报告为静态审查，不涉及代码改动与行为调整。
