---
title: EditorCli 使用指引
source: https://u5-creator.s3.game.163.com/manual/pc_md/editor_cli.html
fetched: 2026-05-11
---

## EditorCli 使用指引

> 面向游戏开发者的命令行工具，用于与编辑器交互，支持状态查询、日志查看、远程执行 Lua 代码等操作。

---

## 简介

EditorCli 是一个命令行工具，让你在终端里就能操控编辑器。主要能做三件事：

- **查看状态和日志** ：确认编辑器是否在线、拉取报错日志、实时监听日志输出
- **远程执行 Lua 代码** ：在编辑器中运行脚本，实现场景搭建、UI 编辑、玩家操控、截图等操作
- **配合 AI 实现自动化** ：EditorCLI 可以给 AI 调用，通过编写 Skill，让 AI 通过 EditorCLI 自动完成场景生成、批量修改、调试等重复性工作

---

## 命令速查表

| 命令 | 用途 | 典型场景 |
| --- | --- | --- |
| `status` | 查看编辑器运行状态 | 确认编辑器是否在线、是否响应 |
| `logs` | 获取历史日志 | 排查崩溃、查看报错堆栈 |
| `watch` | 实时监听日志 | 调试运行时行为、监控特定操作 |
| `clear-logs` | 清空日志缓冲区 | 清理旧日志，准备新一轮调试 |
| `exec` | 远程执行 Lua 代码 | 热修数据、动态调试、查询运行时状态 |

---

## 前置准备

EditorCli 通过与编辑器通信实现操控编辑器。使用前需要完成两步：

1. 编辑器开启端口
2. 打开终端连接验证

---

### 1. 开启编辑器端口

首先，确保编辑器已启动，并在编辑器中启用 Editor Cli。

> **注：** 非必要，不要修改端口设置。

---

### 2. 快速上手：打开终端，输入第一条命令

编辑器端口开启后，就可以用命令行工具与编辑器通信了。如果你之前没用过命令行，跟着下面几步走就行。

#### 2.1 打开 PowerShell

按键盘上的 `Win + R` ，输入 `powershell` ，然后回车。你会看到一个蓝底或黑底的窗口，这就是命令行终端。

你也可以用 `cmd` （命令提示符），操作方式一样。本文以 PowerShell 为例。

#### 2.2 进入工具所在目录

`editor-cli.exe` 是一个独立的可执行文件，你需要先让终端"进入"它所在的文件夹，默认在 "编辑器安装目录/bin/editor-cli.exe"。

假设 `editor-cli.exe` 在 `C:\Eggitor\bin\` 目录下：

```powershell
# 切换盘符（如果工具在 E 盘）
C:

# 进入目录
cd C:\Eggitor\bin\
```

输入后回车，终端的当前路径就会变成 `C:\Eggitor\bin\` 。你可以用以下命令确认：

```powershell
# 查看当前所在目录
pwd

# 查看当前目录下有哪些文件（应该能看到 editor-cli.exe）
dir
```

#### 2.3 验证连接

现在输入第一条命令，检查是否能连上编辑器：

```powershell
.\editor-cli.exe status
```

> **注意：** 在 PowerShell 中运行当前目录下的 exe，需要在文件名前加 `.\` 。如果是在 cmd 中，直接输入 `editor-cli.exe status` 即可。

如果看到类似以下输出，说明连接成功，可以继续使用后续命令了：

```
Editor Status:
  Running          True
  Edit Mode        True
  In Game Runtime  False
  Map Name         AISkillMap
  Map ID           69f2f39d293aeb4c48ab43ca
  editor_status    idle
```

如果看到连接失败（如"由于目标计算机积极拒绝，无法连接"），请检查：

- 编辑器是否已启动
- EditorCli 代理端口是否已开启
- 端口号是否为 `19836` （如不同，使用 `--port` 指定，见下一节）

#### 2.4 命令格式说明

所有命令都遵循以下格式：

```
editor-cli.exe [全局选项] <子命令> [子命令选项]
```

- **全局选项** （如 `--host` 、 `--port` 、 `--json` ）放在子命令前面
- **子命令** （如 `status` 、 `logs` 、 `exec` ）决定你要做什么
- **子命令选项** （如 `--limit` 、 `--level` ）放在子命令后面

举个例子：

```powershell
# 完整格式
.\editor-cli.exe --host 127.0.0.1 --port 19836 logs --limit 20 --level error

