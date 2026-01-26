# 06 存档与后台服务：`ltask` + `service/save.lua`

本工程将“存档/加载/校验”放到后台服务中，通过消息与主线程交互，以降低卡顿风险并提高数据安全性。

## 关键文件

- `core/loadsave.lua`：主线程侧的存档接口（`ltask.call/send`）
- `service/save.lua`：服务侧实现（保存/加载/校验/备份）
- `gameplay/persist.lua`：序列化与原子写入（`.saving/.save` 交换）
- `gameplay/sync.lua`：把 gameplay 内存态同步到 visual（恢复存档后的画面重建）

## 主线程 API：`core/loadsave.lua`

核心点：

- `SERVICE = ltask.uniqueservice "service.save"`：唯一服务，避免多实例写同一存档
- `load_game()`：
  - `ltask.call` 拉取数据
  - 初始化 `persist` 中的多块数据（deck/history/game/track/galaxy/map）
  - 调用 `card.load/track.load/map.load` 重建运行态
  - 返回保存的 phase（用于恢复状态机）
- `sync_game(phase)`：
  - 生成或读取随机种子，`math.randomseed(seed)` 保持可复现
  - 发送 `sync_game` 给服务并触发 `save_game`

参考：`core/loadsave.lua`

## 服务侧：`service/save.lua` 的工程化价值

服务侧不仅做 I/O，还做了大量 **结构校验与一致性校验**，例如：

- card/adv/track/game/map 的允许字段与类型检查
- pile 内卡牌的存在性与重复性验证（`card_verify`）
- autosave 开关、备份文件命名策略

这种“服务端校验”能显著降低：

- 因逻辑 bug 写出坏存档导致无法继续游戏
- 因版本升级导致存档结构不兼容

参考：`service/save.lua`

## 序列化与原子写入：`gameplay/persist.lua`

保存流程（简化）：

1. 写入 `filename.saving`
2. rename 到 `filename.save`
3. 删除旧 `filename`
4. 把 `filename.save` rename 为 `filename`

这样即使在写入过程中崩溃，也尽量保证磁盘上始终有一个完整文件。

参考：`gameplay/persist.lua` 的 `persist.save`

## 可复用模式

- **I/O 下沉到服务**：主线程只维护内存态，服务负责落盘与校验。
- **严格 schema 校验**：为所有“可持久化对象”定义 allowlist，而不是“写啥都行”。
- **原子写入 + 备份**：避免断电/崩溃造成存档全损。
- **显式 sync 边界**：恢复存档后用 `gameplay/sync.lua` 统一重建视觉层。

