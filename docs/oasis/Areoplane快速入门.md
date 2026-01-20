# Areoplane 飞行棋快速入门指南

## 快速概览

Areoplane 是一个完整的飞行棋游戏项目，支持4人在线对战。本指南帮助开发者快速理解项目结构并开始开发。

## 5分钟了解项目

### 项目本质
- **游戏类型**: 飞行棋（4人对战棋类游戏）
- **技术栈**: Unreal Engine + Lua
- **网络模式**: 客户端-服务器架构
- **代码量**: 约60+个Lua文件

### 核心文件（必看）

```
Script/
├── gamemode/                          # 游戏流程控制 ⭐⭐⭐
│   ├── Action_WaitPlayerJoin.lua     # 等待玩家加入
│   ├── Action_PrepareStage.lua       # 准备倒计时
│   ├── Action_PlayerStartNewRound.lua# 回合开始
│   └── Action_PlayerRoundEnd.lua     # 回合结束
│
├── Blueprint/                         # 游戏核心类 ⭐⭐⭐
│   ├── UGCGameState.lua              # 游戏状态（最重要）
│   ├── UGCPlayerController.lua       # 玩家控制器
│   └── UGCGameMode.lua               # 游戏模式
│
├── GameConfigs/                       # 配置文件 ⭐⭐
│   ├── AeroplaneChessGlobalConfigs.lua  # 全局配置
│   ├── AeroplaneChessEventDefine.lua    # 事件定义
│   └── AeroplaneChessUIManager.lua      # UI配置
│
└── UI/UIBP/                          # UI组件 ⭐
    ├── AC_Main_UI.lua                # 主界面
    ├── AC_DiceShow_UIBP.lua          # 骰子显示
    └── AC_Result_UIBP.lua            # 结算界面
```

## 10分钟快速上手

### 1. 理解游戏流程（2分钟）

```
玩家加入 → 准备(30秒) → 游戏开始 → 
回合循环(掷骰子→选飞机→飞机移动→回合结束) → 
游戏结束 → 结算
```

### 2. 理解关键概念（3分钟）

#### 飞机状态
- **在家**: 还没起飞
- **待出发**: 准备起飞（需要掷6点）
- **飞行中**: 在棋盘上
- **到达**: 到达终点

#### 回合状态
```lua
WaitForRollDice      -- 等待掷骰子
  ↓
DiceRolling         -- 骰子滚动(2秒)
  ↓
WaitForPlaneSelection -- 等待选择飞机
  ↓
PlaneFlying         -- 飞机飞行
  ↓
RoundEnd            -- 回合结束
```

#### 特殊规则
- 掷6点可以再掷一次
- 掷6点才能起飞
- 落在对手位置可以吃子

### 3. 理解网络通信（2分钟）

```lua
-- 客户端请求（玩家→服务器）
ServerRPC_RollDice()           -- 请求掷骰子
ServerRPC_SelectPlaneToFly()   -- 请求移动飞机

-- 服务器广播（服务器→所有玩家）
Multicast_NewRoundStart()      -- 新回合开始
Multicast_PlayerFlyPlane()     -- 飞机移动广播
```

### 4. 理解事件系统（3分钟）

```lua
-- 订阅事件
UGCEventSystem.AddListener(EventID, handler, context)

-- 触发事件
UGCEventSystem.FireEvent(EventID, ...)

-- 常用事件
204 - ReceivedDiceResult       -- 骰子结果
205 - PlayerFlyPlane           -- 飞机移动
210 - AeroplaneChessGameFinished -- 游戏结束
```

## 30分钟深入理解

### 阅读顺序建议

#### 第一步：理解游戏状态（10分钟）
1. 阅读 `Script/Blueprint/UGCGameState.lua`
   - 重点看属性定义部分
   - 理解 PlayerInfos 结构
   - 理解 CurRoundStatus 状态

2. 阅读 `Script/GameConfigs/AeroplaneChessGlobalConfigs.lua`
   - 看枚举定义
   - 理解各种状态值

#### 第二步：理解游戏流程（10分钟）
3. 阅读 `Script/gamemode/readme.txt`（如果存在）

4. 按顺序阅读 Action 文件：
   - `Action_WaitPlayerJoin.lua`
   - `Action_PrepareStage.lua`
   - `Action_PlayerStartNewRound.lua`
   - `Action_PlayerRoundEnd.lua`

#### 第三步：理解玩家交互（10分钟）
5. 阅读 `Script/Blueprint/UGCPlayerController.lua`
   - 重点看 ServerRPC 函数
   - 理解输入处理

6. 浏览 `Script/UI/UIBP/AC_Main_UI.lua`
   - 理解UI如何响应事件
   - 看事件监听部分

## 常见开发任务

### 任务1: 修改准备时间
```lua
-- 文件: Script/gamemode/Action_PrepareStage.lua
-- 找到这一行并修改数值
local prepareTime = 30  -- 修改为你想要的秒数
```

### 任务2: 修改回合时间
```lua
-- 文件: Script/Blueprint/UGCGameState.lua
-- 找到回合时间配置并修改
local roundTime = 15  -- 修改为你想要的秒数
```

### 任务3: 添加新的UI提示
```lua
-- 1. 在 GameConfigs/AeroplaneChessEventDefine.lua 定义新事件
AeroplaneChessEventDefine.MyNewEvent = 216

-- 2. 在合适的地方触发事件
UGCEventSystem.FireEvent(AeroplaneChessEventDefine.MyNewEvent, data)

-- 3. 在UI组件中监听
function MyUIComponent:OnEnable()
    UGCEventSystem.AddListener(
        AeroplaneChessEventDefine.MyNewEvent, 
        self.OnMyNewEvent, 
        self
    )
end

function MyUIComponent:OnMyNewEvent(data)
    -- 处理事件
end
```