# 日常使用（省略默认值）
.\editor-cli.exe logs -n 20 -l error
```

#### 2.5 小技巧

| 技巧 | 说明 |
| --- | --- |
| `Tab` 键自动补全 | 输入文件名前几个字母后按 Tab，会自动补全 |
| `↑` 方向键 | 调出上一条输入过的命令，不用重复敲 |
| `Ctrl + C` | 终止正在运行的命令（比如停止 watch） |
| 右键粘贴 | 在 PowerShell 中，选中文本后按右键即可粘贴 |

---

### 3. 自定义连接地址

如果编辑器运行在其他机器上，或端口不同：

```powershell
# 指定 IP 和端口
.\editor-cli.exe --host 192.168.1.100 --port 19999 status

# 仅指定端口
.\editor-cli.exe --port 19999 status
```

---

## 命令详解

### status — 查看编辑器状态

**作用：** 检查编辑器是否在线、能否正常响应。这是最常用的"探活"命令。

**调试场景：**

- 不确定编辑器是否卡死时，快速确认
- 脚本/自动化流程中作为健康检查

**基本用法：**

```powershell
editor-cli.exe status
```

**输出示例：**

```
Running          True
  Edit Mode        True
  In Game Runtime  False
  ……itor status: running
Uptime: 2h 15m
Active documents: 3
```

**获取 JSON 格式（便于脚本解析）：**

```powershell
editor-cli.exe --json status
```

---

### logs — 获取日志

**作用：** 拉取编辑器后端的历史日志，支持按级别、数量、时间过滤。

**调试场景：**

- 游戏崩溃后，拉取崩溃前的 error 日志定位问题
- 查看最近的 warning，排查潜在隐患
- 按时间范围缩小日志范围，聚焦特定操作时段

**基本用法：**

```powershell
# 获取最近 50 条日志
editor-cli.exe logs --limit 50

# 简写
editor-cli.exe logs -n 50
```

**按级别过滤：**

```powershell
# 只看错误日志（排查崩溃）
editor-cli.exe logs --level error

# 只看警告及以上
editor-cli.exe logs --level warning

# 简写
editor-cli.exe logs -l error
```

可选级别： `error` 、 `warning` 、 `info` 、 `debug`

**按时间过滤：**

```powershell
# 只看某个时间点之后的日志（Unix 时间戳）
editor-cli.exe logs --since 1714400000
```

**组合使用：**

```powershell
# 最近 20 条 error 日志
editor-cli.exe logs -n 20 -l error

# 某时间点之后的所有 warning
editor-cli.exe logs -l warning --since 1714400000
```

---

### watch — 实时监听日志

**作用：** 类似 Linux 的 `tail -f` ，持续输出编辑器日志，实时观察运行状态。

**调试场景：**

- 在编辑器中执行某个操作，同时观察日志输出，定位触发时机
- 复现一个偶发 bug 时，开着 watch 等待错误出现
- 性能分析时观察特定模块的日志刷屏频率

**基本用法：**

```powershell
# 监听所有日志
editor-cli.exe watch
```

**按级别过滤：**

```powershell
# 只监听 error 和 warning
editor-cli.exe watch --level warning

# 简写
editor-cli.exe watch -l error
```

按 `Ctrl + C` 停止监听。

---

### clear-logs — 清空日志缓冲区

**作用：** 清空编辑器内存中的日志缓冲区。

**调试场景：**

- 准备复现一个 bug 前，先清空旧日志，确保拉到的都是相关日志
- 长时间运行后日志过多，清理后重新开始

**用法：**

```powershell
editor-cli.exe clear-logs
```

**典型工作流：**

```powershell
# 1. 清空旧日志
editor-cli.exe clear-logs

# 2. 在编辑器中执行要调试的操作

# 3. 拉取新产生的日志
editor-cli.exe logs -n 50
```

---

### exec — 执行 Lua 代码

**作用：** 远程在编辑器环境中执行 Lua 代码。这是最强大的调试命令，可以在编辑时操作场景和 UI，也可以在调试时操控游戏内玩家。

> ⚠️ **重要：** `exec` 命令不会在终端直接输出 Lua 返回值。如果需要获取数据，请使用 `EditorAPI.log()` 将结果写入日志，然后读取项目根目录的 `log.txt` 文件。

**调试场景：**

- **开启/关闭试玩** ：一键启动游戏调试，无需在编辑器里点按钮
- **查询场景数据** ：获取场景中所有单位、选中单位、单位属性
- **操控游戏内玩家** ：瞬移、移动、跳跃、广播自定义事件
- **搭建场景** ：批量创建组件、设置缩放和旋转
- **编辑 UI** ：创建文本/按钮/图片节点、修改属性
- **截图** ：远程截取编辑器画面

---

## 编辑时 API（Idle 状态）

> 📖 编辑时 API 文档： [点击查看](https://u5-creator.s3.game.163.com/manual/pc_md/lua/EggyEditorAPI.html)

### 开启 / 关闭试玩

```powershell
# 开始试玩
.\editor-cli.exe exec "EditorAPI.run_game()"

