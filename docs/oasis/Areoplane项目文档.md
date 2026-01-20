# Areoplane 飞行棋游戏项目文档

## 项目概述

Areoplane 是一个基于虚幻引擎（Unreal Engine）开发的完整飞行棋游戏项目，使用 Lua 脚本语言实现游戏逻辑。这是一个4人对战的多人在线棋类游戏，每位玩家控制4架飞机从起点出发，通过掷骰子决定移动步数，最终目标是让所有飞机抵达终点。

**项目版本**: 1.34.12.23618

**技术栈**:
- 引擎: Unreal Engine (UGC 自定义内容平台)
- 脚本语言: Lua
- 网络架构: 客户端-服务器模式（RPC远程过程调用）
- 音频系统: Wwise

## 目录结构

```
Areoplane/
├── Areoplane.ugcproj          # 项目配置文件
├── Script/                     # Lua脚本代码
│   ├── gamemode/              # 游戏模式和状态机
│   ├── Blueprint/             # 核心游戏逻辑类
│   ├── GameConfigs/           # 游戏配置和常量
│   ├── GameAttribute/         # 游戏属性定义
│   ├── Common/                # 公共工具库
│   ├── UI/UIBP/              # 用户界面组件
│   └── UMGTemplate/           # UI模板
├── Asset/                      # 游戏资源
│   ├── Arts_Effect/           # 视觉效果和动画
│   ├── Blueprint/             # 蓝图资源（骰子、对象等）
│   ├── Data/                  # 游戏数据
│   ├── Map/                   # 游戏地图
│   ├── Objects/               # 游戏对象
│   ├── Particles/             # 粒子效果
│   ├── UI/                    # UI资源
│   ├── UMGTemplate/           # UMG模板
│   ├── WwiseAudio/            # Wwise音频配置
│   └── WwiseEvent/            # 音频事件定义
├── Navmesh/                    # 导航网格
├── UGCmap/                     # 地图文件
├── UGCmap.umap                # 主地图
├── Thumbnail.png              # 项目缩略图
├── WhiteList.ini              # 白名单配置
└── workspace.code-workspace   # VS Code工作区配置
```

## 游戏规则

### 基本规则

1. **玩家人数**: 4人（红、黄、绿、蓝四队）
2. **飞机数量**: 每人4架飞机
3. **获胜条件**: 最先将所有4架飞机送达终点的玩家获胜
4. **排名依据**: 按完成时间排名

### 游戏机制

#### 飞机状态（EPlaneState）
- **在家 (AtHome)**: 尚未起飞
- **待出发 (Ready)**: 已准备起飞
- **已出发 (InFlight)**: 在棋盘上飞行
- **已到达 (Finished)**: 抵达终点

#### 掷骰子规则
- 骰子点数范围: 1-6
- **首次起飞**: 必须掷出6点才能让飞机离开起点
- **再掷一次**: 掷出6点后可以再掷一次
- **吃子规则**: 飞机落在对手飞机位置时，对手飞机被送回起点

#### 回合状态（ERoundStatus）
1. **等待掷骰子 (WaitForRollDice)**: 玩家准备掷骰子
2. **骰子滚动中 (DiceRolling)**: 骰子动画播放中（持续2秒）
3. **等待选择飞机 (WaitForPlaneSelection)**: 玩家选择要移动的飞机
4. **飞机飞行中 (PlaneFlying)**: 飞机移动动画播放中
5. **回合结束 (RoundEnd)**: 本回合结束

#### 游戏状态（EGameStatus）
- **等待就绪 (WaitReady)**: 等待游戏开始
- **游戏中 (Gaming)**: 游戏进行中
- **结算 (Result)**: 游戏结算阶段

### 游戏流程

```
等待玩家加入 (WaitPlayerJoin)
    ↓
准备阶段 (PrepareStage) - 约30秒倒计时
    ↓
游戏开始 (GameStart)
    ↓
游戏回合循环:
    玩家回合开始 (PlayerStartNewRound)
    ↓
    掷骰子 (RollDice)
    ↓
    选择飞机 (SelectPlane)
    ↓
    飞机移动 (FlyPlane)
    ↓
    回合结束 (PlayerRoundEnd)
    ↓
    检查游戏是否结束
    ↓
    切换到下一位玩家
    ↓
游戏结束 (AeroplaneChessGameFinished) - 3位玩家完成后
    ↓
结算显示 (Result)
```

