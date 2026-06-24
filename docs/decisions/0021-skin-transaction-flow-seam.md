---
kind: adr
status: stable
owner: architecture
last_verified: 2026-06-24
---
# ADR 0021 - 皮肤交易流程归属 app/cosmetics seam

## 背景

`皮肤交易流程` 是玩家在皮肤商店中查看某个角色的皮肤状态，触发购买、购买成功后解锁并自动装备，或对已持有皮肤执行装备/脱下，并把持有与装备状态同步到宿主归档的完整玩法过程。它包含皮肤目录、角色持有状态、当前装备状态、付费购买入口、购买回调履约、装备宿主模型、成就进度、归档读写和面板可观察结果。

当前实现已经有可替换材料，但外部 seam 仍然浅：

- `src/ui/coord/skin_panel.lua` 同时负责 panel 打开/关闭/翻页、slot 到 catalog 的映射、owned/equipped 状态、购买 callback、购买成功解锁、装备、脱下、归档读写和提示。
- `src/app/host_integrations/skin_purchase.lua` 只把 skin 转成 paid purchase entry，但成功履约仍是从 UI panel 传入的 `on_success` callback。
- `src/app/host_install.lua` 直接把 `skin_panel.configure_equip`、`configure_unequip`、`skin_purchase.configure`、runtime refs 与成就进度接在一起，安装层知道了交易流程的多段内部结构。
- `src/host/paid_purchase_gateway.lua` 是真实宿主付费 adapter，负责商品映射、pending queue 和宿主回调；但 skin 购买履约身份目前靠 UI callback 闭包间接保存。
- `src/ui/input/route_skin_panel.lua` 为了把按钮路由为 `equip` 或 `unequip`，在 input adapter 中查询 live equipped 状态。
- `src/ui/render/skin_panel.lua` 直接根据 `owned_by_role` 与 `selected_by_role` 推导 locked/owned/equipped、按钮 copy、价格图标和 touch 状态。
- `features/v102/skin_shop.feature`、`tools/acceptance/steps/skin_shop.lua`、`spec/behavior/ui/skin_panel_spec.lua` 与 `spec/property/skin_archive_spec.lua` 都在不同层断言交易细节，测试容易穿过 UI 私有状态而不是稳定交易 interface。

这些入口都在学习“皮肤交易”的内部组合。后续修改统一 198 金豆购买、付费回调、归档恢复、装备宿主模型、按钮 copy 或购买失败 reason 时，复杂度会在 panel coord、host install、render、input route、acceptance steps 和 host adapter 之间扩散。

## 决策

在 `app/cosmetics` 引入一个深 module 表达 **皮肤交易流程**。它的外部 seam 是 app/cosmetics transaction interface，而不是 UI panel callback、render slot 状态、host install wiring、paid host gateway 或 acceptance step。

该 module 至少承担两类入口：

- 处理皮肤商店交易动作：解析 actor、panel role、page/slot 或 product id；读取/维护角色持有与装备状态；对未持有购买类皮肤启动付费购买；对已持有皮肤执行装备；对已装备皮肤执行脱下；返回结构化交易结果。
- 完成付费购买履约：验证宿主回调对应的 pending skin purchase；确认 product id 与 role 仍合法；标记持有；自动装备购买的皮肤；同步归档；返回结构化交易结果。

具体函数名和参数形状由实现阶段决定，但 interface 必须保持领域语言。推荐形状为 `handle_skin_transaction(state, role_id, request, context)` 与 `complete_skin_purchase(state, role_id, product_id, context)`。`request` 可以表达 `open`、`equip_slot`、`equip_product`、`unequip`、`page_next`、`page_prev` 等用户意图；caller 不得传 `on_success` callback、直接传 mutable owned/equipped map、传 render button 状态，或直接操作归档字段。

该 module 可以内部使用 `src.config.content.skins`、`src.rules.ports.paid_purchase`、`src.rules.cosmetics` 与宿主归档 adapter，但这些依赖必须通过明确 adapter 或内部 seam 注入。真实宿主付费是外部依赖，应保留 production adapter 与 in-memory test adapter；不要把 host paid gateway 细节暴露为皮肤交易 interface。

