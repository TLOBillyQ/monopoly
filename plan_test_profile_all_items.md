# test_profile 改造：全道具卡启动配置与黑市付费道具购买

本可执行计划是活文档。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"。

本文件必须遵循 `.agents/harness/PLANS.md` 维护。执行者只依赖当前工作树与本文件即可复现实施与验收过程。


## 目的 / 全局视角

改造前，编辑器快速测试档位 `ui_quick_all` 只给玩家 5 张道具卡（受限于 `inventory_slots = 5`），且金豆/乐园币余额偏低，无法在黑市中完整测试全部付费道具购买流程。改造后，编辑器启动即进入一个拥有全部 19 张道具卡的状态，且双方玩家均持有充足的金币（200000）、金豆（500）和乐园币（500），可以直接在黑市（道具商店）进行任意付费道具购买操作，而不需要手动积累资源。

验证方式：运行 `lua tests/regression.lua`（或 `lua5.4 tests/regression.lua`），预期 212 项全部通过；其中新增的两项测试 `profile_bootstrap_all_items_injects_all_cards` 和 `profile_bootstrap_all_items_has_paid_currency_balances` 分别验证 19 张道具卡注入与付费货币余额设置。


## 进度

- [x] (2026-03-02T12:32Z) 调研现有 test_profile 体系：`Config/TestProfiles.lua` 定义档位，`TestProfileBootstrap.lua` 应用启动配置，`GameplayRules.lua` 选择当前档位
- [x] (2026-03-02T12:33Z) 调研道具卡体系：19 张道具卡定义在 `Config/Generated/Items.lua`（id 2001-2019），背包上限 `inventory_slots = 5` 定义在 `Config/Generated/Constants.lua`
- [x] (2026-03-02T12:33Z) 调研黑市付费体系：`Config/Generated/Market.lua` 定义商品列表（道具商店 + 座驾商店），三种货币（金币/金豆/乐园币），`Config/RuntimePaidGoods.lua` 管理金豆和乐园币的付费购买面板
- [x] (2026-03-02T12:34Z) 设计方案：新增 `ui_quick_all_items` 档位，`TestProfileBootstrap` 支持 `inventory_slots` 覆写
- [x] (2026-03-02T12:35Z) 实现 `TestProfileBootstrap.lua` 支持 `player_cfg.inventory_slots` 覆写 `player.inventory.max_slots`
- [x] (2026-03-02T12:35Z) 新增 `ui_quick_all_items` 档位到 `Config/TestProfiles.lua`
- [x] (2026-03-02T12:35Z) 更新 `GameplayRules.lua` 默认 `test_profile` 为 `ui_quick_all_items`
- [x] (2026-03-02T12:36Z) 新增两项测试到 `tests/suites/test_profiles.lua`
- [x] (2026-03-02T12:36Z) 回归验证通过：212 项全绿


## 意外与发现

- 观察：`inventory_slots = 5` 是硬编码在 `Config/Generated/Constants.lua` 的全局常量，直接修改它会影响所有游戏逻辑（如黑市购买时判断背包已满）。
  证据：`src/game/core/player/Inventory.lua:17` 中 `max_slots` 从 `opts.constants.inventory_slots` 读取，市场购买逻辑用 `inventory.is_full(player)` 判断是否跳过道具类商品。
  结论：选择在 `TestProfileBootstrap` 中按玩家覆写 `max_slots`，不修改全局常量，从而仅影响测试档位而不改变游戏规则。

- 观察：`Inventory` 的 `max_slots` 是实例上的普通字段，可以在 `new()` 之后直接赋值覆写。
  证据：`src/game/core/player/Inventory.lua:22` — `self.max_slots = max_slots`，无 setter/getter 保护。
  结论：这使得覆写方案干净可行，不需要修改 `Inventory` 类的接口。


## 决策日志

- 决策：用 `player_cfg.inventory_slots` 覆写 `player.inventory.max_slots`，而不是修改全局 `Constants.inventory_slots`。
  理由：全局修改会影响非测试场景下的游戏平衡和黑市购买逻辑（如"背包已满时排除道具商品"的行为会在测试中失真）。per-player 覆写只影响被指定的测试档位。
  日期/作者：2026-03-02 / Codex

- 决策：新增独立档位 `ui_quick_all_items`，保留原有 `ui_quick_all` 不变。
  理由：`ui_quick_all` 已被现有测试用例验证，修改它会破坏 `_test_profile_bootstrap_quick_all_injects_resources` 等测试的断言。新档位可独立演进。
  日期/作者：2026-03-02 / Codex

- 决策：P1 和 P2 均给 200000 金币、500 金豆、500 乐园币。
  理由：黑市道具最贵的金币商品是 5000（遥控骰子卡 / 路障卡 / 流放卡），`limit = 5`，最大消耗约 6×5000 = 30000，200000 足够多轮测试。金豆最贵单品 50（均富卡 / 查税卡），500 金豆远超需求。乐园币同理。P2 也给同样余额以支持双方交互测试。
  日期/作者：2026-03-02 / Codex


## 结果与复盘

本轮已完成。新增 `ui_quick_all_items` 测试档位，让编辑器启动后 P1 持有全部 19 张道具卡且双方拥有充足的三种货币，可直接进行黑市付费道具购买测试。改动范围四个文件、改动行数极小：

1. `src/app/testing/TestProfileBootstrap.lua` — 增加 3 行支持 `inventory_slots` 覆写
2. `Config/TestProfiles.lua` — 增加一个新档位配置块
3. `Config/GameplayRules.lua` — 修改默认 `test_profile` 值和注释
4. `tests/suites/test_profiles.lua` — 增加 2 项测试

