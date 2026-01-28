# 临时记录：屏蔽 move_anim

## 目的
- 暂时屏蔽 move_anim，玩家位置只依赖 EggyLayerBoard.refresh_board 渲染

## 修改点
- 移除 eggy_layer.lua 中 move_anim 依赖与动画步进逻辑
- 去掉 eggy_layer_board.lua 中 wait_move_anim 阶段的同步抑制

## 影响文件
- src/adapters/eggy/eggy_layer.lua
- src/adapters/eggy/eggy_layer_board.lua

## 自测
- lua tests/deps_check.lua
