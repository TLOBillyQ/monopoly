---
kind: adr
status: accepted
owner: specification
last_verified: 2026-06-25
---
# ADR 0018 — 局内金币以角色属性为真源

## 背景

现有大富翁局内经济以 Lua 侧 `player.cash` 作为金币余额，买地、升级、租金、机会卡和起点奖励都围绕该字段读写。产品裁定要求 Lua 侧自己维护的金币统一改成角色 Fixed 属性里的“金币”，属性 id 为 `coin_count`。

## 决策

局内经济的唯一金币余额改为角色 Fixed 属性 `coin_count`。`player.cash` 不再作为业务运行时字段或缓存镜像存在；所有金币读写应经统一的角色属性访问边界完成，测试和离线环境只能提供该边界的 fake 存储。

`coin_count` 不是蛋仔 commodity、金豆、乐园币或外部商品货币；本迁移不得接 commodity API 或付费货币通道。

新玩家初始化时先创建不含金币余额的 `Player` 对象，再立即通过统一金币边界把 `constants.starting_cash + fan_club.starting_cash_bonus()` 写入该玩家的 `coin_count`，而不是先放入 `player.cash` 或传入 `Player.new`。初始金币是状态种子，不是对局内“获得金币”事件；初始化写入应保证 UI 初始刷新能读到余额，但不触发 `cash_receive` 这类获得动画。

只有玩家创建/加入流程可以初始化 `coin_count`。`player_balance("金币")` 等普通读余额入口读到缺失的 `coin_count` 时必须硬失败并指出该玩家金币未初始化，不得自动写入起始金币。

恢复或重连路径如果已有 `coin_count`，不得重新应用 `constants.starting_cash` 或 `fan_club.starting_cash_bonus()`。起始金币和粉丝团加成只在新玩家加入时种子写入一次，避免重复发钱。

角色属性访问固定使用 `get_attr_raw_fixed("coin_count")` / `set_attr_raw_fixed("coin_count", value)`；增减金币时读当前值后写回新值。

`coin_count` 属性 id 必须抽成单一常量，例如 `COIN_COUNT_ATTR_ID = "coin_count"`。金币边界、Role fake、测试和静态 guard 都应引用该常量；除常量定义、feature/ADR 文档和错误断言外，运行时实现不应散落 `"coin_count"` 字符串。

没有真实 Eggy Role 的场景也必须通过同一属性边界：acceptance driver、单测和 synthetic AI 使用支持 `get_attr_raw_fixed` / `set_attr_raw_fixed` 的 fake role 或内存 store，不得回退到 `player.cash`。

生产运行时如果解析不到支持 `coin_count` raw fixed 属性读写的 Role，金币读写必须硬失败并给出清晰错误；不得降级为 0，也不得临时创建 `player.cash`。

Fixed 只是宿主属性类型；大富翁经济的业务金额仍是整数金币。规则层不得引入小数金币、四舍五入或小数租金。

金币余额保持现有局内经济语义，不允许把 `coin_count` 写成负数。统一金币边界在写入前校验结果；消费、租金或扣款如果会低于 0，应按既有玩法规则失败或进入既有不足/破产流程，不得因为迁移到角色属性而写入负数。

金币边界只接受有限整数 number。读到或准备写入 `nil`、非 number、小数、`NaN` 或无穷大时必须硬失败并给出清晰错误，不得把脏值带入买地、租金或其他经济规则计算。

所有 `coin_count` 读写或校验失败都必须可诊断，错误信息至少包含玩家 id 或玩家名、属性 id `coin_count`、失败原因，例如缺少 Role、缺少 `get_attr_raw_fixed` / `set_attr_raw_fixed`、读到非法值或写入负数。

租金、转账等“一人扣钱、一人加钱”的金币结算必须具备单次结算语义：先校验付款方余额和双方 Role 属性能力，全部通过后再写付款方与收款方 `coin_count`。如果任何一方读写失败或付款方余额不足，本次结算整体失败，不允许出现一边扣款成功、另一边未到账的状态。

如果宿主 Role 属性没有事务能力，转账写入前必须记录双方旧余额。写入过程中任一写失败时，必须尽力恢复已写玩家的旧 `coin_count` 并硬失败；错误信息需要说明原始失败和回滚结果。若回滚也失败，必须进入明确 fatal 错误状态，不得静默继续。

现有规则层公共入口 `player_balance("金币")`、`add_player_cash`、`set_player_cash` 可暂时保留名称，但内部必须读写 `coin_count`；禁止的是 `player.cash` 字段作为余额真源，不是这些方法名。本轮不把 `add_player_cash` / `set_player_cash` 重命名为 `add_player_coins` / `set_player_coins`，后续命名清理应作为独立低风险任务处理。`set_player_cash` 只能用于初始化、测试 fixture、恢复/调试加载和明确“设为某值”的系统流程；普通玩法的奖励、扣款、租金和购买应使用加、减或转账语义。

玩家可见 Gherkin 继续表述为“金币”；只有迁移 feature、技术验收或实现说明需要明确金币由角色属性 `coin_count` 承载。

玩家界面、玩家日志和普通玩法 Gherkin 继续展示“金币”，不得把 `coin_count` 暴露为玩家文案。`coin_count` 只出现在迁移 feature、技术错误、调试/测试断言和实现文档中。

测试档案和调试 profile 可以临时接受既有 `cash` 输入别名，但加载时必须立即写入 `coin_count`，运行时状态不得保留 `cash`；若生产存档没有旧 `cash` 字段，则不新增生产兼容迁移。