回归从 210 项增长到 212 项，全部通过。原有测试行为未受影响。


## 背景与导读

本仓库是一个类大富翁游戏，使用 Lua 编写。与本次改动相关的关键文件和模块如下。

`Config/TestProfiles.lua` 定义了多个测试档位（profile），每个档位包含地图模块引用和启动配置（bootstrap）。启动配置可以为玩家设定初始金币、货币余额和背包道具。

`src/app/testing/TestProfileBootstrap.lua` 在游戏创建后被调用，读取档位配置并应用到游戏实例上——设置玩家资金、货币、背包道具。

`Config/GameplayRules.lua` 中的 `test_profile` 字段决定编辑器启动时使用哪个测试档位。

`Config/Generated/Items.lua` 定义了 19 张道具卡（id 2001-2019），从免费卡到天使卡。每张卡有独立的 id、名称、级别（tier）、商店货币和价格。

`Config/Generated/Market.lua` 定义了黑市（道具商店 + 座驾商店）的商品列表，包括产品 id、货币类型、价格和购买上限。

`Config/RuntimePaidGoods.lua` 管理金豆和乐园币两种付费货币的购买面板配置。

`src/game/core/player/Inventory.lua` 实现了玩家背包，背包容量由 `max_slots` 字段控制（默认 5 格），`is_full()` 检查当前数量是否 >= `max_slots`。

`tests/suites/test_profiles.lua` 包含测试档位相关的回归测试。


## 工作计划

在 `TestProfileBootstrap.lua` 的 `_apply_player_bootstrap` 函数中，在清空并注入道具之前，先检查 `player_cfg.inventory_slots` 是否存在，若存在则覆写 `player.inventory.max_slots`。这使得测试档位可以声明大于默认 5 格的背包容量。

在 `Config/TestProfiles.lua` 中新增 `ui_quick_all_items` 档位。该档位使用与 `ui_quick_all` 相同的地图 `Config.Maps.UIQuickAll`，P1 配置 `inventory_slots = 19` 并列出全部 19 个道具卡 id（2001-2019），P1 和 P2 均配置 `cash = 200000`、`金豆 = 500`、`乐园币 = 500`。

更新 `GameplayRules.lua` 的 `test_profile` 为 `"ui_quick_all_items"`，并更新注释列表。

在 `tests/suites/test_profiles.lua` 新增两个测试函数：`_test_profile_bootstrap_all_items_injects_all_cards` 验证 19 张卡全部注入且背包容量被正确覆写；`_test_profile_bootstrap_all_items_has_paid_currency_balances` 验证金豆和乐园币余额对两位玩家均正确设置。


## 具体步骤

所有命令均在仓库根目录执行。

第一步：修改 `src/app/testing/TestProfileBootstrap.lua`，在处理 `items` 列表之前插入 `inventory_slots` 覆写逻辑：

    -- 在 _apply_player_bootstrap 函数中，items 块开头增加：
    if player_cfg.inventory_slots then
      player.inventory.max_slots = player_cfg.inventory_slots
    end

第二步：在 `Config/TestProfiles.lua` 的 profiles 表中，`ui_quick_status3d` 之后新增 `ui_quick_all_items` 条目，包含全部 19 个道具 id 和三种货币余额。

第三步：修改 `Config/GameplayRules.lua` 中 `test_profile = "ui_quick_all"` 为 `test_profile = "ui_quick_all_items"`。

第四步：在 `tests/suites/test_profiles.lua` 添加两个新测试函数并注册到 tests 列表。

第五步：运行回归测试验证：

    lua5.4 tests/regression.lua

预期输出：

    All regression checks passed (212)
    dep_rules ok
    tick ok
    forbidden_globals ok


## 验证与验收

验收标准一：运行 `lua5.4 tests/regression.lua`，212 项全部通过，其中新增的两项在变更前不存在、变更后通过。

验收标准二：新档位 `ui_quick_all_items` 启动后，P1 持有 19 张道具卡（id 2001-2019），P1 背包容量为 19。

验收标准三：新档位启动后，P1 和 P2 的金豆余额为 500、乐园币余额为 500、金币为 200000，足以覆盖黑市全部付费道具的多次购买。

验收标准四：原有测试 `profile_bootstrap_quick_all_injects_resources` 和 `profile_bootstrap_quick_bankruptcy_applies_tile_override` 仍然通过，说明旧档位未受影响。


## 可重复性与恢复

本计划可重复执行。所有改动均为增量式（新增配置条目、新增测试、新增少量逻辑），不删除和修改任何已有功能代码。若需回退，删除新增的 `ui_quick_all_items` 档位、移除 `inventory_slots` 覆写逻辑、恢复 `test_profile` 为 `"ui_quick_all"`、删除两项新测试即可。


## 产物与备注

回归测试输出：

    All regression checks passed (212)
    dep_rules ok
    tick ok
    forbidden_globals ok


## 接口与依赖

本次改动的接口变更仅一处：`TestProfileBootstrap._apply_player_bootstrap` 现在识别 `player_cfg.inventory_slots` 字段。该字段为可选项，不填则行为与之前完全一致。

新增档位 `ui_quick_all_items` 使用现有地图 `Config.Maps.UIQuickAll`，不引入新依赖。

依赖的测试命令：`lua5.4 tests/regression.lua`（或环境中的 `lua tests/regression.lua`）。
