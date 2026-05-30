---
kind: guide
status: deprecated
owner: quality
last_verified: 2026-05-22
---
# Lua 5.4 单一工具链迁移 Playbook

**用途**：一次性执行 ADR 0007 的环境迁移。**已于 2026-05-22 由 coder 执行完毕**，本文 `status: deprecated`，仅作历史记录保留。

**决策依据**：`docs/decisions/0007-lua-5.4-only-toolchain.md`

**预计时间**：10-15 分钟（含 luarocks 源码编译 2-3 分钟）

**回滚成本**：中等。Phase 1-3 brew 操作可逆（重装 5.5 + 重新装 gnuplot）；Phase 5 代码改动 `git revert` 即可。已建议每 Phase 单独 commit。

---

## Phase 0 — 起点状态（执行前确认）

期望本机当前状态：

```bash
brew list | grep -E '^lua'        # 期望：lua, lua@5.4, lua-language-server, luacheck, luarocks
which lua                          # 期望：/opt/homebrew/bin/lua
lua -v                             # 期望：Lua 5.5.0
brew uses --installed lua          # 期望：gnuplot, luarocks
ls ~/.luarocks/lib/luarocks/       # 期望：rocks-5.4/ 已存在（12 个 rocks）
```

如有偏离请先排查再继续。

## Phase 1 — 卸 lua 5.5 链路

```bash
brew uninstall gnuplot
brew uninstall luarocks
brew uninstall lua
```

校验：

```bash
brew list | grep -E '^lua'              # 应只剩：lua@5.4, lua-language-server, luacheck
brew uses --installed lua@5.4           # 应只剩：luacheck
ls /opt/homebrew/bin/lua* 2>/dev/null   # 应只剩 lua-language-server（lua / luac 软链消失）
```

## Phase 2 — `lua@5.4` 上岗

```bash
brew link lua@5.4
```

（`lua@5.4` 是 keg-only，不需要 `--force`：此刻没有 `lua` formula 与之冲突。）

校验：

```bash
lua -v                                  # 期望：Lua 5.4.8
which lua                               # 期望：/opt/homebrew/bin/lua
readlink /opt/homebrew/bin/lua          # 期望：../Cellar/lua@5.4/5.4.8/bin/lua
ls /opt/homebrew/bin/lua5.4             # 期望：存在
```

## Phase 3 — 源码安装 luarocks against lua@5.4

```bash
LR_VERSION=3.13.0
cd /tmp
curl -fsSL "https://luarocks.org/releases/luarocks-${LR_VERSION}.tar.gz" | tar xz
cd "luarocks-${LR_VERSION}"
./configure \
    --prefix="$HOME/.luarocks" \
    --with-lua="/opt/homebrew/opt/lua@5.4" \
    --lua-version=5.4 \
    --rocks-tree="$HOME/.luarocks"
make
make install
```

PATH 配置（写入 `~/.zshrc`，幂等防重复）：

```bash
# 检查是否已经存在
grep -q '\.luarocks/bin' ~/.zshrc || echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

校验：

```bash
which luarocks                          # 期望：/Users/<you>/.luarocks/bin/luarocks
head -1 "$(which luarocks)"             # 期望：#!/opt/homebrew/opt/lua@5.4/bin/lua5.4
luarocks --version                      # 期望：第一行 LuaRocks 3.13.0，第二行 "using Lua 5.4"
luarocks config rocks_trees             # 期望：只有 user 一棵树指向 ~/.luarocks
```

## Phase 4 — 补齐 5.4 rocks（只缺 argparse）

```bash
luarocks install argparse
luarocks list                           # 期望：13 个 rocks 全齐
```

完整 13 个：`argparse busted datafile dkjson lua-term lua_cliargs luacov luafilesystem luassert luasystem mediator_lua penlight say`

## Phase 5 — 项目代码改动（commit 1：toolchain 解耦）

**改动 5a** — `tools/quality/verify_full.lua`

在现有 `_LUA54_BIN_CANDIDATES` 块之后（约 line 23 后）插入：

```lua
local _BUSTED54_BIN_CANDIDATES = {
  os.getenv("HOME") .. "/.luarocks/bin/busted",
  "/opt/homebrew/bin/busted",
}

