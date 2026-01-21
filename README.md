# 蛋仔大富翁

## 调数值
1. 修改./design/目录下的xlsx表格
2. 运行export_xlsx.bat
3. 如果成功，./src/config下的对应lua文件会被覆盖。同时打新包到bin/windows下的Game.exe

## 运行
1. 2d图形demo： ./bin/windows/Game.exe
2. 无图形模拟: ./run_all_ai.bat
3. 日志为game.log.

## 平台入口
- Love2D：`main.lua`
- Eggy：`eggy_main.lua`
- Oasis：`oasis_main.lua`
- 可选参数：`--platform=love2d|eggy|oasis|headless` 或环境变量 `MONOPOLY_PLATFORM`
