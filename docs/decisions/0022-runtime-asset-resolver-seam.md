---
kind: adr
status: stable
owner: architecture
last_verified: 2026-06-24
---
# ADR 0022 - 运行时资源按含义解析归属 config/runtime_assets seam

## 背景

`运行时资源解析` 是把项目里的领域含义转换成宿主运行时可用资源标识的过程。它覆盖道具图标、机会卡图标、皮肤卡片图、皮肤模型资源、默认皮肤模型、AI 头像、AI unit key、棋盘反馈 cue、音效、特效和缺资源 fallback 策略。

当前实现已经有集中数据，但外部 seam 仍然浅：

- `src/config/content/runtime_refs.lua` 与 `src/config/content/runtime_ref_images.lua` 是核心数据源，但调用方直接知道 `images`、`audio`、`effects`、`board_feedback`、`skins`、`synthetic_ai` 和 `default_creature` 的 table shape。
- `src/ui/render/assets.lua` 直接读取 `runtime_refs.images`，用 `3000 + index` 拼道具图标 ref，并把整张 `runtime_refs` 挂到 `state.ui_refs`。
- `src/ui/render/skin_panel.lua` 直接读取 `state.ui_refs.images[tostring(product_id)]`，因此 skin card image 的含义泄漏成图片表 key 规则。
- `src/app/host_install.lua` 直接读取 `runtime_refs.skins[tostring(product_id)]` 与 `runtime_refs.default_creature`，安装层知道了皮肤 product id 到宿主模型资源 id 的表结构。
- `src/ui/render/board_feedback/catalog.lua` 与 `service.lua` 直接解释 `board_feedback`、`effect_id_ref`、`sound_id_ref`、`followup_sounds`、`audio`、`effects` 与 bind offset。
- `src/config/gameplay/config_sanity.lua` 复制 board feedback ref 校验规则，测试也直接 pin raw runtime ref table。
- `src/app/roster.lua` 直接读取 `runtime_refs.synthetic_ai` 与 `runtime_refs.images.AI*`，把 synthetic AI 的 avatar/name/unit key 组合分散到 app startup。
- popup、item atlas、market 和 action-status 相关 render/helper 仍通过 `state.ui_refs.images` 取图，测试 fixture 也复制这个 raw shape。

这些入口都在学习资源数据的内部分类。后续改资源 id、拆图片表、给皮肤卡和模型加 fallback、扩展 board feedback cue 或调整 synthetic AI 资源时，复杂度会在 config sanity、render、host install、roster、acceptance fixture 和行为测试中扩散。

## 决策

在 `config` 层引入一个深 module 表达 **运行时资源 resolver**，推荐路径为 `src/config/runtime_assets.lua` 或 `src/config/runtime_assets/init.lua`。它的外部 seam 是 meaning-based resolver interface，而不是 raw `runtime_refs` table、`state.ui_refs.images`、render helper、host install wiring 或 board feedback service。

`src/config/content/runtime_refs.lua` 与 `src/config/content/runtime_ref_images.lua` 保持 data-only。它们可以继续作为 resolver 的内部数据源，但 caller 不应直接根据 table category 与 key 取运行时资源。

该 module 至少承担以下入口能力：

- 按领域含义解析图片资源：道具图标、机会卡图标、皮肤卡片图、AI 头像、空占位图等。
- 按领域含义解析模型资源：皮肤 product id 对应的宿主模型 resource id，以及脱下皮肤的默认 creature fallback。
- 按领域含义解析 synthetic AI profile：名字、unit key、头像资源，包含缺项 fallback。
- 按 cue 名解析 board feedback：返回已经解析过的 effect id、sound id、followup sounds、bind offset、duration、volume、scale、allow missing 策略等结构化 cue。
- 校验当前 runtime asset catalog：发现缺图、缺 effect、缺 sound、非法 cue 字段、非法 id 和重复/冲突含义时返回稳定 reason 或抛出稳定错误。

具体函数名由实现阶段决定，但 interface 必须保持领域语言。推荐形状为 `image_for_item(item_id)`、`image_for_chance_card(card_id)`、`image_for_skin_card(product_id)`、`skin_model_for_product(product_id)`、`default_skin_model()`、`synthetic_ai_profile(slot_index)`、`board_feedback_cue(cue_name, overrides)` 与 `validate_catalog()`.

如果实现希望统一入口，可以使用 `resolve(meaning, params)`，但 `meaning` 必须是领域含义，例如 `skin.card_image`、`skin.model`、`item.icon`、`chance.icon`、`synthetic_ai.avatar`、`board_feedback.cue`。不得暴露 `images`、`skins`、`audio`、`effects` 这类 data table category 作为 caller 契约。

## 规则归属

该 module 内部拥有以下规则和状态变更细节：

- product id、item id、chance card id、AI slot index 等 key 的数字/字符串归一化。
- 资源含义到 raw ref key 的映射，例如 `item_id=2007`、`skin_product_id=5001`、`AI slot=2`、`cue_name=upgrade_land_smoke`。
- 图片资源、模型资源、音效资源、特效资源各自的 id 解析、缺失判断和稳定 reason。
- `Empty` 图、默认 creature、synthetic AI name/unit/avatar 的 fallback 策略。
- board feedback cue 的字段归一化：numeric fields、bind offset、effect id、sound id、followup sounds、allow missing resource、payload override。
- 当前配置的完整性校验，包括 board feedback 引用的 effect/sound 是否存在，skin catalog product 是否有 card image 与 model ref，startup 必需 item icon 是否存在。
- warning/错误去重策略可以留在 caller 或 resolver 内部，但缺资源 reason 必须由 resolver 统一命名。