规则运行时、调试快照和 acceptance 状态输出都不得再暴露 `player.cash` 或 `cash` 余额字段。需要展示余额时通过 `player_balance("金币")` 或玩家可见“金币”字段表达；旧 profile 输入可以临时接受 `cash`，但加载后的输出不得再带 `cash`。

表现层事件和动画命名中的 `cash_receive` / `suppress_cash_receive_anim` 本轮不重命名；它们只表示“收到金币”的效果。获得/扣减动画 payload 继续表示本次变化量 `delta`，UI 刷新需要余额时再通过 `player_balance("金币")` 读取 `coin_count`，不得把动画 payload 改成变化后的余额。

`Player.new(attrs)` 不再接受 `balances = { ["金币"] = ... }` 作为余额输入；玩家对象只保留身份、位置、状态、库存等 Lua 状态，金币余额不属于 Player 对象。

`Player` 对象上的 `cash` 余额字段必须一次性删除，不允许以“暂不使用”的形式保留。表现层的 `cash_receive` 命名可以保留，但它不能对应 Player 对象上的 `cash` 字段。

本迁移需要静态 guard：`src/**` 不得直接读写 `player.cash` 或把 `.cash` 当作余额字段。`spec/**` 和 `tools/acceptance/**` 允许旧 profile 输入兼容和 `cash_receive` 表现命名，但禁止断言或构造运行时 `player.cash`；测试例外不能继续固化旧余额模型。

金币属性访问边界归在 `src/player/actions/balance.lua` 这一侧：规则层继续调用 `player_balance("金币")`、`add_player_cash`、`set_player_cash`，由 balance 边界解析 Role 并读写 `coin_count`。Chance、land、items 等规则模块不得直接调用 EggyAPI 属性接口。

Role 解析也必须收敛在窄适配边界里：`balance.lua` 可以依赖本地 helper/adapter 从 player 解析对应 Role，并只暴露 `get_coin_count` / `set_coin_count` 或等价窄接口。业务规则、测试和玩法模块不应直接认识 EggyAPI 的完整 Role / AttrComp 结构。

所有金币变化最终都必须收敛到统一金币边界里的加、减、设置或转账等操作。规则模块不得复制“读取 `coin_count`、自行计算、写回 `coin_count`”的三步逻辑；非负、整数、错误信息、状态标脏和表现事件副作用应只在边界内实现一次。

写入 `coin_count` 后仍需保留现有刷新与表现副作用：标记玩家状态脏，并继续发金币变化表现事件。

新增专门的技术验收 feature 覆盖迁移契约，建议路径为 `features/v102/role_attribute_coins.feature`。该 feature 只选代表路径覆盖初始化、获得金币、消费金币、支付给另一玩家、支付写入失败回滚、旧 `cash` profile 输入兼容、一个非法 `coin_count` 值硬失败、静态禁止 `player.cash`、缺失 Role 属性能力硬失败；现有玩家视角经济 feature 继续表述为“金币”，不批量改写为 `coin_count`。缺失属性能力与非法值都要在技术 feature 各保留一个代表失败场景，更细的缺失 Role、缺 set、`nil`、`NaN`、无穷大组合由单元测试覆盖。

本轮范围仅限局内经济金币真源迁移到 `coin_count`，不包含分享页金币显示或分享奖励。

## 后果

- `player_balance("金币")`、`add_player_cash`、`set_player_cash` 等现有金币入口需要改为读写角色 Fixed 属性 `coin_count`。
- 需要定义并复用 `coin_count` 属性 id 常量，避免实现层散落字符串。
- `set_player_cash` 需要收窄为初始化、fixture、恢复/调试加载等系统入口；普通玩法应使用加、减或转账操作。
- 直接读写 `player.cash` 的规则、AI、验收 step 和测试夹具需要迁移到统一金币入口或角色属性 fake。
- Synthetic AI 与测试 role adapter 需要补齐 `coin_count` raw fixed 属性读写能力。
- 测试 profile 的 `cash` 字段需要改为加载期兼容输入，不能成为运行时余额字段或输出字段。
- `Player.new` / `game_factory` 的 `balances["金币"]` 初始化路径和 `Player.cash` 字段需要删除，改为创建玩家后写入角色属性。
- 余额读取不能隐式初始化 `coin_count`；缺失属性必须暴露为创建/加入流程错误。
- 恢复/重连路径不能重复应用起始金币或粉丝团加成；已有 `coin_count` 直接作为当前余额。
- 金币写入边界需要保留非负余额校验，避免 `coin_count` 承载非法负数。
- 金币读写边界需要拒绝 `nil`、非 number、小数、`NaN` 和无穷大等非法值。
- 金币读写错误需要包含玩家标识、`coin_count` 和具体失败原因，便于定位宿主 Role 或 fake store 问题。
- 需要提供窄 Role 适配边界，避免 EggyAPI Role / AttrComp 结构扩散到规则层和测试。
- 规则模块的金币变化需要调用统一边界操作，不能各自读改写 `coin_count`。
- 租金/转账路径需要通过统一金币边界完成双边校验和结算，不能分散成不受保护的两次直接写属性。
- 无宿主事务能力时，转账失败需要尽力回滚已写余额，并在回滚失败时暴露 fatal 错误。
- 增加或更新静态 guard：`src/**` 严禁 `player.cash` / `.cash` 余额字段，`spec/**` 和 `tools/acceptance/**` 仅保留受控兼容/表现命名例外。
- 新增 `features/v102/role_attribute_coins.feature` 作为迁移验收入口，避免把所有玩家视角经济 feature 改成技术术语。
- 迁移后不得保留 `player.cash` 与 `coin_count` 两套余额并行同步。