## 规则归属

该 module 内部拥有以下规则和状态变更细节：

- page/slot/product id 到 skin catalog entry 的解析，以及缺 slot、越界 slot、缺 product 的稳定 reason。
- 皮肤状态计算：empty、locked、owned、equipped，以及按钮可执行动作、价格 copy、价格图标可见性和购买可触达性所需的领域状态。
- 购买类皮肤的合法性：`unlock == "purchase"`、`product_id`、`currency`、`price`、当前角色、当前玩家、付费网关可用性和 in-flight 状态。
- 购买启动：构造 paid purchase entry，记录 pending skin purchase，向 paid purchase port 发起宿主购买，并在失败时返回稳定 reason。
- 购买成功履约：只解锁 pending 中记录的 product id；page 已改变时仍履约原购买皮肤；重复、过期、缺角色、缺商品或不匹配回调返回稳定 reason。
- 解锁语义：只有付费购买成功写入宿主归档的 owned 状态；测试或运营直接解锁路径若保留，必须作为明确 request/source，而不是 UI action 私自写 map。
- 装备语义：装备已持有皮肤时调用 equip adapter、记录 `last_equip_ok` 或等价结果、保存 equipped product、刷新可观察状态并返回是否关闭 panel。
- 脱下语义：清空 equipped product、调用 unequip adapter、保存归档并刷新可观察状态。
- 打开商店时从归档读取 owned/equipped；只自动装备归档中已持有的皮肤；缺 archive 或 partial archive 时返回可观察的 no-op 结果而不是让 caller 分支。
- 装备成功时触发皮肤成就进度；runtime refs 的 product id 到宿主 resource id 映射属于 equip adapter，不属于 UI callback。
- UI 提示、刷新、关闭 panel 等副作用以结构化结果表达，由 UI adapter 执行；交易 module 不要求 caller 记住调用顺序。

返回值必须是结构化结果，至少能表达 accepted/rejected、stable reason、pending purchase、purchase fulfilled、ownership changed、equipped product、unequipped、panel should close、slot view model dirty、notification、host action attempted、host action result 等语义。旧的 `true`、`false`、`on_success`、`owned_by_role`、`selected_by_role`、`last_equip_ok_by_role` 可以继续存在于 implementation 内部或兼容状态里，但不得泄漏为新 seam 的 caller 契约。

## Adapter 归属

`src/ui/coord/skin_panel.lua` 降为 panel adapter：负责 panel open/close/page 状态、把 canvas action 翻译成 skin transaction request、执行结构化结果中的 UI side effects，并请求 render 刷新。它不拥有购买启动、购买成功履约、归档同步、装备/脱下语义或 slot 状态推导。

`src/ui/render/skin_panel.lua` 降为 render adapter：渲染 transaction module 给出的 slot view model。它不直接读取 `owned_by_role`、`selected_by_role` 来决定 locked/owned/equipped、按钮 copy、价格图标或 touch 状态。

`src/ui/input/route_skin_panel.lua` 降为 input adapter：把点击翻译成稳定的 panel intent。它不通过 require coord module 查询 equipped 状态来决定 `equip`/`unequip`；action 类型应来自 transaction view model 或由 transaction module 在处理 intent 时决定。

`src/app/host_integrations/skin_purchase.lua` 应被折叠为 transaction implementation 内部 adapter，或保留为很薄的 paid-purchase adapter。它不再接受 UI 传入的 `on_success` fulfillment callback。

`src/app/host_install.lua` 只安装 adapters：paid purchase gateway、skin equip adapter、skin archive adapter、achievement adapter 和 transaction module。它不把多段交易流程直接接在 `skin_panel.configure_*` 上。

`src/host/paid_purchase_gateway.lua` 保持真实宿主 adapter：商品列表映射、宿主购买面板、宿主回调事件、pending goods queue 都属于该 adapter。它不拥有 skin ownership/equip/archive 语义，也不通过 UI 闭包履约皮肤交易。