# 停止试玩
.\editor-cli.exe exec "EditorAPI.stop_game()"
```

开始试玩后，编辑器会进入 `entering` → `map-loading` → `playing` 的过渡过程。可以用 `status` 命令轮询等待进入 `playing` 状态后再执行游戏内操作。

### 查询场景单位

```powershell
# 获取场景中所有单位的 ID
.\editor-cli.exe exec "local ids = EditorAPI.get_all_unit_ids(); for i=1,#ids do EditorAPI.log(tostring(i) .. ': id=' .. tostring(ids[i])) end"

# 获取当前选中的单位
.\editor-cli.exe exec "local ids = EditorAPI.get_selected_unit_ids(); for i=1,#ids do EditorAPI.log(tostring(i) .. ': id=' .. tostring(ids[i])) end"

# 按名称搜索单位
.\editor-cli.exe exec "local units = EditorAPI.query_scene_units('Enemy', false); for i=1,#units do EditorAPI.log(tostring(i) .. ': ' .. tostring(units[i])) end"

# 获取指定单位的详细数据
.\editor-cli.exe exec "local d = EditorAPI.get_scene_unit_data(123); EditorAPI.log('name=' .. d.name .. ' pos=' .. tostring(d.position[1]) .. ',' .. tostring(d.position[2]) .. ',' .. tostring(d.position[3]))"
```

### 创建场景组件

```powershell
# 创建一个组件（key 为组件编号，坐标用 math.Vector3）
.\editor-cli.exe exec "EditorAPI.create_obstacle(100051, math.Vector3(0, 0, 10))"

# 创建组件并设置缩放和旋转（一条命令完成）
.\editor-cli.exe exec "local uid = EditorAPI.create_obstacle(100051, math.Vector3(5, 0, 5)); EditorAPI.set_unit_attr(uid, 'scale', math.Vector3(2.0, 1.0, 2.0)); EditorAPI.set_unit_attr(uid, 'model_angle', {0, 90, 0})"

# 删除组件
.\editor-cli.exe exec "EditorAPI.destroy_obstacle(123)"
```

### 修改单位属性

```powershell
# 修改单位名称
.\editor-cli.exe exec "EditorAPI.set_unit_attr(123, 'name', 'NewName')"

# 修改透明度
.\editor-cli.exe exec "EditorAPI.set_unit_attr(123, 'model_alpha', 0.5)"

# 修改血量
.\editor-cli.exe exec "EditorAPI.set_unit_attr(123, 'ob_max_hp', 500)"
```

### 环境设置

```powershell
# 获取相机属性
.\editor-cli.exe exec "local cam = EditorAPI.get_camera_properties(); EditorAPI.log(tostring(cam))"

# 获取当前天空盒 ID
.\editor-cli.exe exec "EditorAPI.log(tostring(EditorAPI.get_cur_skybox()))"
```

### 截图

```powershell
# 截取当前编辑器画面
.\editor-cli.exe exec "EditorAPI.take_screenshot()"

# 指定分辨率截图
.\editor-cli.exe exec "EditorAPI.take_screenshot_with_size(1920, 1080)"
```

---

## 调试时 API（Playing 状态）

> 📖 调试时 API 文档： [点击查看](https://u5-creator.s3.game.163.com/manual/pc_md/lua/EggyEditorAPI.html)

调试时操作需要通过 `EditorAPI.game_execute()` 执行，且必须先在编辑器中开启试玩（ `EditorAPI.run_game()` ）并等待进入 `playing` 状态。

### 获取玩家状态

```powershell
# 获取玩家位置
.\editor-cli.exe exec "EditorAPI.game_execute('local roles = GameAPI.get_all_roles(); if not roles or #roles == 0 then return end; local u = roles[1].get_ctrl_unit(); local pos = u.get_position(); print(pos)')"

# 获取玩家血量
.\editor-cli.exe exec "EditorAPI.game_execute('local roles = GameAPI.get_all_roles(); if not roles or #roles == 0 then return end; local u = roles[1].get_ctrl_unit(); print(u.get_life())')"

