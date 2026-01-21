# Gameplay 架构迁移指南

> 把 Deep Future 的 gameplay 架构应用到"大富翁"项目。

## 核心目标

- 规则与渲染解耦
- 可存档/读档
- 确定性复现（seed + 输入序列 → 相同结果）
- 阶段化流程（可插拔、易扩展）

## 架构四件套

1. **状态机流程** - core/flow.lua（协程驱动阶段逻辑）
2. **集中式 Store** - gameplay/store.lua（持久化数据）
3. **同步层** - gameplay/sync.lua（读档后 UI 全量对齐）
4. **效果系统** - gameplay/effect.lua（事件执行框架）

---

## 目录结构

`​
core/
  flow.lua                  - 状态机/协程调度
  util.lua                  - 通用工具

gameplay/
  store.lua                 - 数据持久化/版本管理
  rng.lua                   - 确定性随机
  board.lua                 - 棋盘结构与移动
  player.lua                - 玩家状态
  property.lua              - 地产规则
  decks/                    - 卡牌系统
  effects/                  - 效果实现
  sync.lua                  - UI 全量对齐
  turn/
    start.lua, roll.lua, move.lua, land.lua, action.lua, end.lua

visual/
  vboard.lua, vplayer.lua, vui.lua, vdecks.lua  - 仅负责渲染与动画
`​

## 模块依赖规则

- gameplay/* 可依赖 core/*
- isual/* 可依赖 core/*
- gameplay/* 可调用 isual.* 触发动画，但不能读取 UI 状态
- **规则判断只能基于 store**

---

## 流程层：状态机

每个阶段是一个函数：

`​
read store → update store → call visual → wait input → return next_state
`​

最小闭环：	urn.start → roll → move → land → action → end

---

## 数据层：Store

**唯一事实来源**，仅包含可存档、可复现的数据：

`​
players       - 玩家数组
board         - 棋盘与地块状态
properties    - 地产所有权/房屋/抵押
decks         - 卡堆与弃牌堆
turn          - 当前玩家/阶段/骰子/回合计数
rng           - 随机状态
meta          - 版本信息
`​

**原子保存**：写入 .save 文件后 rename 覆盖

---

## 同步层：sync_all()

读档/回放后执行，用 store 重建 UI（不依赖是否播过动画）：

- 玩家棋子位置
- 现金/资产数值
- 地产信息（owner/房屋/抵押）
- 卡堆剩余数
- 临时状态（入狱、连掷、免租卡等）

**原则**：规则推进可做差量动画；读档必须全量对齐。

---

## 效果系统

把"落地/抽卡/奖励/惩罚"等统一为 Effect，避免巨型 if-else。

三层结构：

1. **扫描** - list_available_effects(ctx) → effects[]
2. **判定** - can_apply(effect, ctx) → bool
3. **执行** - pply(effect, ctx) → events[]（仅改 store）

执行顺序：强制效果（进狱/交税/交租/抽卡）→ 可选效果（买地/建房/抵押）

---

## 随机性：RNG

- 掷骰、洗牌、抽卡必须走同一 RNG
- ng = RNG(seed) 初始化
- 每次 ng:next() 更新内部 state
- store.rng 持久化为 {seed, state}

---

## 输入与交互

- 阶段脚本等待玩家选择，选择结果写入 store
- UI 高亮由 visual 完成
- 原则：输入只产生"决定"，决定改变 state

---

## 测试

- 固定 seed 的"金路径"回合测试
- 每次 phase 切换记录：	urn, player, phase
- 每次 effect 执行记录：ffect_id, 状态变化

---

## 实施路线图（4 周最小可玩）

- **第 1 周** - 最小闭环（掷骰→移动→交租→结束）
- **第 2 周** - 牌堆与事件（抽卡 + effect 框架）
- **第 3 周** - 资产系统（购买/建房/抵押/破产）
- **第 4 周** - 存档/回放/测试

---

## 检查清单

- [ ] 规则判定仅从 store 读取？
- [ ] 所有随机通过统一 RNG 并持久化？
- [ ] 任意阶段可保存，读档后 sync_all() 恢复正确？
- [ ] "落地/抽卡/奖励"抽象为 effect？
- [ ] visual 仅负责表现，不改 store？

---

## 概念对照表

| Deep Future | 大富翁 |
|---|---|
| core/flow.lua | 状态机 |
| gameplay/persist.lua | gameplay/store.lua |
| gameplay/sync.lua | gameplay/sync.lua |
| gameplay/effect.lua | gameplay/effects/* |
| gameplay/card.lua | gameplay/decks/* |
| gameplay/map.lua | gameplay/board.lua |
