# 加载屏（loading_screen）

加载提示界面，通常在游戏初始化或场景切换时显示。

## 结构建议

loading_screen（ECanvas）
- loading_tip（ELabel）
- backgroud_loading（EImage）

## 显示与隐藏

- ECA 事件名：显示加载屏、隐藏加载屏。
- 触发点：`Manager/Adapter/Eggy/EggyRuntime.lua` 在 GAME_INIT 时先显示加载屏并隐藏基础屏，
  然后短延时隐藏加载屏并显示基础屏。