## 核心模块详解

### 1. 游戏模式 (Script/gamemode/)

游戏模式采用**事件驱动的状态机模式**，主要的Action文件：

| 文件 | 功能描述 |
|------|---------|
| **Action_WaitPlayerJoin.lua** | 等待第一位玩家加入，触发准备阶段 |
| **Action_PrepareStage.lua** | 准备倒计时（默认约30秒），显示准备界面 |
| **Action_PlayerStartNewRound.lua** | 玩家回合开始，检查是否可以再次掷骰（掷6点时） |
| **Action_PlayerRoundEnd.lua** | 回合结束，检查游戏是否完成，切换到下一位玩家 |
| **Action_PlayerFinishedGame.lua** | 玩家所有飞机到家时记录完成时间 |
| **Action_AeroplaneChessGameFinished.lua** | 游戏最终结算（3位玩家完成），发送结果到后端 |
| **Action_PlayerLogin.lua** | 处理玩家登录 |
| **Action_PlayerExit.lua** | 处理玩家退出/断线 |
| **Action_SendEvent.lua** | 事件触发系统 |

### 2. 核心类 (Script/Blueprint/)

#### UGCGameState.lua
**主游戏状态管理器**
- 管理所有玩家信息
- 存储骰子结果
- 跟踪飞机位置
- 处理属性复制（网络同步）

主要属性：
- `CurTeamIndex`: 当前玩家索引
- `CurRoundStatus`: 当前回合状态
- `GameStarted`: 游戏是否开始
- `PlayerInfos`: 玩家信息数组
- `DiceResult`: 骰子结果
- `PrepareStageRemainTime`: 准备阶段剩余时间
- `CurRoundRemainTime`: 当前回合剩余时间

#### UGCPlayerController.lua
**玩家控制器**
- 处理玩家输入
- 相机控制
- RPC调用（掷骰子、选择飞机）
- 与服务器通信

主要功能：
- `ServerRPC_RollDice()`: 向服务器请求掷骰子
- `ServerRPC_SelectPlaneToFly()`: 向服务器发送选择的飞机
- 相机位置预设切换

#### UGCGameMode.lua
**游戏模式**
- 游戏模式初始化
- 主要使用事件驱动的Action系统

#### UGCPlayerState.lua
**玩家状态**
- 跟踪单个玩家的状态
- 玩家特定数据

#### AeroplanePawn.lua
**飞机棋子**
- 飞机移动逻辑
- 状态管理
- 位置跟踪
- （注：当前代码中大部分被注释）

#### AeroplaneAIController.lua
**AI控制器**
- 自动托管模式逻辑
- 断线玩家的AI接管

### 3. 游戏配置 (Script/GameConfigs/)

#### AeroplaneChessGlobalConfigs.lua
**全局配置**
- 飞机状态枚举
- 游戏状态枚举
- 回合状态枚举
- 队伍颜色定义（红/黄/绿/蓝）

#### AeroplaneChessMode.lua
**游戏数据中心**
- 游戏数据中心引用
- 玩家引用管理

#### AeroplaneChessEventDefine.lua
**事件定义**（14+个事件）
```lua
201 - PrepareStageRemainTimeChanged    -- 准备倒计时更新
202 - CurRoundRemainTimeChanged        -- 回合倒计时更新
203 - PlayerStartNewRound              -- 玩家回合开始
204 - ReceivedDiceResult               -- 收到骰子结果
205 - PlayerFlyPlane                   -- 飞机移动
206 - PlayerInfosChanged               -- 玩家信息变更
207 - PlaneReachedEndPoint             -- 飞机抵达终点
208 - PlayerFinishedGame               -- 玩家完成游戏
209 - Kill                             -- 吃子
210 - AeroplaneChessGameFinished       -- 游戏结束
211 - TeamIndexAssigned                -- 队伍位置分配
212 - PlayerPanelChange                -- 玩家面板变更
213 - CurRoundStatusChanged            -- 回合状态变更
214 - CurTeamIndexChanged              -- 当前玩家变更
215 - GameStartChanged                 -- 游戏开始状态变更
```

