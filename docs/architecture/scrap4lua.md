# scrap4lua

`scrap4lua` 是面向 Monopoly 的语义导航工具：回答“概念 X 先看哪些代码、测试、文档”，不负责边界判罚，也不替代 `arch_view` / `crap4lua` / `mutate4lua`。

## 适合回答的问题

- `choice owner_role_id` 相关代码和文档分散在哪
- `bankruptcy feedback` 先读哪个 Port、哪个规则实现、哪些测试
- 旧路径 `src/game/*` 迁移到现路径后，该从哪继续读

## 入口

```sh
lua tools/quality/scrap.lua --help
lua tools/quality/scrap.lua index --out tmp/scrap_index.json
lua tools/quality/scrap.lua find --query "choice owner_role_id"
lua tools/quality/scrap.lua clusters --out tmp/scrap_clusters.json
lua tools/quality/scrap.lua viewer --out-dir tmp/scrap_view
```

`tmp/...` 会映射到系统临时目录下的 `monopoly_scrap/`。

裸调用 `lua tools/quality/scrap.lua` 默认直接导出并打开 viewer，等价于 `viewer --out-dir tmp/scrap_view --open`。

## Monopoly 适配层做了什么

- 默认索引 `src/**/*.lua`、`tests/**/*.lua`、`docs/architecture/**/*.md`
- 自动加载 `tests/support/migration_pairs.lua`，把旧 `src/game/*` 概念映射到现路径模块
- 查询排序默认 `code > test > doc`
- 输出稳定 JSON，便于后续接静态 viewer 或 TUI
- Monopoly 提交态 viewer 快照保留在 `tools/quality/scrap/viewer/`

## 输出说明

### `index`

输出 `ScrapIndex` JSON，主要字段：

- `metadata`
- `scraps`
- `terms`
- `themes`
- `edges`
- `warnings`

### `find`

输出：

- `query`
- `expanded_terms`
- `matches`
- `explanations`

每个 match 至少包含 `path`、`title`、`level`、`collection`、`score`、`reasons`。

### `viewer`

导出静态 bundle：

- `index.html`
- `styles.css`
- `script.js`
- `scrap_index.json`
- `scrap_data.js`

支持：

```sh
lua tools/quality/scrap.lua viewer --out-dir tmp/scrap_view
lua tools/quality/scrap.lua viewer --in-json tmp/scrap_index.json --out-dir tmp/scrap_view
```

viewer 是搜索优先的阅读台：左侧输入概念词，中间查看匹配 scraps，右侧检查 terms / requires / 同路径符号 / 相关 scraps。

如果要刷新仓库内提交的快照：

```sh
lua tools/quality/scrap.lua viewer --out-dir tools/quality/scrap/viewer
```

## 边界

- 它是阅读辅助，不是 CI gate
- 第一版只做 CLI + JSON
- Theme 由确定性的共现聚类生成，不做在线学习