Acceptance step 与 `tools/acceptance/steps/skin_shop.lua` 降为 adapter：布置皮肤目录、打开商店、触发玩家可观察动作、读取 transaction 结果或 UI view model。它不得直接检查/修改 `owned_by_role` 与 `selected_by_role` 来替代交易 interface。

## 测试边界

行为测试应把新 skin transaction interface 当作主要 test surface，并用 in-memory paid gateway、archive、equip、unequip 与 achievement adapters 覆盖交易结果。重点覆盖：

- 打开商店从 archive 恢复 owned/equipped，只自动装备已持有皮肤。
- 未持有购买类皮肤启动购买，并把 role、product id、name、currency、price 传给 paid purchase port。
- host purchase success 只解锁并装备 pending product；page 变化后仍装备原购买皮肤。
- paid gateway 缺失、商品映射缺失、角色缺失、重复回调、过期回调、in-flight purchase 等稳定 reason。
- 已持有皮肤直接装备，不触发购买；已装备皮肤脱下并清归档。
- equip adapter 返回 true/false/nil 或抛错时，交易结果与可观察状态稳定。
- archive 缺 load/save 方法时保持 no-op 语义。
- slot view model 对 locked/owned/equipped/empty、198 金豆价格、touch 状态与按钮 copy 的输出。

旧的 `spec/behavior/ui/skin_panel_spec.lua` 应缩窄为 panel adapter 与 render adapter 测试；交易行为迁移到新 module interface。`spec/property/skin_archive_spec.lua` 应改为 transaction interface 的 archive round-trip property，而不是直接驱动 `skin_panel.open`。Host paid gateway 的商品映射与事件回调测试继续保留在 gateway 层，但不得断言 skin ownership/equip 细节。

Mutation 重点放在新 module 的外部 interface，以及 paid host adapter 与 render adapter 的窄接口。不要继续让 `skin_panel.lua` 同时承担交易规则、adapter wiring 和 render refresh 的 mutation 压力。

## 范围外

本决定不重写黑市商品购买、道具商店付费商品、`src.rules.market.paid_purchase_flow` 或宿主商品列表映射。它们可以继续使用 `src.rules.ports.paid_purchase` 与 `src.host.paid_purchase_gateway`。

本决定不覆盖皮肤卡片纯视觉布局、皮肤图库展示、runtime ref 配置完整性、成就定义、宿主归档底层 key 设计或付费货币余额系统。它们可以由各自 module 和 seam 处理。

## 影响

这个决定提高 locality：皮肤购买启动、购买成功履约、持有状态、装备状态、归档读写、装备宿主模型和可观察 slot 状态集中在 `app/cosmetics`。它提高 leverage：UI、render、input、host install、acceptance 和行为测试穿过同一个交易 interface，而不是各自学习 panel 私有 map、purchase callback、host paid entry 和 archive callback 的组合。

删除新 module 时，购买成功履约、pending product 身份、owned/equipped 状态、archive 读写、装备宿主模型和 slot 状态推导会重新散回 `skin_panel`、`skin_purchase`、`host_install`、render、input route 和 acceptance steps；这通过 deletion test。

## 取舍

不把 seam 放在 `ui/coord/skin_panel.lua`：panel coord 拥有打开/关闭/翻页和 canvas 刷新，但皮肤交易跨 UI、host paid、archive、equip 和 achievement，属于 app/cosmetics 流程。

不把 seam 放在 `src.host.paid_purchase_gateway`：paid gateway 是真实宿主 adapter，只知道商品购买面板与宿主回调。它不应理解 skin ownership、auto-equip 或 archive。

不把 seam 放在 `src.rules.cosmetics`：该文件是宿主模型装备 adapter，负责角色模型切换。它不是购买、持有、归档和 UI 状态的交易流程。

不继续使用 UI `on_success` callback 作为交易契约：callback 很方便，但它把 pending product 身份和履约副作用藏在 UI 闭包里，使 paid adapter、测试和 acceptance 都难以通过稳定 interface 观察交易结果。
