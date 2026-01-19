# gameplay review 落实检查

**日期**：2026-01-19  
**范围**：`docs/reviews/gameplay_review.md`  
**说明**：只核对落实情况，不评估新改动的合理性。

---

## 落实状态

1) 道具 ID 常量化（P1）  
- 结论：**已落实**  
- 依据：玩法层已统一使用 `ITEM_IDS`，未发现 `200x` 魔法数散落。  
- 参考：`src/gameplay/constants.lua`，`src/gameplay/item_executor.lua`，`src/gameplay/item_post_effects.lua`，`src/gameplay/land.lua`，`src/gameplay/land_actions.lua`，`src/gameplay/item_strategy.lua`。

2) 抽取通用“道具选择器”流程（P2）  
- 结论：**已落实**  
- 依据：`run_item_choice_flow` 统一了候选/AI/choice_spec 流程。  
- 参考：`src/gameplay/item_executor.lua`。

3) Choice meta 字段统一（P1）  
- 结论：**已落实**  
- 依据：统一使用 `player_id`，未发现 `user_id/stealer_id`。  
- 参考：`src/gameplay/agent.lua`，`src/gameplay/choice_handlers/item_choice_handler.lua`。

4) Choice 清理与等待态规范（P1）  
- 结论：**部分落实**  
- 依据：`choice_service` 增加统一约定与非法选项兜底，但各 handler 仍自行清理与分支处理。  
- 参考：`src/gameplay/choice_service.lua`，`src/gameplay/choice_handlers/item_choice_handler.lua`，`src/gameplay/choice_handlers/market_choice_handler.lua`。

5) Game/service 获取与 nil 防御规范（P3）  
- 结论：**部分落实**  
- 依据：消除局部重复与风格差异，但跨模块规范仍未统一。  
- 参考：`src/gameplay/land_actions.lua`，`src/gameplay/player_effects.lua`。

6) 等待态返回协议统一（P3）  
- 结论：**已落实**  
- 依据：`effect_pipeline` 统一为“已 dispatch → waiting without intent”。  
- 参考：`src/gameplay/effect_pipeline.lua`。

7) Inventory 入口收敛（P2）  
- 结论：**部分落实**  
- 依据：玩法侧读写大多收敛到 `item_inventory`，破产清空仍保留直接访问。  
- 参考：`src/gameplay/item_inventory.lua`，`src/gameplay/item_steal.lua`，`src/gameplay/market_service.lua`，`src/gameplay/bankruptcy_service.lua`。

8) BFS/队列逻辑复用（P2）  
- 结论：**已落实**  
- 依据：公共队列遍历已收敛到 `BoardUtils.queue_walk`。  
- 参考：`src/gameplay/item_board_utils.lua`，`src/gameplay/land_actions.lua`，`src/gameplay/item_post_effects.lua`。

---

## 总结
- 已落实：1、2、3、6、8  
- 部分落实：4、5、7  
- 未落实：无
