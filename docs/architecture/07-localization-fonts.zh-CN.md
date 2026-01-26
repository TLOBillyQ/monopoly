# 07 本地化与字体：`core/language.lua` / `core/localization.lua`

本工程把本地化拆成两层：**数据加载与语言切换（language）**、**字符串替换与模板渲染（localization）**，并包含跨平台字体兜底策略。

## 关键文件

- `core/language.lua`：读取 `localization/*.dl`，合并成 DATA，切换语言、选择字体
- `core/localization.lua`：字符串模板替换与递归引用
- `localization/*.dl`：文本、语言设置、随机名称池等

## 加载与合并：`language.init()`

`language.init()` 会遍历 `localization/` 目录，把每个 `.dl` parse 后 merge 到 `DATA`：

- 文本与配置可分散在多个文件中维护
- 最终通过 `DATA[lang]` 组织每种语言的文本表

参考：`core/language.lua`

## 文本模板系统：`localization.convert(key, env)`

`core/localization.lua` 提供两类替换：

- `$(...)`：文本引用（支持递归展开）
- `${...}`：参数替换（支持 `a.b.c` 路径，从 `env` 中取值；支持默认值 `key|default`）

并带有最大深度限制，避免循环引用导致死循环。

参考：`core/localization.lua`

## 字体策略：系统字体 → 字体文件 → 兜底

`core/language.lua` 的 `get_font(lang)` 顺序大致是：

1. 根据语言设置列出的 font name，尝试 `font.name(fontname)` 查找已注册字体
2. 找不到则用 `soluna.font.system` 尝试导入系统字体（跨平台）
3. 仍找不到则尝试从 `fontfile` 加载字体文件导入
4. 最终兜底到默认字体

并在切换语言时：

- `vdesktop.change_font(font_id)` 刷新 UI 文本绘制
- `soluna.set_window_title(...)` 更新窗口标题
- 写入用户设置（`core/setting.lua`）

参考：`core/language.lua` 的 `switch_flush/get_font`

## 可复用模式

- **语言数据与渲染解耦**：渲染层只拿 `localization.convert(...)` 的结果，不关心语言文件组织。
- **文本模板统一**：tips、按钮、HUD 文本都走同一套模板与参数注入。
- **字体多级兜底**：优先系统字体，再退到资源内字体，最大化跨平台可用性。

