# 定位榜单bug

实际上线榜单未接入，查EggAPI和在线文档 https://u5-creator.s3.game.163.com/manual/mobile/README.html ，确认是lua侧问题还是编辑器侧问题

## 诊断结论

- Lua 已在 `src/app/host_integrations/leaderboard.lua` 写入整数存档 1001（胜利次数）和 1002（总资产），并由 `gm.finished` 事件接线。
- `Role.get_archive_by_type`、`Role.set_archive_by_type` 的签名与 `EggyAPI.lua` 及在线 API 文档一致；相关行为测试通过（16 个接线测试、271 个 app 行为测试）。
- 在线文档要求通过 `GameAPI.request_archive()` 上传玩家存档；当前代码没有调用该 API，这是 Lua 侧导致线上榜单不更新的缺口。
- 编辑器仍须配置整数型自定义存档 1001/1002、将榜单数据源设为对应“自定义进度”，并正式发布/更新地图；仓库没有编辑器配置可供核验。