### 任务4: 修改骰子动画时间
```lua
-- 文件: Script/GameConfigs/AeroplaneChessAnimationConfigs.lua
DiceRollingTime = 2.0  -- 修改为你想要的秒数
```

### 任务5: 添加新的音效
```lua
-- 使用 UGCSoundTools 播放音效
UGCSoundTools.PlaySound(soundPath, location)

-- 使用 UGCBGMTools 播放背景音乐
UGCBGMTools.PlayBGM(bgmPath)
```

## 调试技巧

### 1. 打印日志
```lua
-- 使用 UE4 的打印函数
print("Debug info: " .. tostring(value))

-- 或者使用 UE 日志
UE.UKismetSystemLibrary.PrintString(self, "Debug info", true, true)
```

### 2. 查看游戏状态
```lua
-- 在 PlayerController 中获取 GameState
local gameState = self:GetGameState()
print("Current Team: " .. gameState.CurTeamIndex)
print("Round Status: " .. gameState.CurRoundStatus)
print("Dice Result: " .. gameState.DiceResult)
```

### 3. 监听所有事件
```lua
-- 在某个组件中添加所有事件监听（用于调试）
for eventId = 201, 215 do
    UGCEventSystem.AddListener(eventId, function(...)
        print("Event " .. eventId .. " fired")
    end, self)
end
```

## 项目结构速查

### 按功能分类

#### 游戏逻辑层
- `Script/gamemode/` - 游戏流程控制
- `Script/Blueprint/` - 核心游戏类

#### 配置层
- `Script/GameConfigs/` - 所有配置文件
- `Script/GameAttribute/` - 属性定义

#### 表现层
- `Script/UI/` - UI组件
- `Asset/UI/` - UI资源
- `Asset/Arts_Effect/` - 特效资源

#### 工具层
- `Script/Common/` - 通用工具库

### 按修改频率分类

#### 经常修改
- UI组件 (`Script/UI/`)
- 游戏配置 (`Script/GameConfigs/`)
- 游戏流程 (`Script/gamemode/`)

#### 偶尔修改
- 核心游戏类 (`Script/Blueprint/`)
- 工具库 (`Script/Common/`)

#### 很少修改
- 资源文件 (`Asset/`)
- 引擎相关 (`.uasset` 文件)

## 常见问题 FAQ

### Q1: 如何开始一个本地测试？
A: 在 Unreal Editor 中打开 `UGCmap.umap`，点击 Play 按钮。需要至少1个玩家加入才会进入准备阶段。

### Q2: 如何模拟多人游戏？
A: 在 Editor 中设置 "Number of Players" 为 4，选择 "Play as Listen Server"。

### Q3: 修改Lua代码后需要重启吗？
A: 如果项目支持热重载，可能不需要。否则需要停止游戏重新启动。

### Q4: 在哪里查看网络同步的数据？
A: 在 `UGCGameState.lua` 中，所有标记为 Replicated 的属性都会自动同步。

### Q5: UI不更新怎么办？
A: 检查：
1. 事件是否正确触发？（添加 print 日志）
2. UI组件是否正确监听了事件？
3. 事件ID是否正确？

### Q6: 如何添加新的游戏规则？
A: 
1. 在 `GameConfigs` 中添加配置
2. 在对应的 Action 文件中实现逻辑
3. 如果需要UI反馈，定义新事件并在UI中监听

## 代码规范

### 命名约定
```lua
-- 类名：大驼峰
UGCGameState, PlayerController

-- 函数名：大驼峰
function MyClass:DoSomething()

-- 变量名：小驼峰
local myVariable = 10

-- 常量：全大写+下划线
local MAX_PLAYERS = 4

-- 私有函数：前缀下划线
function MyClass:_PrivateFunction()
```

### 文件组织
```lua
-- 1. 模块声明
local MyClass = {}

-- 2. 依赖引用
local Helper = require("Helper")

-- 3. 常量定义
local CONSTANT_VALUE = 100

-- 4. 函数实现
function MyClass:Initialize()
end

-- 5. 返回模块
return MyClass
```

## 学习路径建议

### 初级（1-2天）
1. 理解飞行棋游戏规则
2. 阅读本快速入门指南
3. 浏览主要的 Lua 文件
4. 运行游戏，观察游戏流程

### 中级（3-5天）
1. 深入阅读 GameState 和 PlayerController
2. 理解事件系统的使用
3. 修改简单的配置（时间、UI等）
4. 添加简单的日志输出

### 高级（1-2周）
1. 理解完整的网络架构
2. 修改游戏逻辑
3. 添加新功能
4. 优化性能

## 推荐工具

### 代码编辑
- **VS Code** + Lua 插件
- 打开 `workspace.code-workspace` 文件

### 调试
- Unreal Engine 内置调试器
- Lua 打印日志

### 版本控制
- Git（记得添加 `.gitignore` 排除大型资源文件）

## 下一步

完成快速入门后，建议：

1. 📖 阅读完整的项目文档 (`Areoplane项目文档.md`)
2. 🏗️ 查看架构图文档 (`Areoplane架构图.md`)
3. 🔍 深入研究感兴趣的模块
4. 🛠️ 尝试添加一个小功能
5. 🎮 运行游戏，实际体验

## 参考资源

### 项目文档
- `Areoplane项目文档.md` - 完整的项目文档
- `Areoplane架构图.md` - 架构图和流程图

### 代码注释
- 大部分关键代码都有中文注释
- 查看 `Script/gamemode/readme.txt` 了解游戏模式

### 外部资源
- Unreal Engine 官方文档
- Lua 语言参考手册

---

**祝你开发愉快！** 🚀

如有问题，请参考完整的项目文档或查看源代码中的注释。