# 获取玩家最大血量
.\editor-cli.exe exec "EditorAPI.game_execute('local roles = GameAPI.get_all_roles(); if not roles or #roles == 0 then return end; local u = roles[1].get_ctrl_unit(); print(u.get_life_max())')"

# 判断玩家是否死亡
.\editor-cli.exe exec "EditorAPI.game_execute('local roles = GameAPI.get_all_roles(); if not roles or #roles == 0 then return end; local u = roles[1].get_ctrl_unit(); print(u.is_die_status())')"
```

> **建议：** 每条命令只 `print` 一个值，避免在 `print()` 内做复杂字符串拼接。拼接容易因 PowerShell 引号转义出错。需要多个数据时分条执行，简单可靠。

### 玩家操控

```powershell
# 瞬移到指定坐标
.\editor-cli.exe exec "EditorAPI.game_execute('local roles = GameAPI.get_all_roles(); if not roles or #roles == 0 then return end; local u = roles[1].get_ctrl_unit(); u.set_position(math.Vector3(10, 2, -5))')"

# 物理移动到指定坐标（持续 5 秒，会触发沿途碰撞）
.\editor-cli.exe exec "EditorAPI.game_execute('local roles = GameAPI.get_all_roles(); if not roles or #roles == 0 then return end; local u = roles[1].get_ctrl_unit(); u.cmd_move_to_pos(math.Vector3(10, 0, 20), 5.0)')"

# 让玩家跳跃
.\editor-cli.exe exec "EditorAPI.game_execute('local roles = GameAPI.get_all_roles(); if not roles or #roles == 0 then return end; local u = roles[1].get_ctrl_unit(); u.jump()')"

# 让玩家冲刺
.\editor-cli.exe exec "EditorAPI.game_execute('local roles = GameAPI.get_all_roles(); if not roles or #roles == 0 then return end; local u = roles[1].get_ctrl_unit(); u.cmd_rush()')"
```

### 广播自定义事件

```powershell
# 广播无数据事件（模拟触发游戏逻辑）
.\editor-cli.exe exec "EditorAPI.game_execute('LuaAPI.global_send_custom_event([[Test_Event]], nil)')"
```

---

## 引号规则

在 PowerShell 中使用 `exec` 时，注意引号嵌套：

```powershell
# 直接 exec：外层双引号，Lua 字符串用单引号
.\editor-cli.exe exec "EditorAPI.set_unit_attr(123, 'name', 'NewName')"

# game_execute：外层双引号，中层单引号，Lua 内字符串用 [[]] 长字符串
.\editor-cli.exe exec "EditorAPI.game_execute('print([[hello world]])')"
```

> **关键规则：** `game_execute('...')` 内部需要字符串字面量时，使用 Lua 的 `[[]]` 长字符串语法，不要用单引号或双引号。PowerShell 会错误解析 `''` 和 `\"` ，导致参数截断。

---

## 如何读取 exec 的执行结果

`exec` 命令不会在终端直接输出返回值。获取数据的方式：

1. 在 Lua 代码中使用 `EditorAPI.log("内容")` 或 `print("内容")` 输出
2. 读取项目根目录的 `log.txt` 文件获取输出

```powershell
# 执行查询，将结果写入日志
.\editor-cli.exe exec "local ids = EditorAPI.get_all_unit_ids(); EditorAPI.log('total units: ' .. tostring(#ids))"

# 读取日志最后 20 行查看结果
powershell -Command "Get-Content 'log.txt' -Tail 20"
```

---

## 常见问题

### Q: 提示"由于目标计算机积极拒绝，无法连接"

编辑器未开启 EditorCli 代理，或端口号不对。请确认：

- 编辑器已启动
- EditorCli 代理功能已开启
- 端口号正确（默认 `19836` ）

### Q: exec 命令返回 nil 或报错

- 检查 Lua 语法是否正确
- 确认调用的 API 名称是否与编辑器文档一致
- 部分 API 可能仅在特定平台可用（如 `--platform game` ）

### Q: watch 命令没有输出

- 确认编辑器当前有日志产生（先在编辑器中做一些操作）
- 检查 `--level` 过滤条件是否过严

### Q: 如何获取 JSON 格式输出

在子命令前加 `--json` ：

```powershell
editor-cli.exe --json status
editor-cli.exe --json logs -n 10
```

JSON 格式便于在自动化脚本或 CI 流程中解析。

---

<sub>工具版本：editor-cli 0.1.0</sub>
