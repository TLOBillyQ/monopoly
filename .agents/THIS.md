# 项目上下文

## 运行环境

- Gameplay: monopoly/ richman
- 语言：Lua，环境说明见 `.agents/docs/eggy/lua_env.md` 与 `.agents/docs/eggy/lua_advanced.md`。
- 平台：蛋仔编辑器（Eggy），核心记忆见 `.agents/docs/eggy/eggy_lua_agent_memory.md`。
- 完成后测试：`agents/tests/`

## API 检索路径

按以下顺序查找，命中即停：

1. `.agents/docs/eggy/api/` 目录下的分类文件
2. `.agents/docs/eggy/EggyAPI.lua` 按关键词搜索（最多 5 次未命中则视为不存在）
3. 在线文档 <https://u5-creator.s3.game.163.com/manual/pc_md/overview.html>

不盲目通读，只按需检索。