#### AeroplaneChessUIManager.lua
**UI管理器**
- UI组件路径配置
- 骰子动画配置
- 主界面、结算界面、引导界面路径

#### AeroplaneChessAssetConfigs.lua
**资源配置**
- 队伍材质路径（队伍标记/光环）
- 红/黄/绿/蓝队资源路径

#### AeroplaneChessAnimationConfigs.lua
**动画配置**
- 骰子滚动时间（2秒）
- 其他动画时长

#### AeroplaneChessAudioConfig.lua
**音频配置**
- 音频/背景音乐配置
- Wwise事件配置

### 4. 公共工具 (Script/Common/)

| 工具类 | 功能 |
|--------|------|
| **UGCEventSystem.lua** | 发布-订阅事件系统（AddListener、RemoveListener、FireEvent） |
| **TableHelper.lua** | 表操作工具（深拷贝等） |
| **VectorHelper.lua** | 向量数学工具 |
| **UGCBGMTools.lua** | 背景音乐管理 |
| **UGCSoundTools.lua** | 音效管理 |
| **UGCParticleTools.lua** | 粒子效果管理 |
| **UGCAsyncLoadTools.lua** | 异步资源加载 |
| **GlobaTickTools.lua** | 全局定时器工具 |
| **UGCNoticeTipsTools.lua** | 提示通知工具 |
| **ue_enum_custom.lua** | 自定义枚举 |

### 5. UI组件 (Script/UI/UIBP/)

#### 主要UI组件

| 组件 | 功能 |
|------|------|
| **AC_Main_UI.lua** | 根UI界面：显示玩家列表、骰子按钮、棋盘视图、游戏模式按钮 |
| **AC_DiceShow_UIBP.lua** | 骰子结果动画显示（1-6点图标） |
| **AC_Throw_UIBP.lua** | 掷骰子按钮UI |
| **AC_RoundCountdown_UIBP.lua** | 回合倒计时显示 |
| **AC_PrepareStageRemainTime_UIBP.lua** | 准备阶段倒计时 |
| **AC_PlayerList_Item_UIBP.lua** | 单个玩家信息项（位置1-4） |
| **AC_GameStart_Tips_UIBP.lua** | 游戏开始提示 |
| **AC_GameVictory_Tips_UIBP.lua** | 胜利消息 |
| **AC_Kill_Tips_UIBP.lua** | 吃子通知 |
| **AC_56Tips.lua** | "掷到6点，再来一次"提示 |
| **AC_GameShows_UIBP.lua** | 游戏教程/引导 |
| **AC_Result_UIBP.lua** | 最终结算屏幕（排名、时间） |
| **AC_ResultMate_Item_UIBP.lua** | 结算列表中的玩家项 |

#### UI特性
- 实时玩家面板更新
- 骰子动画（2秒滚动）
- 回合倒计时
- 吃子通知（击杀事件）
- 自动托管模式指示器
- 视图切换（投掷视图、自动托管视图、列表视图）
- 相机位置预设

## 网络架构

### RPC模式

#### 服务器RPC（客户端→服务器）
- `ServerRPC_RollDice`: 请求掷骰子
- `ServerRPC_SelectPlaneToFly`: 选择要移动的飞机

#### 多播RPC（服务器→所有客户端）
- `Multicast_NewRoundStart`: 新回合开始广播
- `Multicast_PlayerFlyPlane`: 飞机移动广播
- `Multicast_AeroplaneChessGameFinished`: 游戏结束广播

#### 属性复制
GameState的属性自动同步到所有客户端

### 网络流程示例
```
1. 客户端点击骰子按钮 → ServerRPC_RollDice()
2. 服务器验证回合，掷骰子 → DoRollDice()
3. 服务器广播 → Multicast_NewRoundStart()
4. 客户端UI通过事件更新
```

## 游戏完成与结算

### 获胜条件
- 最先将所有4架飞机送达终点
- 按完成时间排名
- 断线玩家由AI自动托管

