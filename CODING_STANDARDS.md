# Coding Standards

## 命名与 Lua

- 文件、模块、函数、变量使用 `snake_case`；类名使用 `CamelCase`。
- `src/` 的数字判断与转换使用 `src.foundation.number` 的 `NumberUtils`，不使用 `tonumber` 或 `type(value) == "number"`。
- Eggy `Fixed` 参数写浮点字面量，例如 `30.0`。
- Eggy 沙盒的上下界使用 `math.maxval` / `math.minval`。
- 源文件保持 UTF-8、LF；不把生成物或运行时状态写进源码目录。

## 分层与依赖

- 模块职责和放置规则见 [`docs/architecture.md`](docs/architecture.md)。依赖约束以 `tools/packages/arch_view/config.json` 与 `test/guards/` 的可执行规则为准。
- `foundation` 是唯一 substrate，只含无玩法语义的通用能力，不依赖七层；`host` 是 L2 宿主适配层。
- `state` 与 `config` 不依赖上层；装配、mixin 安装和跨边界接线放在 `src/app`。
- 业务规则不接触 UI 节点或 Eggy API；宿主能力经 port 进入内层。
- `src/ui/manager` 是现有 host-EUI adapter 例外，不把该待遇扩散到其他 UI 模块。

## 宿主调用

- `EggyAPI.lua` / `EggyEditorAPI.lua` 是第三方注解线索，不是运行时事实；不得修改成项目实现。
- 宿主对象类名不稳定，业务逻辑不依赖 `type()` 返回的宿主类名。
- 已取证的宿主签名采用单次直调；`pcall` 只隔离宿主异常，成功按接口规定的明确信号判定（无返回值的调用回读状态翻转），不以“没有抛异常”为成功——宿主参数错误只记 ERROR 返回 nil，不抛异常。
- 宿主对象或方法缺失、调用异常与跳过路径必须留下可诊断日志，不静默吞掉。

## 测试

- 测试观察公共接缝和可见行为，不钉私有函数或内部调用次数；mock 只放在宿主、时间、随机数等系统边界。
- 改 `src/rules/**` 前先补或调整 behavior spec；产品外显行为放 `features/**/*.feature`，实现回归留在 `test/behavior/`。
- Acceptance step/driver 调真实 `src` 公共面，不复制业务常量或平行实现规则。
- 期望值来自规格、字面例子或独立真源，不用与实现相同的算法重算期望值。

## 断言层迁移(#74,ADR 0069 第一步)

迁移顺序是**先断言、后结构**:先把 `lu.*` / `luax.has_error` 换成真 luassert,`TestX = {}` 类结构原样留着;结构层(`describe` / `it`)换 busted 时再做第二步。两步之间的中间态允许进仓库,**不建「TestX 自动包成 describe」或「lu.* 转发到 luassert」的兼容层**——shim 出错的表现是测试静默通过。

### 断言对象怎么拿

- 文件头两行固定:`require("test.bootstrap").install_package_paths()` 之后 `local luassert = assert(require("test.support.luassert_loader").load())`,断言只走这个局部对象。
- loader 只从**项目工具缓存** `<repo>/.toolcache/luarocks/` 装载 `luassert`、其子模块及 `say`。未验证的 `package.loaded` 预注入即失败;装载期间的优先 searcher 按缓存文件显式 loadfile,避免 preload/searcher 绕过;后续调用复核已加载对象身份。解析路径在缓存中不代表预加载对象来自缓存。
- **不覆盖全局 `assert`**。旧运行器与 LuaUnit 的后端语义挂在全局 `assert` 上,覆盖它等于换执行后端而不是换断言词汇;`test/guards/lib/luassert_migration_pilot_guard.lua` 会扫 `_G.assert =` 一类写法。

### 译法对照(带陷阱)

