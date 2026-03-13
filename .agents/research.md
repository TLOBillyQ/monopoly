# 移动规则简化重构计划（src/）

## 目标

将当前移动规则简化为以下 4 条，并给出可落地的代码库重构路径：

1. 外圈默认逆时针向前移动。
2. 上下左右分叉点在本次移动步数为偶数时进入内圈。
3. 进入内圈后维持直线向前，直到从对侧出口回到外圈。
4. 位置选择屏的邻接关系按地图曼哈顿距离计算。

---

## 当前实现深度理解（基于 src/ 与地图配置）

### 1) 移动主链路

- 入口：`src/game/systems/movement/init.lua` 的 `movement.move(game, player, steps, opts)`。
- 每步推进调用：`board:step_forward_by_facing(current_index, facing, parity)`。
- 步进实现：`src/game/systems/board/init.lua`，当前解析优先级为：
	- `_resolve_outer_next`
	- `_resolve_fresh_forward_next`
	- `_resolve_market_exit`
	- `_resolve_facing_next`
	- `_resolve_fallback_next`

### 2) 地图结构

- 配置：`Config/maps/default_map.lua`
- 外圈：`outer_next/outer_prev`（逆时针闭环）
- 内圈：十字轴线在黑市 `39` 相交
- 入口点：`42/40/41/43`（四边中点）

### 3) 当前分叉与距离计算

- 当前入口逻辑：偶数步 + 朝向匹配（从 `outer_prev` 方向进入）
- 当前黑市逻辑：奇偶决定左转/右转（`turn_left/turn_right`）
- 当前位置范围计算：`src/game/systems/board/query.lua` 的 BFS 图距离（`indices_in_range`）

---

## 目标规则到代码映射

### 规则 1：外圈默认逆时针

- 保留 `default_map.lua` 的 `outer_next`/`outer_prev`。
- `board._resolve_outer_next` 继续作为外圈默认前进来源。

### 规则 2：分叉点偶数进入内圈

- 删除入口朝向匹配条件。
- 条件简化为：`entry and parity and (parity % 2 == 0)`。
- 同一次移动禁止多次进圈（见风险控制）。

### 规则 3：内圈直线穿越

- 删除黑市奇偶左/右转逻辑。
- 在内圈及黑市处优先保持当前 `facing` 直行。
- `fresh_forward_next` 仅用于 fresh 起步时给出初始导向；一旦有 `facing`，持续直行，直至回到外圈。

### 规则 4：位置选择按曼哈顿距离

- 将 `board_query.indices_in_range` 从 BFS 改为基于 tile 坐标 `(row, col)` 的曼哈顿距离：
	- `|row_a - row_b| + |col_a - col_b| <= distance`
- 影响所有使用该接口的系统（例如 `target_query`、`demolish`、`board_utils`）。

---

## 分阶段重构计划

## Phase A：地图与步进规则收敛

### A1. 简化入口规则

- 文件：`src/game/systems/board/init.lua`
- 改动：
	- `_resolve_outer_next(map, current_id, facing, parity)` 改为不依赖 `facing` 匹配。
	- 仅按偶数 `parity` 决定是否进入 `entry.inner_id`。

### A2. 移除黑市分叉

- 文件：`src/game/systems/board/init.lua`
- 改动：
	- 删除 `_resolve_market_exit` 及其在 `_resolve_forward_next_id` 中的调用。
	- 前进解析链改为：
		- `_resolve_outer_next`
		- `_resolve_fresh_forward_next`
		- `_resolve_facing_next`
		- `_resolve_fallback_next`

### A3. 同次移动禁止重入内圈

- 文件：`src/game/systems/movement/init.lua`、`src/game/systems/board/init.lua`
- 改动建议：
	- 在 move context 中新增 `entered_inner` 状态。
	- 首次由外圈进内圈后置 `true`。
	- 后续同次移动经过其他入口点，即使偶数也不再进入。

---

## Phase B：距离模型替换为曼哈顿

### B1. 重写 range 查询

- 文件：`src/game/systems/board/query.lua`
- 改动：
	- `indices_in_range(board, start, distance)` 改为扫描 `board.path` 全量 tile。
	- 用 tile `row/col` 计算曼哈顿距离并筛选。
	- 返回值保持现有索引列表接口不变（兼容调用方）。

### B2. 全局调用侧兼容验证

- 重点文件：
	- `src/game/systems/items/target_query.lua`
	- `src/game/systems/items/demolish.lua`
	- `src/game/systems/land/board_utils.lua`
- 目标：无需改签名，仅验证语义变化可接受。

---

## Phase C：文档、测试与回归

### C1. 设计文档同步

- 文件：`docs/design/map.md`
- 内容：
	- 删除黑市奇偶左右转说明。
	- 更新为“内圈直线穿越 + 偶数入口 + 禁止同次重入”。
	- 新增位置选择使用曼哈顿距离说明。

### C2. 测试重构

- 文件：`tests/suites/domain/movement.lua`
- 改动：
	- 移除/改写 `market_exit` 奇偶转向测试。
	- 更新入口判定测试：不再校验朝向匹配。
	- 新增“直线穿越内圈”四方向路径测试。
	- 新增“同次移动禁止重入”测试。
	- 更新 `indices_in_range` 相关断言为曼哈顿语义。

### C3. 回归验收

- 命令：`lua tests/regression.lua`
- 预期：
	- 领域移动相关 case 与新规则一致
	- target picker 范围行为与曼哈顿规则一致

---

## 关键变更清单（建议）

- `Config/maps/default_map.lua`（必要时精简 map 返回字段）
- `src/game/systems/board/init.lua`（核心前进规则）
- `src/game/systems/movement/init.lua`（重入防护状态）
- `src/game/systems/board/query.lua`（BFS → 曼哈顿）
- `src/game/systems/items/target_query.lua`（语义回归确认）
- `src/game/systems/items/demolish.lua`（语义回归确认）
- `tests/suites/domain/movement.lua`（规则测试同步）
- `docs/design/map.md`（规则文档同步）

---

## 风险与控制

1. **规则切换导致测试大面积变更**
	 - 控制：先改 `board` 核心，再逐步修测试；每步运行 domain + regression。

2. **重入防护遗漏边界路径**
	 - 控制：新增“进圈→穿出→再遇入口”专门测试，覆盖四个入口。

3. **曼哈顿替换影响道具平衡**
	 - 控制：对 `demolish`/`target_query` 做对照用例，确认可选集合与设计预期一致。

---

## 验收标准

- 外圈移动始终逆时针。
- 偶数步到入口即可进内圈（不再依赖朝向匹配）。
- 内圈/黑市不再左右分叉，保持直线穿越到对侧外圈。
- 同一次移动最多进入内圈一次。
- 位置选择与范围判断统一使用曼哈顿距离。
- 回归套件通过，且文档与实现一致。
