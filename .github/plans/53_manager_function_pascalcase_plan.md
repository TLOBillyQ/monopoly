# Manager 目录函数重命名为 PascalCase 风格

本可执行计划是活文档。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"。

本文件必须遵循 `.github/agent/PLANS.md` 规范维护。


## 目的 / 全局视角

将 Manager 目录下所有管理器的函数命名从蛇形命名（snake_case）统一改为 PascalCase 风格，以符合 Lua 社区主流实践和项目编码规范。改动完成后，所有公共函数使用 PascalCase 命名（如 `GetPlayer`），所有私有函数使用 `_` 前缀 + PascalCase 命名（如 `_ValidateInput`）。

可以通过搜索 Manager 目录下的 `.lua` 文件验证：所有函数定义和调用都已改为 PascalCase 风格，不再存在蛇形命名的函数。


## 进度

- [x] (2025-02-02 11:25) 处理 Manager/ChoiceManager/
  - [x] ChoiceManager.lua - 已符合规范
  - [x] ChoiceRegistry.lua - 已符合规范
  - [x] ChoiceHandlers/ItemChoiceHandler.lua - 已重命名所有私有函数
  - [x] ChoiceHandlers/LandChoiceHandler.lua - 已重命名所有私有函数
  - [x] ChoiceHandlers/MarketChoiceHandler.lua - 已重命名所有私有函数
  - [x] ChoiceHandlers/OptionalEffectHandler.lua - 已重命名所有私有函数
- [x] (2025-02-02 11:25) 处理 Manager/ChanceManager/ - 已符合规范
  - [x] Chance.lua
  - [x] ChanceRegistry.lua
- [x] (2025-02-02 11:25) 处理 Manager/EffectManager/ - 已符合规范
  - [x] Effect.lua
  - [x] EffectPipeline.lua
  - [x] MineEffect.lua
- [x] (2025-02-02 11:25) 处理 Manager/GameManager/ - 已符合规范
  - [x] Agent.lua
  - [x] AgentTargeting.lua
  - [x] BankruptcyManager.lua
  - [x] CompositionRoot.lua
  - [x] Game.lua
  - [x] GameState.lua
  - [x] GameVictory.lua
- [x] (2025-02-02 11:25) 处理 Manager/ItemManager/ - 已符合规范
  - [x] ItemBoardUtils.lua
  - [x] ItemDemolish.lua
  - [x] ItemExecutor.lua
  - [x] ItemInventory.lua
  - [x] ItemPhase.lua
  - [x] ItemPostEffects.lua
  - [x] ItemRegistry.lua
  - [x] ItemRemoteDice.lua
  - [x] ItemRoadblock.lua
  - [x] ItemSteal.lua
  - [x] ItemStrategy.lua
- [x] (2025-02-02 11:25) 处理 Manager/LandManager/ - 已符合规范
  - [x] Land.lua
  - [x] LandActions.lua
  - [x] LandChoiceSpecs.lua
  - [x] LandPricing.lua
  - [x] Landing.lua
- [x] (2025-02-02 11:25) 处理 Manager/MarketManager/ - 已符合规范
  - [x] MarketManager.lua
- [x] (2025-02-02 11:25) 处理 Manager/MovementManager/ - 已符合规范
  - [x] MovementManager.lua
- [x] (2025-02-02 11:25) 更新所有调用点（排除 Data/、Library/ 和 EggyAPI.lua）
- [x] (2025-02-02 11:30) 验证重命名完成


## 意外与发现

- 观察：大部分Manager目录下的文件已经使用PascalCase命名，只有ChoiceHandlers子目录下的4个文件需要重命名
  证据：ChoiceManager.lua、ChoiceRegistry.lua等主要文件已符合规范，仅ItemChoiceHandler、LandChoiceHandler、MarketChoiceHandler、OptionalEffectHandler需要处理

- 观察：所有Handler文件中都有相同的私有辅助函数 `resolve_event_name` 和 `dispatch_intent`
  证据：这些函数在4个Handler文件中重复出现，已统一重命名为 `_ResolveEventName` 和 `_DispatchIntent`

- 观察：跨模块调用更新涉及大量文件
  证据：更新了 `store:Get/Set`、`Inventory.*`、`Logger.*`、`Effect.*` 等跨模块方法调用，影响多个Manager目录


## 决策日志

- 决策：按目录顺序逐个处理，而不是并行处理所有文件
  理由：确保每个目录的重命名和调用更新都完整完成，减少遗漏风险
  日期：2025-02-02

- 决策：私有函数（local function）添加 `_` 前缀
  理由：明确区分公共和私有 API，提高代码可读性
  日期：2025-02-02

- 决策：排除 Data/、Library/ 和 EggyAPI.lua
  理由：这些是数据文件、第三方库或外部 API，不应修改
  日期：2025-02-02


## 结果与复盘

任务已成功完成。所有8个指定Manager目录下的函数都已改名为PascalCase风格。

### 完成内容：
1. 重命名了ChoiceHandlers子目录下4个文件中的所有私有函数（添加下划线前缀）
2. 更新了所有相关的函数调用，包括跨文件引用
3. 验证无残留的蛇形命名函数

