# src 评审报告

## 病徴（按重輕）
### 重
- 连段租金以 `board.path` 线性相邻计，然地圖自明 `path` 仅为索引，实走依 neighbors。分岔地图上恐致租金失真。`src/gameplay/land.lua:18`，`src/config/map.lua:102`。

### 中
- 机会卡「强制征地」仅重置 tile 状态，未清业主 `properties`，致产权残留，后续丢地/破产流程或失实。`src/gameplay/chance.lua:143`，`src/game.lua:89`。
- 毀屋类道具射程以线性索引前后取距，忽略分岔实路，AI 选点与玩家列表或现不可达格。`src/gameplay/item_board_utils.lua:5`，`src/gameplay/item_demolish.lua:119`。

### 輕
- 机会卡破产判定仅于现金 < 0 时淘汰，与租金/税金处理中「=0 即出局」不一，规则易紊。`src/gameplay/chance.lua:15`。

## 改进路线图
- 近程：统一「邻接/距离」模型，明示于 Board/Map；连段租金与道具射程皆改用图距，并补分岔/入内圈之测例。
- 中程：重置地块时同步清理业主 `properties`（含机会卡征地），并增回归测试。
- 远程：整理破产规则（=0 vs <0），抽一处统一判定函数，覆写租金、税金、机会卡之判定。

## 需明
- 分岔地图中「连段租金」之本义：依图邻接抑或依 path 序列？
- 现金归零之玩家是否必出局？若否，现行租金/税金之判定亦当同调。
