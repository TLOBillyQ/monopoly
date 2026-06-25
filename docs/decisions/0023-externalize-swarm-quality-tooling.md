---
kind: adr
status: implemented
owner: architecture
last_verified: 2026-06-25
---
# ADR 0023 - 将 swarm 质量工具从 vendored 子模块外置为「提示词规范 + 钉定参考实现」

## 实现状态

已实现。五个 swarm 质量工具由 `swarmforge/tools.lock` 钉定，wrapper 通过 `tools/shared/tool_cache.lua` 按需 bootstrap 到 gitignored `.swarmforge/tools/<tool>@<sha>/`；五个 `vendor/*` gitlink 与 `.gitmodules` 条目已移除，`vendor/third_party/` 保持不动。

## 背景

`vendor/` 下有 6 项。`vendor/third_party/`(Behavior、NavMesh、UIManager、Bincore、ClassUtils、Utils)是游戏运行时的 Eggy 宿主库,**不在本决定范围**。其余 5 个全是项目自有的 Lua 质量工具 git 子模块:`mutate4lua`、`crap4lua`、`dry4lua`、`arch_view`、`acceptance4lua`(APS)。

按代码确认的真实消费者:

- `mutate4lua` —— 只有 architect 收尾流程调用(role 的「语言变异 → DRY → soft Gherkin」序列),**不在任何 make 目标**。
- `dry4lua` —— 同上,只有 architect。
- `crap4lua` —— `tools/quality/crap.lua` → `require("crap4lua.cli")`,在 `make verify` 的 `crap_collect` 车道。
- `arch_view` —— `tools/quality/arch.lua` → `require("arch_view.cli")`,在 `make verify` 的 `arch` 车道。
- `acceptance4lua`(APS)—— `tools/acceptance/` 全套,是 `make acceptance` 核心。

也就是说真正「只有 AI swarm 用」的是 `mutate4lua` + `dry4lua`;另外三个是任何人跑 `make verify`/`make acceptance` 都依赖的项目永久质量门。

参照 `github.com/unclebob/swarm-forge`:其工具不是 vendored 二进制,而是**角色提示词里描述的活动**;编排本体是 Clojure(babashka,即本仓库 `swarmforge/scripts/*.bb`)+ shell。上游并没有现成的「clj/go 多实现工具」。

当前 `engineering.prompt` 明文要求「Language tools are project-local: vendor/mutate4lua... Do not replace vendored Lua tools」,即把工具钉死为仓库内子模块。本决定改变这一架构姿态:把这 5 个工具移出主仓库依赖图,提升为提示词层的可移植规范,实现按需获取。

## 决策

### 1. 范围:5 个全部外置
`mutate4lua`、`dry4lua`、`crap4lua`、`arch_view`、`acceptance4lua` 全部移出主仓库,不再作为 vendored 子模块存在。主仓库做到「零 swarm 工具」。`vendor/third_party/` 保持不动。

### 2. 机制:提示词承载可移植规范 + 钉定参考实现(按需获取)
每个工具拆成两层:

- **工具规范(tool spec)**:CLI 契约 + manifest 格式 + 算法要点,语言无关,承载在提示词域,是可移植的真相源。
- **参考实现(reference implementation)**:一个钉定版本的实际实现(当前为 Lua,未来可有 clj/go),不进主仓库树,由 bootstrap 按需拉取到 gitignored 缓存。

不采用「agent 每次从规范现场重建工具」:`make verify`/`make acceptance` 由人类/CI 运行时根本没有 agent 去重建 `crap`/`arch`,且重建无法稳定复现 `mutate4lua` 的 manifest。

### 3. 版本钉定:仓库内 lockfile
新增仓库内 lockfile(推荐 `swarmforge/tools.lock`),每个工具一行 `repo + commit SHA`(可选 checksum)。bootstrap 按 SHA 获取。版本与代码分离、可审计、可复现;升级工具 = 改一行 lock 并走正常评审。子模块原本靠超级仓库树里的 gitlink SHA 钉版本,删除后由 lockfile 顶替这一职责。

### 4. 获取时机:bootstrap 按需自动
在 `tools/shared/bootstrap.lua` 增加 `ensure_tool(name)`:读 lockfile → 查 gitignored 缓存(`.swarmforge/tools/<tool>@<sha>`,随 orchestration 状态一起保留、不被例行清理)→ 缺则按 SHA clone → 注入 `package.path`。各 wrapper(`tools/quality/{crap,arch,mutate,dry}.lua`、`tools/acceptance/*`)调用前先 `ensure_tool`。`make verify`/`make acceptance` 开箱即跑:首跑需网络,之后离线命中缓存。可另加 `make bootstrap` 仅用于预热缓存。

### 5. 规范位置:constitution 域内每工具一份
每个工具一份语言无关规范放提示词域(推荐 `swarmforge/constitution/tools/<tool>.prompt`),写 CLI 契约 + manifest 格式 + 算法要点;`engineering.prompt` 由「钉死 vendor 路径」改为「指向各工具规范 + 描述 bootstrap 获取模型」。外部实现仓库携带 conformance 测试,防止规范与实现漂移。

