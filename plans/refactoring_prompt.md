# 计划讨论
## 最终目标
交付一系列嵌套的可执行计划到plans/下。

此计划描述了如何实现一个`LuaSource_大富翁`(后面称为原版)的重构版本，此版本的根目录为`./Refactoring`。
重构版本是monopoly项目的eggy适配最终版本。

## 重构版本（下称此版本）
总体上，利用原版中的尝试（ move.lua, macro.lua, init.lua, eca.lua）与数据（ui_data.lua, refs.lua），以及生存割草/汉堡UI/商城道具的知识。

- main入口的初始化，仿造生存割草的main.lua初始化流程。
- 保留原版的UI管理器（从汉堡UI中来），管理器的文档是ui_manager.lib.md. UINodes.lua里是黑市/机会卡/道具卡等UI Panel的具体名称，这里缺少信息需要进一步理清。
- 利用goods_api.md与商城道具项目知识，接入src/gameplay中的item与chance, init.lua中的“道具槽位"对应的是gameplay中最多五个item的
- 原版中的eca.lua的存在时为了转发lua事件到 eggy编辑器中的触发器系统，类似切屏和载具的接口在触发器系统中，使用eca转发可以实现
- 原版中的move.lua实际上实现了移动动画

## 注意
- 此轮讨论，我们关注在可执行计划的层级结构，或者说可执行计划链，弄清执行的先后依赖，比如首先我们需要确定重构版本的文件目录层级结构。
