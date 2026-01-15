# Brainstorm - 托管/AI/AutoRunner 演进方向
Date: 2026-01-15

## 目标与边界
- 目标：玩家托管 = 使用 AI 策略自动做决策；AutoRunner 只负责把决策结果“模拟输入”。
- 前提：这是头脑风暴阶段，允许全局重构与跨层调整。
- 成功标准：同一套 AI 决策在不同前端一致生效；UI 自动化不影响核心逻辑正确性。

## 批判性接受：该方向的风险
- UI 层模拟输入具有顺序和时序依赖，容易被界面变化破坏；将托管建立在 UI mock 上会把核心逻辑绑死在某个前端。
- AI 决策与输入执行混在一起会导致“无法复现”的问题：同一策略在不同前端出现不同选择。
- 自动化路径过多（TurnManager/ChoiceResolver/AutoRunner 各自“自动选”）会造成重复逻辑和冲突。

结论：方向成立，但必须让“托管/AI 决策”归属于核心逻辑层，AutoRunner 只能作为 UI 的输入模拟器，而不是策略的来源。

## 最优方案（建议架构）

### 核心原则
1) 决策单一来源：所有自动决策从一个“决策入口”产出 action（或 nil）。
2) UI 无逻辑：AutoRunner 只执行 action，不产生策略。
3) 统一在 gameplay 层：托管、AI、无人机测试均调用同一套策略。

### 关键模块
- DecisionEngine（核心层）：
  - 输入：game state + choice context + policy（AI/托管配置）。
  - 输出：action 或 nil。
  - 作用：统一策略执行点，组合 Agent + Strategy + (future) 规则脚本。

- ActionDispatcher（应用层）：
  - 输入：action。
  - 输出：state 更新（TurnManager / ChoiceResolver）。
  - 作用：统一 action 触发，避免 UI 直接绕过。

- AutoRunner（UI 层）：
  - 输入：action。
  - 输出：mock input（button/click）或者直接调用 dispatch。
  - 作用：纯执行，不参与策略。

### 合并策略
- 统一保留 Agent/Strategy 的“决策能力”，让托管直接走 DecisionEngine。
- AutoRunner 不再基于“选择 UI 默认项”的逻辑做策略，而是只执行 DecisionEngine 给出的 action。

## 落地路线图（最优方案）

Phase 1 - 单一决策入口
- 新增 DecisionEngine：封装 Agent.auto_action_for_choice + Strategy.auto_pre_action。
- TurnManager 在 wait_choice 统一调用 DecisionEngine，移除其他自动选择分支。
- 产出统一 action 结构，明确 action 格式的规范。

Phase 2 - 托管接入核心逻辑
- 在玩家状态中加入“托管模式”标记；托管玩家的每次 choice 都由 DecisionEngine 产生 action。
- UI 层保留“自动播放”按钮，但仅影响 AutoRunner 的执行速度，不改变决策逻辑。

Phase 3 - AutoRunner 退回执行器
- AutoRunner 不再有“无选择自动 cancel/默认选项”的分支；它只负责执行已有 action。
- 若无 action，保持等待，不主动推断。

Phase 4 - 统一测试与验证
- 增加“前端无关”的托管测试：直接调用 DecisionEngine + ChoiceResolver。
- 在 Love2D 层保留少量 UI 集成测试，确保 action -> input mock 正常工作。

## 衍生收益
- 托管逻辑与 AI 策略的演进完全共享；AI 调整自动影响托管。
- 前端可替换（Love2D/未来 Web）而托管行为保持一致。
- 自动化路径减少，调试链路更清晰。

## 开放问题
- 是否允许托管策略与 AI 策略不同（例如托管更保守）？如果需要，需要 policy 维度。
- 是否允许用户在托管中“干预一次”？需要明确 action 来源的优先级。
- 是否将 DecisionEngine 设计成纯函数，便于重放与测试？