### 6. 多实现语义:单一权威实现 + 重基线事件
lockfile 同时只钉**一个权威实现**,manifest 由它定义。clj/go 等是「备选实现」,可读可跑,但**切换权威实现 = 一次显式「重基线全部 manifest」事件**(类比工具大版本升级),不要求跨实现字节一致。规范写到「足以重写一个兼容实现」的深度,但承认 `semanticHash` 的权威归当前钉定实现。这避免了把哈希算法钉到字节级跨语言一致的极高成本。

### 7. 旧模型产物:平移到新模型
`tools/quality/vendor_submodules.lua`(跨 worktree 子模块健康检查)改写/替换为「工具缓存 + lockfile 健康检查」(校验 lockfile 完整、缓存 SHA 命中、可按需获取)。断言「工具是 vendored submodule」的质量验收 feature(`tools/acceptance/steps/quality/setup_steps.lua`、`bootstrap_steps.lua`)改为断言「工具按 lockfile bootstrap 到位」。`CLAUDE.md`「submodule status 全部前缀非 -」常驻规则与 `engineering.prompt` 同步改写。保住「工具就位」的等价质量门与诊断能力。

### 8. 落地:一次性全迁,但钉死当前 SHA 使迁移 manifest-中性
五个工具在单个分支上一次性外置。风险缓解:`tools.lock` **钉死各工具当前 submodule 的 gitlink SHA**(如 `mutate4lua` 当前为 `4b3073bd`),使 bootstrap 出的参考实现与今天的 vendored 实现字节一致 →**现有内嵌 manifest 全部仍然有效,本次迁移无需重基线**。重基线只在未来某次刻意升级 lockfile 时才触发。合入前用全量 `make verify` + `make acceptance` 双门禁把关。

## 术语

为避免污染游戏域的 `CONTEXT.md`,本机制词汇就地记录在此:

- **工具规范 / tool spec**:提示词域里语言无关的工具契约(CLI + manifest 格式 + 算法),可移植真相源。
- **参考实现 / reference implementation**:lockfile 当前钉定、对 manifest 有权威的那个实际实现。
- **备选实现 / alternate implementation**:其他语言(clj/go)的实现,可用但非权威;成为权威需走重基线。
- **`tools.lock`**:仓库内工具版本钉定文件(repo + SHA)。
- **重基线 / re-baseline**:切换权威实现后,用新实现重新生成全部内嵌 manifest 的显式事件。

## 影响

- `make verify`/`make acceptance` 从「依赖 vendored 子模块」变为「依赖 bootstrap 按需获取」:首跑需网络,之后离线命中 `.swarmforge/tools/` 缓存。air-gapped CI 需预热缓存。
- 主仓库 `.gitmodules` 删 5 项、`git submodule status` 不再含这 5 个;fresh checkout 对游戏开发者更干净(不再 `--recurse-submodules` 拉质量工具)。
- 因第 8 点钉死当前 SHA,内嵌 mutate manifest 不变,迁移本身可过现有差分变异。
- 工具升级从「改 gitlink + 提交子模块指针」变为「改 `tools.lock` 一行」;若升级跨越语义变化,需配套一次重基线。
- 为「未来用 clj/go 重写某工具」铺了路:只要新实现通过 conformance 测试并成为权威(走重基线),即可换。

删除本机制(回退到子模块)需:恢复 5 个 `.gitmodules` 条目、还原 wrapper 的 `require` 路径、删 lockfile/bootstrap 获取逻辑、还原健康检查与验收 feature。

## 范围外

- 不动 `vendor/third_party/`(游戏运行时)。
- 不重写这些工具本身的功能,也不在本决定内真的产出 clj/go 实现——只是把架构改成「允许」多实现。
- 不改变 APS 可移植契约与项目专属适配器(entrypoint generator、runtime、step handlers、runner adapter)之间的既有分工;`acceptance4lua` 外置后,APS 契约仍来自 `unclebob/Acceptance-Pipeline-Specification`,项目专属部分仍留在仓库内。
- 不定义 `make bootstrap` 是否强制(留实现阶段决定;默认按需自动获取已足够)。

## 取舍

- **不保留 vendored 子模块**:子模块把「只有 AI swarm 用」的工具压进游戏仓库依赖图,污染 `submodule status` 与 fresh checkout,且升级需提交子模块指针。
- **不采用纯 agent 现场重建**:无法稳定复现 mutate manifest,且人类/CI 跑 make 时无 agent 重建 crap/arch。
- **不追求跨实现字节一致**:把 `semanticHash` 钉到字节级跨语言一致的规范与一致性测试成本极高,收益不抵;单一权威实现 + 重基线已满足复现需求。
- **不用浮动 latest main**:会让 mutate manifest 跨会话漂移,与复现目标矛盾。
- **未采纳分批试点(架构建议)**:架构上建议先迁 blast radius 最小的 `mutate4lua` 验证整套闭环再扩,但采纳一次性全迁以更快到达终态;靠「钉死当前 SHA + 双门禁」把大爆炸式迁移的风险压到 manifest-中性。