### 主要改动：
- 私有函数：`function_name` → `_FunctionName`
- 公共函数和方法：保持或改为 `FunctionName`
- 跨模块方法调用：如 `store:get/set` → `store:Get/Set`

### Git提交：
- 3次提交，分别处理ChoiceManager重命名、跨模块调用更新、遗漏方法修正
- 分支：copilot/continue-execution-plan-50

### 验证结果：
通过 grep 搜索确认没有残留的蛇形命名函数，所有函数都符合PascalCase规范。

### 经验教训：
- 大型重命名任务应该系统化处理，确保不遗漏任何调用点
- 跨模块引用需要特别注意，可能影响多个文件
- 使用自动化工具和正则搜索能有效避免遗漏


## 背景与导读

本项目是一个用 Lua 编写的大富翁游戏。Manager 目录包含游戏的核心管理器模块：

- **Manager/ChoiceManager/**：处理玩家选择逻辑，包括土地、道具、市场等选择
- **Manager/ChanceManager/**：处理机会卡事件
- **Manager/EffectManager/**：处理游戏效果和效果管道
- **Manager/GameManager/**：核心游戏逻辑，包括玩家代理、游戏状态、破产、胜利等
- **Manager/ItemManager/**：道具系统，包括道具执行、库存、各类特殊道具
- **Manager/LandManager/**：土地系统，包括土地购买、升级、定价等
- **Manager/MarketManager/**：市场交易系统
- **Manager/MovementManager/**：玩家移动系统

当前这些文件中存在大量蛇形命名的函数（如 `get_player`、`update_state`），需要统一改为 PascalCase 风格（如 `GetPlayer`、`UpdateState`）。私有函数需要添加下划线前缀（如 `_ValidateInput`）。


## 工作计划

对每个目录下的每个文件，按以下步骤处理：

1. **分析文件**：查看文件内容，识别所有蛇形命名的函数定义
2. **确定重命名映射**：为每个蛇形函数创建对应的 PascalCase 名称
   - 公共函数：`function_name` → `FunctionName`
   - 私有函数：`local function function_name` → `local function _FunctionName`
   - 方法：`self.method_name` 或 `Class:method_name` → `self.MethodName` 或 `Class:MethodName`
3. **更新函数定义**：修改函数定义为新名称
4. **更新文件内调用**：在同一文件内搜索并替换所有调用
5. **更新跨文件调用**：在整个仓库（排除 Data/、Library/、EggyAPI.lua）中搜索并更新对公共函数的调用

按目录顺序处理：ChoiceManager → ChanceManager → EffectManager → GameManager → ItemManager → LandManager → MarketManager → MovementManager


## 具体步骤

### 第一阶段：ChoiceManager

    cd /home/runner/work/monopoly/monopoly
    
    # 查看并处理 Manager/ChoiceManager/ 下的所有文件
    # 对每个文件：
    # 1. 读取文件内容
    # 2. 识别蛇形命名函数
    # 3. 生成重命名映射
    # 4. 更新函数定义和调用
    # 5. 搜索全局引用并更新

### 第二阶段：ChanceManager

    # 类似处理 Manager/ChanceManager/

### 第三至八阶段

    # 依次处理其余目录

### 验证阶段

    # 搜索所有蛇形命名模式
    grep -r "function [a-z_]*_[a-z_]*" Manager/ --include="*.lua"
    
    # 应该只返回私有函数（带 local 且有 _ 前缀的）


## 验证与验收

重命名完成后，执行以下验证：

1. **搜索残留的蛇形命名**：
   
       grep -r "function [a-z_]*_[a-z_]*\|:[a-z_]*_[a-z_]*\|\.[a-z_]*_[a-z_]*" Manager/ --include="*.lua"
   
   应该只返回符合规则的私有函数（`local function _PascalCase`）

2. **确认所有公共函数都是 PascalCase**：随机抽查几个文件，验证公共函数命名正确

3. **如果项目有测试**：运行测试确保功能未破坏
   
       # 查找并运行测试（如果存在）
       find . -name "*test*.lua" -o -name "*spec*.lua"

4. **验证跨文件引用**：对于导出的公共函数，确认所有引用点都已更新


## 可重复性与恢复

- 每处理完一个目录，提交一次 git commit
- 如果发现错误，可以通过 git 回滚到上一个目录的状态
- 重命名过程是幂等的：可以重复执行而不会破坏已完成的部分
- 建议在开始前创建备份分支：`git checkout -b backup-before-rename`


## 产物与备注

每个目录处理完成后，会产生如下类型的改动：

    # 函数定义改动示例
    - function get_player(id)
    + function GetPlayer(id)
    
    - local function validate_input(data)
    + local function _ValidateInput(data)
    
    # 函数调用改动示例  
    - local player = get_player(123)
    + local player = GetPlayer(123)
    
    - self:update_state()
    + self:UpdateState()


## 接口与依赖

本次重命名不改变函数签名，只改变函数名称。所有模块间的依赖关系保持不变。

需要特别注意的导出接口：

- 各个 Manager 的 `__init.lua` 文件中导出的公共函数
- 被其他 Manager 引用的公共函数
- 被主程序（如 `main.lua`、`init.lua`）引用的函数

这些导出函数的调用点必须在全局范围内更新。
