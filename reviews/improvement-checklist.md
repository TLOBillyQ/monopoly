# 代码改进清单 (Code Improvement Checklist)

基于 [code-review-2026-01-16.md](./code-review-2026-01-16.md) 的发现，本清单列出所有需要修复的问题。

---

## 第一阶段：清理冗余抽象 (优先级：高)

预计时间：1-2天  
目标：删除 ~160 行冗余代码，移除 3 个文件

### 修复1: 删除 ui_port.lua 包装层
- [ ] 搜索所有 `UI.push_popup()` 调用点（11处）
- [ ] 替换为直接调用 `game.ui_port:push_popup(...)`
- [ ] 搜索所有 `UI.is_available()` 调用
- [ ] 替换为直接检查 `game.ui_port ~= nil`
- [ ] 删除 `src/gameplay/ui_port.lua` 文件
- [ ] 运行 `lua tests/deps_check.lua` 验证
- [ ] 运行 `lua tests/regression.lua` 验证

**预期收益：** 删除 22 行代码，简化 1 个模块

---

### 修复2: 合并重复的 dispatch() 函数
- [ ] 创建 `src/util/intent_dispatcher.lua`
- [ ] 实现统一的 dispatch 函数
- [ ] 修改 `src/gameplay/choice_resolver.lua` 使用新模块
- [ ] 修改 `src/gameplay/effect_pipeline.lua` 使用新模块
- [ ] 修改 `src/gameplay/item_phase.lua` 使用新模块
- [ ] 删除 3 处 local dispatch 函数定义
- [ ] 运行测试验证

**预期收益：** 删除 36 行重复代码

---

### 修复3: 内联 choice.lua 到调用点
- [ ] 搜索所有 `Choice.get()` 调用（约 3 处）
- [ ] 替换为 `game.store:get({ "turn", "pending_choice" })`
- [ ] 搜索所有 `Choice.open()` 调用（约 2 处）
- [ ] 替换为 `game.store:set({ "turn", "pending_choice" }, spec)`
- [ ] 搜索所有 `Choice.clear()` 调用（约 3 处）
- [ ] 替换为 `game.store:set({ "turn", "pending_choice" }, nil)`
- [ ] 删除 `src/gameplay/choice.lua` 文件
- [ ] 运行测试验证

**预期收益：** 删除 44 行包装代码

---

### 修复4: 删除 landing_resolver.lua 薄层
- [ ] 修改 `src/gameplay/turn_land.lua`
- [ ] 直接 require `effect_pipeline.lua` 而非 `landing_resolver.lua`
- [ ] 使用固定参数调用 `Pipeline.run(...)`
- [ ] 删除 `src/gameplay/landing_resolver.lua` 文件
- [ ] 运行测试验证

**预期收益：** 删除 57 行代码

---

### 修复6: 提取 as_number() 到工具模块
- [ ] 创建 `src/util/convert.lua`
- [ ] 实现 `Convert.to_number()` 函数
- [ ] 修改 `src/gameplay/choice_resolver.lua` 使用新模块
- [ ] 修改 `src/gameplay/market_service.lua` 使用新模块
- [ ] 删除 2 处 local as_number 函数定义
- [ ] 运行测试验证

**预期收益：** 删除 20 行重复代码

---

## 第二阶段：重构复杂模块 (优先级：中)

预计时间：3-5天  
目标：提升可维护性，降低圈复杂度

### 修复5: 拆分 choice_resolver.lua
- [ ] 创建 `src/gameplay/choice_service.lua` (主入口)
- [ ] 创建 `src/gameplay/choice_handlers/` 目录
- [ ] 拆分出 `land_choice_handler.lua`
- [ ] 拆分出 `market_choice_handler.lua`
- [ ] 拆分出 `item_choice_handler.lua`
- [ ] 拆分出 `optional_effect_handler.lua`
- [ ] 更新 composition_root.lua 注入
- [ ] 删除原 choice_resolver.lua
- [ ] 运行测试验证

**预期收益：** 职责分离，圈复杂度降低

---

### 修复7: 简化 agent.lua 嵌套逻辑
- [ ] 重构 `pick_remote_dice_value()` 使用提前返回
- [ ] 添加辅助函数减少嵌套
- [ ] 添加注释说明算法意图
- [ ] 运行测试验证

**预期收益：** 可读性提升

---

### 重命名任务
- [ ] 重命名 `choice_resolver.lua` → `choice_service.lua`
- [ ] 更新所有 require 引用
- [ ] 更新文档中的引用

---

## 第三阶段：补充测试与文档 (优先级：低，持续进行)

### 单元测试
- [ ] `land.lua` 租金计算测试
- [ ] `item_executor.lua` 道具效果测试
- [ ] `agent.lua` AI 决策测试
- [ ] `movement_service.lua` 移动逻辑测试
- [ ] `market_service.lua` 交易逻辑测试

### 集成测试
- [ ] 完整游戏流程测试（起点→落地→选择→结束）
- [ ] 多人破产场景测试
- [ ] 道具组合效果测试

### 边界测试
- [ ] 0金币玩家行为测试
- [ ] 满载道具槽测试
- [ ] 地图边界移动测试

### 文档
- [ ] 添加 API 文档（函数参数与返回值）
- [ ] 补充架构决策记录 (ADR)
- [ ] 更新 README.md 反映最新结构

---

## 错误处理与健壮性增强 (优先级：中-高)

### 空指针保护
- [ ] `land.lua`: 检查 `tile.state` 存在性
- [ ] `board.lua`: 验证路径索引边界
- [ ] 添加默认值或显式错误处理

### 除零保护
- [ ] `land_pricing.lua`: 租金计算时检查分母非零

### 输入验证
- [ ] `choice_resolver.lua`: 验证 option_id 合法性
- [ ] `market_service.lua`: 检查购买数量为正数

---

## 性能优化 (优先级：低，可选)

- [ ] 缓存路径计算结果
- [ ] 复用 context 对象减少 table 分配
- [ ] 优化高频调用路径

---

## 验证清单

每次修复后必须执行：

```bash
# 1. Lua 语法检查（如果可用）
lua -l src/game.lua

# 2. 依赖规则检查
lua tests/deps_check.lua

# 3. 回归测试
lua tests/regression.lua

# 4. Git diff 检查
git diff --stat
```

---

## 进度追踪

| 阶段 | 任务数 | 完成数 | 进度 |
|------|--------|--------|------|
| 第一阶段 | 5 | 0 | 0% |
| 第二阶段 | 3 | 0 | 0% |
| 第三阶段 | 14 | 0 | 0% |
| 错误处理 | 5 | 0 | 0% |
| **总计** | **27** | **0** | **0%** |

---

**最后更新：** 2026-01-16  
**下次评审日期：** 2026-02-16 (建议)
