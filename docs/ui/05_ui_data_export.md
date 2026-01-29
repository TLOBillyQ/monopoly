# ui_data 导出形态

`UIManagerNodes.lua` 是 UIManager 的节点清单，`UIManager.Builder` 会用它构建节点树。

## 数据形态

核心是 “节点 id -> { 节点名, 节点类型 }” 的映射，示例（截取自当前文件）：

    return {
      ["1519736575|1907699520"] = {"btn_next", "EButton"},
      ["1519736575|1248111351"] = {"loading_screen", "ECanvas"},
      ["1519736575|1535720565"] = {"backgroud_rect_base", "EImage"},
      ["1519736575|1951900414"] = {"modal_choice", "ECanvas"},
    }

## 类型约束

常用类型只有四种：ECanvas、EImage、ELabel、EButton。必须与引擎节点类型一致。

## placeholder 说明

当前导出的 `UIManagerNodes.lua` 已不包含 `placeholder|xxx` 条目；若开发阶段需要兜底节点，可临时补充，但交付前必须由 Eggitor 导出真实 id 覆盖。

## 导出要求

- 所有节点名必须与 `docs/ui_naming_list.md` 一致。
- 基础屏不再依赖 tile_1..tile_45 的棋盘文本节点，导出时保持与命名清单一致即可。
- item_slot_* 节点需具备 `image_texture` 与 `disabled` 属性，用于道具图片与点击开关。
