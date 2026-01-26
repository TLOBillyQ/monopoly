# 03 数据驱动：`.dl` 配置、layout、sprites/icons

工程大量使用 `.dl`（datalist）做“资源/配置/布局”的数据承载，让 Lua 代码更偏向行为与流程。

## `.dl` 在本工程中的三种用途

1. **UI/规则配置**：`asset/gameplay/*.dl`（例如 `asset/gameplay/ui.dl`）
2. **UI layout 描述**：`asset/layout/*.dl`（例如 `asset/layout/hud.dl`）
3. **资源表**：`asset/icons.dl`、`asset/sprites.dl`

## 配置读取：`core/rules.lua`

`core/rules.lua` 用 `util.cache` + `soluna.datalist.parse` 做懒加载缓存：

- 访问 `require("core.rules").ui` 时，实际上会加载 `asset/gameplay/ui.dl`
- 同理还有 `phase.dl`、`track.dl` 等（按 key 映射到文件名）

参考：`core/rules.lua`、`core/util.lua` 的 `util.cache`

## layout 加载与脚本扩展：`core/widget.lua` + `visual/ui.lua`

- `core/widget.lua`：用 `soluna.layout.load(filename, scripts[k])` 加载 layout
- `visual/ui.lua`：提供 `scripts.track(name)` 等函数，**动态生成** layout 中需要的子结构

这允许你在 layout 中写“静态骨架”，再用 Lua 把重复/参数化部分生成出来。

参考：`core/widget.lua`、`visual/ui.lua`

## sprites/icons：用 `.dl` 描述资源元信息

示例：

- `asset/icons.dl`：给 icon name 绑定图片路径
- `asset/sprites.dl`：定义 sprite 名称、文件名与锚点等
- `main.lua`：`soluna.load_sprites "asset/sprites.dl"`、`text.init "asset/icons.dl"`

## 可复用模式

- **把“可调参”从代码挪到数据**：颜色、尺寸、速度、布局比例都在 `.dl` 里。
- **对外暴露稳定数据接口**：Lua 侧只读 `rules.ui.xxx`，不关心文件格式细节。
- **脚本化生成重复结构**：用 `scripts.*` 避免在 layout 文件里复制粘贴大量节点。

## 常见坑（建议）

- 缓存失效：`util.cache` 是懒加载缓存，语言切换/热更新时可能需要显式清理（工程里也有 `todo` 提示）。
- 数据结构校验：对外部输入/存档要做严格校验（见 `service/save.lua`），对内部 `.dl` 也建议在启动期做基本断言。

