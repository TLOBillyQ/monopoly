# 蛋仔大富翁

## 调数值
1. 修改./design/目录下的xlsx表格
2. 运行export_xlsx.bat
3. 如果成功，./src/config下的对应lua文件会被覆盖

## 运行
1. 无图形模拟: `./run_all_ai.bat` 或 `lua main.lua --all-ai`
2. 日志为 `game.log`

## 平台入口
- Eggy：`LuaSource_大富翁/main.lua`（Eggitor/Eggy 环境入口）
- Headless：`main.lua`
- 可选参数：`--platform=eggy|headless` 或环境变量 `MONOPOLY_PLATFORM`