| 迁移前 | 迁移后 | 陷阱 |
| --- | --- | --- |
| 标量 `lu.assertEquals(a, b)` | `luassert.is.equal(b, a)` | **参数顺序翻转**成 (expected, actual);`is.equal` 是 `==`,表只比身份 |
| 表 `lu.assertEquals(a, b)` | `luassert.is.same(b, a)` | LuaUnit 原本深比较表;luassert 的 `is.same` 忽略元表做深比较,不可换成身份比较 |
| `lu.assertNotEquals(a, b)` | 标量用 `luassert.is_not(b, a)`,表用 `luassert.is_not.same(b, a)` | 必须保住标量不等或表内容不等的原口径 |
| `lu.assertIs` / `lu.assertNotIs` | `luassert.is.equal` / `is_not`(同一引用) | 比的是引用,不是内容 |
| `lu.assertEvalToTrue(x)` | `luassert.truthy(x)` | **truthiness**,`1` / `"s"` / 表都通过 |
| `lu.assertEvalToFalse(x)` | `luassert.falsy(x)` | 只认 `nil` 与 `false` |
| `lu.assertTrue(x)` / `lu.assertFalse(x)` | `luassert.is_true(x)` / `is_false(x)` | **严格布尔**,`is_true(1)` 必红;别拿 `truthy` 顶替 |
| `lu.assertNil` / `lu.assertNotNil` | `luassert.is_nil` / `is_not_nil` | `is_nil(false)` 必红,`false` 不是 `nil` |
| `lu.assertIsTable` 等类型断言 | `luassert.is_table` 等 | `is_*` 家族即类型断言 |
| `lu.assertError(f, ...)` | `luassert.has_error(function() f(...) end)` | `lu.assertError` 把尾参**传给 f**、只验「抛没抛」;`has_error` **不转发参数**,给了 expected 就**精确比文本**。保住原义要显式包闭包、不顺手把期望值升级成精确文本——那是改期望值 |
| `lu.assertErrorMsgContains(sub, f, ...)` | `luassert.has_error.match(function() f(...) end, sub, 1, true)` | 旧断言转发尾参;新断言需闭包保住调用。`has_error` 是**精确文本**,子串必须走 `match` 且加 `1, true`(init + plain,禁用模式元字符) |
| `luax.has_error(f, msg)` | `luassert.has_error(f, msg)` | 同口径(先剥一层 `文件:行: ` 位置前缀,字符串精确比、表深比),换名即可 |
| `lu.assertStrContains(s, sub)` | `luassert.matches(sub, s, 1, true)` | 同上,plain 模式 |
| `lu.fail(msg)` | `lu.fail(msg)` 原样保留 | 见下方分桶口径 |

### 分桶口径(失败如何传播)

旧运行器只有一个引擎、一个退出码:`exit = (failures + errors > 0 or cases == 0) and 1 or 0`。断言层的抛错按消息分类:

- `lu.fail` 与 LuaUnit 断言的消息带 `LuaUnit test FAILURE: ` 前缀 → 计 **failures**;
- **luassert 的抛错是普通字符串**(`文件:行: <说明>`),不带该前缀 → 计 **errors**。

两个桶都**独立**作用于退出码,任何一种都不能被忽略:只 failed、只 errors,退出码都是非零。TAP 输出里两者都是 `not ok N - <类>.<用例>`。改动断言层后如果 `errors` 归零而 `failed` 也归零,先怀疑断言被吞了,而不是修好了。

### 试点范围与对账

- 本票试点 5 个文件(见 `test/guards/lib/luassert_migration_pilot_guard.lua` 的 `PILOT_FILES`),迁移前后用例集合必须逐类一致:45 例(9 / 9 / 5 / 13 / 4 + 5),基线由 `test/support/luassert_migration/test/test_luassert_assertion_contract.lua` 对账。
- 本票交付**不跳过特殊结构**:`setUp` 钩子、`multi_class_return.merge` 的多类 return、`runtime_baseline_guard` 补装、局部断言 helper 均保留,由迁移前后 diff 与真实 45 例对账验收,不设永久源码字面锚点、调用数量下界或 describe 禁令。
- 45 例逐类对账是断言阶段的可撤契约;后续结构迁移须替换为新运行器的同集合证据,不保留旧 Test 类或 helper 的内容嗅探规则。断言有效性由真实正负语义与非零退出钉住。
- `test/support/luax.lua` 不在本票范围内,其余 spec 继续用它。

### 诊断

Lua 编译期 `LUA_IDSIZE` 是 60,长 chunk 名在错误消息里被截成 `...<尾部>`,所以 TAP 的 `# <src> @ <line>` **不保证是完整路径**——对账与归因按文件名(basename),不要拿它当绝对路径去拼。

## mutate4lua manifest

- `src` 文件尾部的 mutate4lua manifest 与源码同属一个提交。
- 删除或改名函数后运行 `lua tools/cli.lua mutate <file> --update-manifest` 重生成；首次纳入差分基线先跑 `--mutate-all`。
- survived、timeout 或仅差分通过都不能证明全量基线。