local function _resolve_busted54()
  local override = os.getenv("BUSTED54_BIN")
  if override ~= nil and override ~= "" then
    return override
  end
  for _, candidate in ipairs(_BUSTED54_BIN_CANDIDATES) do
    if common.path_exists(candidate) then
      return candidate
    end
  end
  return "busted"
end
```

改 line 216-217（contract / guards lane 定义）。原代码：

```lua
local lanes = {
  { label = "contract", cmd = "busted --run contract" },
  { label = "guards", cmd = "busted --run guards" },
}
```

改为：

```lua
local busted_bin = _resolve_busted54()
local lanes = {
  { label = "contract", cmd = common.shell_quote(busted_bin) .. " --run contract" },
  { label = "guards", cmd = common.shell_quote(busted_bin) .. " --run guards" },
}
```

**改动 5b** — `.agents/skills/verify/SKILL.md`

把 `lua tools/quality/lint.lua` 显式化为 `lua5.4 tools/quality/lint.lua`，未来即便 brew 出 `lua` 5.6 link 上来也不会被偷换。

**验证（必做）** — 工具链改动按 [memory: feedback_toolchain_verification] 走端到端：

```bash
lua tools/quality/verify_full.lua
```

期望：所有 lane PASS。

commit 信息建议：`chore(toolchain): resolve busted via 5.4 user-tree (ADR 0007)`

## Phase 6 — 残留清扫（commit 0：纯环境清理，无代码 diff）

```bash
rm -rf /opt/homebrew/lib/luarocks/rocks-5.5
rm -rf /opt/homebrew/share/lua/5.5
rm -rf /opt/homebrew/lib/lua/5.5
# 旧 5.5 链路 luarocks 装的 wrapper（brew uninstall 不会清）
rm -f /opt/homebrew/bin/busted
rm -f /opt/homebrew/bin/luacov
rm -f /opt/homebrew/bin/luacov~
brew autoremove
brew cleanup
```

校验：

```bash
find /opt/homebrew -name 'rocks-5.5' -o -name 'lua/5.5' 2>/dev/null   # 期望：空
brew list | grep -E '^lua'                                            # 期望：lua@5.4, lua-language-server, luacheck
```

## Phase 7 — 端到端验收清单

| # | 检查 | 命令 | 期望 |
|---|---|---|---|
| 1 | lua 版本 | `lua -v` | `Lua 5.4.8` |
| 2 | luarocks 走 5.4 | `luarocks config lua_version` | `5.4` |
| 3 | busted 走 5.4 | `head -1 $(which busted)` | shebang 含 `lua@5.4` |
| 4 | rocks 全齐 | `luarocks list | grep -c '(installed)'` | 13 |
| 5 | brew 干净 | `brew list \| grep -E '^lua'` | 仅 `lua@5.4 lua-language-server luacheck` |
| 6 | 5.5 残留 | `find /opt/homebrew -name 'rocks-5.5' -o -path '*/lua/5.5'` | 空 |
| 7 | lint 跑 5.4 | `lua tools/quality/lint.lua` | PASS |
| 8 | verify_full 全 lane | `lua tools/quality/verify_full.lua` | 全 PASS |

8 项全绿即迁移完成。

## 回滚

**Phase 1-3 brew 操作**：

```bash
brew unlink lua@5.4
brew install lua            # 拽回 5.5
brew install luarocks       # 重装 brew 版（自动绑 5.5）
brew install gnuplot
rm -rf ~/.luarocks/bin/luarocks  # 移除源码版（rocks 树保留）
# 5.5 rocks 树需重新装：luarocks install <each>
```

**Phase 5 代码改动**：

```bash
git revert <commit-sha-of-toolchain-decouple>
```

## 完成后

1. ADR 0007 `status: draft` → `stable`，`last_verified` 改为执行日期
2. 本 guide `status: draft` → `deprecated`
3. （可选）`AGENTS.md` 补一段"环境约定"：lua@5.4 唯一来源、luarocks 在 ~/.luarocks、未来出现 rocks-5.x 旁路视为告警
