### 基础屏“玩家金币变化显示”升级计划（含节点名核对）

#### Summary
- 已核对 `Data/UIManagerNodes.lua` 最新变更：仅新增 4 个节点，无旧节点重命名。  
- 新增节点为：`基础-玩家1/2/3/4消耗金币显示`（注意是 `基础-`，不是 `基础_`）。  
- 本次按你确认的规则实现：**收支都显示**（`+金额` / `-金额`），显示时长**跟随 `gameplay_rules.action_anim_default_seconds`**。  
- 其他节点名经排查无需同步改名；黑市模板名（`黑市_购买项`/`黑市_道具名称`/`黑市_底框`）属于拼接前缀，现状正确。

#### Key Changes
- 在基础节点契约中新增金币变化节点模式：  
  - [src/presentation/canvas/base/nodes.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/canvas/base/nodes.lua) 增加 `player_cash_delta = "基础-玩家%s消耗金币显示"`。
- 在面板数据层补充“可比较现金值”，避免从文案反解析：  
  - [src/presentation/ui/UIPanel.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/ui/UIPanel.lua) 的 `player_rows` 新增数值字段（如 `cash_value`，用 `NumberUtils` 生成/归一）。
- 在面板渲染层实现“变化检测 + 临时显示 + 自动隐藏”：  
  - [src/presentation/ui/UIPanelPresenter.lua](C:/Users/Lzx_8/Desktop/dev/repo/monopoly/src/presentation/ui/UIPanelPresenter.lua) 中维护 `ui` 级缓存（上一帧现金、hide token）。  
  - 当 `cash_value` 变化时设置对应 `基础-玩家*消耗金币显示`：  
    - 增加：`+N`  
    - 减少：`-N`  
    - `0` 不显示  
  - 用 `runtime_ports.schedule` 按 `action_anim_default_seconds` 自动隐藏，且用 token 防止新变化被旧定时器误清空。  
  - 同步把该 label 纳入玩家色彩刷新（与名字/现金同色）。
- 名称兼容与降级策略：  
  - 若个别环境缺失该节点，渲染层对该节点更新做安全兜底（仅跳过该效果，不影响主流程）。

#### Test Cases
- `presentation_ui` 新增/更新用例：  
  - 同一玩家现金 `100 -> 80` 显示 `-20`，到时自动隐藏。  
  - 同一玩家现金 `80 -> 120` 显示 `+40`，到时自动隐藏。  
  - 连续变化（短时间两次）只保留最新一条，旧定时器不应清空新文本。  
  - `cash` 不变不显示变化标签。  
  - 缺少“消耗金币显示”节点时不崩溃（仅跳过该节点显示）。
- 回归：  
  - `presentation_ui` 全套通过，确认基础信息（现金/总资产/地块）与托管、行动提示逻辑不受影响。

#### Assumptions
- 本次不改交互流程，只新增基础屏的金币变化可视反馈。  
- “消耗金币显示”节点虽然命名含“消耗”，按你确认统一承载收支两种变化。  
- 不新增配置项，时长直接复用 `gameplay_rules.action_anim_default_seconds`。
