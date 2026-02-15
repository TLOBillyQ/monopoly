# 大富翁代码库一次性重构计划

## 问题与目标

当前架构存在根本性设计缺陷，需要一次性彻底重构而非渐进式修补。

核心问题：
1. **GameState 伪装成类，实际是命名空间** — 204行代码中80%是转发方法，无状态只有委托
2. **Effect 系统依赖方向完全倒置** — 高层抽象直接依赖低层实现，模块加载时构建执行器表
3. **全局注册表是单例反模式** — 模块级状态 + `defaults_registered` 标志导致测试污染
4. **UI与业务逻辑硬编码耦合** — Land.lua 直接调用 `ui_port:on_tile_upgraded()`

目标：一次性拆分和重构，不做渐进式折中。

---

## 拟采用方案

### 阶段1：删除 GameState 伪装类

将 GameState 从"假类真转发"改为纯函数式API。

**修改文件：**
- `src/game/core/runtime/GameState.lua` — 删除
- `src/game/core/runtime/GameStateAPI.lua` — 新建，纯函数集合
- `src/game/core/runtime/CompositionRoot.lua` — 不再组装GameState
- 所有调用方 — 改为 `game_state_api.xxx(game, ...)`

### 阶段2：合并 Land/Landing 并倒置依赖

统一地块效果，实现依赖倒置。

**修改文件：**
- `src/game/systems/land/Landing.lua` — 删除
- `src/game/systems/land/Land.lua` — 重写，合并Landing执行器
- `src/game/systems/effects/EffectExecutor.lua` — 新建，接口定义
- `src/game/systems/effects/EffectRegistry.lua` — 新建，依赖注入容器
- `src/game/systems/effects/Effect.lua` — 重写，从Registry获取执行器

### 阶段3：注册表实例化

消除全局状态，支持多实例。

**修改文件：**
- `src/game/systems/items/ItemRegistry.lua` — 重写，支持 `new()`
- `src/game/systems/choices/ChoiceRegistry.lua` — 重写，支持 `new()`
- `src/game/systems/chance/ChanceRegistry.lua` — 重写，支持 `new()`
- `src/game/core/runtime/Bootstrap.lua` — 重写，返回实例而非修改全局
- `src/game/core/runtime/CompositionRoot.lua` — 注入注册表实例

### 阶段4：UI解耦

业务逻辑通过事件与UI通信。

**修改文件：**
- `src/game/systems/land/Land.lua` — 发送事件而非调用UI
- `src/app/init.lua` — 订阅事件并调用UI

---

## 工作清单

- [ ] 删除 `src/game/core/runtime/GameState.lua`
- [ ] 新建 `src/game/core/runtime/GameStateAPI.lua`
- [ ] 修改 `src/game/core/runtime/CompositionRoot.lua` 移除GameState组装
- [ ] 删除 `src/game/systems/land/Landing.lua`
- [ ] 重写 `src/game/systems/land/Land.lua` 合并Landing
- [ ] 新建 `src/game/systems/effects/EffectExecutor.lua`
- [ ] 新建 `src/game/systems/effects/EffectRegistry.lua`
- [ ] 重写 `src/game/systems/effects/Effect.lua`
- [ ] 重写 `src/game/systems/items/ItemRegistry.lua` 实例化模式
- [ ] 重写 `src/game/systems/choices/ChoiceRegistry.lua` 实例化模式
- [ ] 重写 `src/game/systems/chance/ChanceRegistry.lua` 实例化模式
- [ ] 重写 `src/game/core/runtime/Bootstrap.lua`
- [ ] 修改 `src/game/core/runtime/CompositionRoot.lua` 注入依赖
- [ ] 修改 `src/game/systems/land/Land.lua` 使用事件
- [ ] 修改 `src/app/init.lua` 订阅事件
- [ ] 修改所有调用方使用新API
- [ ] 运行回归测试 `lua .github/tests/regression.lua`
- [ ] 验证无新增失败

---

## 风险与约束

- **风险**：改动面过大，调用方众多
  对策：使用grep批量定位，一次性完成避免中间状态

- **风险**：测试覆盖不足，引入回归bug
  对策：重构前补充关键路径测试，全量回归验证后再提交

- **约束**：不做渐进式折中，不保留兼容层，不扩展业务范围

---

## 验收标准

执行 `lua .github/tests/regression.lua` 后：

- 所有原有测试通过
- 无新增失败项
- 删除的文件无残留引用（`grep -r "GameState" --include="*.lua" src/` 无结果）