### 结算数据
- 玩家排名/位置
- 完成时间
- 到家飞机数量（EntryNum）
- TLog数据报告（用于分析）

## 事件系统

项目使用自定义的发布-订阅事件系统（`UGCEventSystem.lua`）：

```lua
-- 订阅事件
UGCEventSystem.AddListener(EventID, handler, context)

-- 取消订阅
UGCEventSystem.RemoveListener(EventID, handler, context)

-- 触发事件
UGCEventSystem.FireEvent(EventID, ...)
```

### 事件流示例
```
玩家点击掷骰子
    ↓
ServerRPC_RollDice 发送到服务器
    ↓
服务器计算骰子结果
    ↓
触发 ReceivedDiceResult 事件（204）
    ↓
UI组件监听并更新显示
    ↓
AC_DiceShow_UIBP 显示骰子动画
```

## 资源组织

### Asset目录结构
```
Asset/
├── Arts_Effect/              # 视觉效果资源
│   ├── Materials/           # 材质（光环、传送带等）
│   ├── Mesh/                # 网格（皇冠、格子等）
│   ├── Particle/            # 粒子系统
│   └── Texture/             # 贴图
├── Blueprint/               # 蓝图对象
│   ├── Items/              # 游戏物品（棋子、骰子）
│   ├── SceneObjects/       # 场景对象（直升机、格子）
│   └── Animation/          # 动画
├── Data/                    # 游戏数据
│   └── Table/              # 数据表
├── Map/                     # 游戏地图
├── Objects/                 # 可放置对象
├── Particles/               # 粒子效果
├── UI/                      # UI资源
│   ├── ItemIcon/           # 骰子图标（6个点数图标）
│   ├── TeamMark/           # 队伍标记（红/黄/绿/蓝）
│   └── UIBP/              # UI蓝图
├── UMGTemplate/            # UMG模板
├── WwiseAudio/             # Wwise音频集成
└── WwiseEvent/             # 音频事件定义
```

### 队伍资源
每个队伍（红、黄、绿、蓝）都有对应的：
- 队伍标记材质
- 队伍光环效果
- 特定颜色的UI元素

## 开发架构特点

### 设计模式
1. **状态机模式**: 游戏流程通过Action文件实现
2. **事件驱动**: 松耦合的组件通信
3. **MVC架构**: 分离数据（GameState）、逻辑（GameMode）、视图（UI）
4. **服务器权威**: 游戏逻辑在服务器端执行
5. **观察者模式**: UI组件订阅游戏事件

### 代码组织优势
- ✅ 清晰的模块划分
- ✅ 配置与逻辑分离
- ✅ 可复用的工具库
- ✅ 事件驱动的松耦合设计
- ✅ 服务器权威保证公平性
- ✅ AI托管提升用户体验

## 扩展性

### 易于扩展的部分
1. **新游戏规则**: 修改GameConfigs配置
2. **新UI组件**: 添加到UI/UIBP目录
3. **新游戏事件**: 在EventDefine中定义
4. **新音效**: 通过Wwise系统添加
5. **新特效**: 添加粒子效果资源

### 配置化设计
- 游戏规则可通过配置文件调整
- UI路径集中管理
- 资源路径可配置
- 动画时长可调整

## 技术亮点

1. **实时多人同步**: 基于RPC和属性复制的网络架构
2. **AI托管系统**: 断线玩家自动由AI接管，不影响游戏进行
3. **事件系统**: 解耦组件，易于维护和扩展
4. **模块化设计**: 清晰的职责划分
5. **配置驱动**: 游戏行为高度可配置
6. **数据分析**: 集成TLog数据上报

## 总结

Areoplane是一个**生产级的多人在线棋类游戏项目**，具有：

- ✅ 完整的游戏流程
- ✅ 成熟的网络架构
- ✅ 丰富的UI反馈
- ✅ 智能AI托管
- ✅ 数据分析集成
- ✅ 模块化Lua架构
- ✅ 事件驱动的状态机

该项目展示了优秀的游戏架构设计，游戏逻辑、UI、配置和工具之间有清晰的分离，具有高度的可维护性和可扩展性。代码质量高，适合作为UGC游戏开发的参考案例。