返回值必须是结构化结果，至少能表达 `ok`、`asset_id` 或 `image_key`、`meaning`、`reason`、`allow_missing`、`fallback_used` 和 cue 的已解析字段。旧的 raw table lookup、`nil`、`false`、`effect_id_ref`、`sound_id_ref`、`state.ui_refs.images` 可以继续存在于 implementation 内部或兼容 adapter 内，但不得泄漏为新 seam 的 caller 契约。

## Adapter 归属

`src/config/content/runtime_refs.lua` 与 `runtime_ref_images.lua` 是 data adapter：只保存宿主资源 id 与静态配置，不包含解析逻辑。

`src/ui/render/assets.lua` 降为 UI asset initialization adapter：设置初始 UI 节点图片，并把 resolver 或 resolver view 放进 state。它不拼 `3000 + index`，不把 raw refs 当成 public state contract。

`src/ui/render/skin_panel.lua` 降为 render adapter：渲染 slot view model 或调用 resolver 的 skin card image 含义。它不直接读取 `state.ui_refs.images[tostring(product_id)]`。

`src/app/host_install.lua` 降为 host install adapter：安装 skin equip/unequip 时向 resolver 询问 `skin_model_for_product` 与 `default_skin_model`。它不直接知道 `runtime_refs.skins` 或 `default_creature`。

`src/ui/render/board_feedback/catalog.lua` 与 `service.lua` 降为 playback adapter：播放 resolver 给出的 resolved cue。它们不再自行穿透 `runtime_refs.audio/effects`，也不把 `effect_id_ref`/`sound_id_ref` 当外部 interface。

`src/config/gameplay/config_sanity.lua` 调用 resolver 的 `validate_catalog()`。它不复制 runtime asset 引用校验规则。

`src/app/roster.lua` 调用 resolver 的 synthetic AI profile 入口。它不直接读取 `runtime_refs.synthetic_ai` 或 `images.AI*`。

popup、item atlas、market、action-status 和测试 helper 应改为通过 resolver 或薄 fixture adapter 解析含义。`state.ui_refs = { images = ... }` 可以作为迁移期兼容 adapter 保留，但不得作为新增代码的 interface。

## 测试边界

行为测试应把 runtime asset resolver interface 当作主要 test surface，并用 in-memory runtime ref tables 覆盖含义解析。重点覆盖：

- item/chance/skin/AI/empty image 的 key 归一化与缺资源 reason。
- skin product id 到 card image 与 model resource id 的解析。
- default skin model fallback。
- synthetic AI profile 的 name、unit key、avatar fallback。
- board feedback cue 解析出的 numeric effect id、sound id、followup sound、bind offset、duration、volume、scale 与 allow missing 策略。
- payload override 优先级：显式 numeric id 优先于 ref name，显式 cue 字段优先于默认字段。
- `validate_catalog()` 对缺 effect、缺 sound、缺 followup sound、缺 skin image/model、缺 startup item icon 的稳定失败。

旧的 `spec/behavior/config/runtime_refs_spec.lua` 可以继续 pin data-only 内容，但不应承载 resolver 行为断言。`spec/behavior/config/config_sanity_spec.lua` 应迁移到 resolver validate 入口，或只验证 config sanity adapter 调用了 resolver。UI render、host install 与 roster 测试应断言它们传入领域含义并消费结构化结果，而不是 pin raw `runtime_refs` 路径。

Mutation 重点放在 resolver interface、board feedback playback adapter 和少量 render adapter。不要继续把 raw table lookup 的 mutation 压力散在 `skin_panel.lua`、`assets.lua`、`host_install.lua`、`roster.lua` 和 `config_sanity.lua`。

## 范围外

本决定不重命名宿主资源本身，不从 Eggy 编辑器自动导出资源，也不定义新的资源 id 生成流程。它只规定项目内如何按含义解析已有资源配置。

本决定不覆盖皮肤交易状态、付费购买、board feedback 实际播放时机、UI 节点纹理设置、模型 equip/unequip 宿主调用或资源预加载策略。它们仍由各自 module 和 adapter 处理。

## 影响

这个决定提高 locality：资源 key 归一化、fallback、cue 解析、缺资源 reason 和配置完整性集中在 `config/runtime_assets`。它提高 leverage：render、host install、roster、config sanity、acceptance fixture 和行为测试穿过同一个小 interface，而不是各自学习 raw runtime ref tables。

删除新 module 时，图片 key、模型 ref、board feedback cue、synthetic AI 资源和 fallback 策略会重新散回 UI render、app startup、host install、config sanity 和测试 fixture；这通过 deletion test。

## 取舍

不把 seam 放在 `runtime_refs.lua`：该文件应保持 data-only，便于审查资源 id 与生成来源。把解析逻辑塞进数据表会让内容配置承担行为。

不把 seam 放在 `ui/render/assets.lua`：render asset 初始化只服务 UI。皮肤模型、默认 creature、synthetic AI profile 和 config sanity 也需要同一套含义解析。

不把 seam 放在 `host_install.lua`：host install 是 app wiring，不应拥有 product id 到资源 id、fallback 和缺资源 reason。

不采用 raw `resolve(category, key)` 作为外部契约：这只是把 `runtime_refs.images[...]` 改成函数调用，caller 仍要知道 data table category。外部 interface 必须表达资源含义。
