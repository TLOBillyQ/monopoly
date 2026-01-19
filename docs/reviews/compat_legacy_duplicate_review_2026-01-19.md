# 代码库审查：兼容 / 遗留 / 重复清理建议

**日期**：2026-01-19  
**范围**：`src/`、`tests/`、`main.lua`  
**目标**：识别兼容/遗留痕迹与重复实现，给出最小化清理建议（不改变现有行为）。

---

## 一、概览结论

- 发现重复/重叠实现 3 类（Inventory、测试工具、入口初始化）。
- 存在兼容/遗留痕迹 2 类（choice meta 字段别名、`---@type any` 兼容注解）。
- 业务常量（道具 ID）多处硬编码，影响可维护性与一致性。

---

## 二、重复/重叠实现

### 1) Inventory 层次重叠
- **文件**：
  - `src\core\inventory.lua`（基础容器）
  - `src\gameplay\item_inventory.lua`（玩法侧操作 + cfg 查询）
- **现象**：玩法侧仍直接操作 `player.inventory`（`find_index/remove_by_index/add`），与 core 容器功能重叠。
- **证据**：
  - `src\core\inventory.lua:14-56`
  - `src\gameplay\item_inventory.lua:22-61`
- **清理建议**：明确层次边界，玩法侧仅负责“道具语义”，容器操作统一经 core（或相反），避免两处并行演进。

### 2) 测试工具重复
- **文件**：
  - `tests\regression.lua:19-23`
  - `tests\flow_control_test.lua:11-14`
- **现象**：`assert_eq` 在多文件重复定义。
- **清理建议**：抽到 `tests/test_utils.lua` 并复用，减少重复与出错面。

### 3) package.path 初始化重复
- **文件**：
  - `main.lua:4`
  - `tests\regression.lua:2`
  - `tests\flow_control_test.lua:4`
- **现象**：多入口重复设置 `package.path`。
- **清理建议**：增加统一 bootstrap（仅 1 个模块），入口复用，降低环境差异风险。

---

## 三、兼容 / 遗留痕迹

### 1) Choice meta 字段别名（兼容旧字段）
- **文件**：`src\gameplay\agent.lua:192-203`
- **现象**：`choice_owner` 同时读取 `player_id` / `user_id` / `stealer_id`。
- **影响**：调用方可能存在旧字段，导致协议不一致。
- **清理建议**：统一 meta 字段名，保留迁移期适配但标注淘汰计划。

### 2) `---@type any` 兼容注解
- **文件**：
  - `src\gameplay\agent.lua:230`
  - `src\gameplay\turn_manager.lua:68,146`
- **现象**：使用 `any` 绕过类型提示（通常是旧工具兼容）。
- **清理建议**：补足局部结构注解（小范围），逐步消除 `any`。

---

## 四、重复硬编码（业务常量）

- **文件/位置**：
  - `src\gameplay\land.lua:111,124,155`
  - `src\gameplay\land_actions.lua:120,140,194`
  - `src\gameplay\agent.lua:137,144`
  - `src\gameplay\item_post_effects.lua:7-115`
  - `src\config\items.lua:2-13`
- **现象**：道具 ID（2001/2007/2009/2010/2011/2012…）在业务逻辑中硬编码，重复散落。
- **影响**：修改成本高，容易漏改。
- **清理建议**：以 `items` 配置为单一来源，集中映射（如常量表或 `cfg_by_id`）供玩法侧引用。

---

## 五、兼容/确定性风险

- **文件**：`src\util\random.lua:13-17`
- **现象**：未提供 RNG 时直接回退 `math.random()`。
- **关联**：已有 `src\core\rng.lua`，但回退路径仍引入非确定性。
- **清理建议**：统一 RNG 注入策略（保持行为一致前提下逐步收敛）。

---

## 六、建议清理优先级

### P1（低风险高收益）
1. 抽出 `tests/test_utils.lua`，统一 `assert_eq` 等工具。
2. 入口统一 `package.path` 初始化，减少测试/运行差异。

### P2（中风险需谨慎）
1. 收敛 `item_id` 常量引用到单一来源。
2. 明确 Inventory 分层边界（避免重复维护）。

### P3（需要验证策略）
1. `random.lua` 取消 `math.random()` 兜底（或统一从 RNG 读取）。
2. Choice meta 字段去兼容化（需要迁移窗口）。

---

## 七、说明

本报告仅为静态审查与整理建议，未修改任何源码与行为。
