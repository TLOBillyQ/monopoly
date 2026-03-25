---
name: debug
description: 分析大富翁部署目录根部的 log.txt，定位运行时错误、警告和可疑行为。用于用户提到 "/debug"、"分析日志"、"看 log.txt"、"排查发布后异常"、"部署包运行报错" 或需要从 win/mac 部署目录读取日志时触发。
---

# Debug

## 功能

定位部署产物根目录的 `log.txt`，提炼关键异常上下文，并把日志现象映射回仓库代码。

## 工作流

1. 先确定日志路径，按以下优先级：
   - 用户直接给出的 `log.txt` 路径
   - 用户给出的部署根目录，再拼出 `log.txt`
   - 环境变量 `MONOPOLY_DEPLOY_TARGET/log.txt`
   - 平台默认目录：
     - `win`: `~/Desktop/dev/LuaSource_大富翁/log.txt`
     - `mac`: `~/Documents/eggy/LuaSource_大富翁/log.txt`
   - 平台未指定时，默认当前宿主平台；若用户明确说要看 `win` / `mac`，以用户指定的平台为准

2. 运行日志分析脚本：

```bash
pwsh -File .agents/skills/debug/scripts/analyze_log.ps1 [-Platform win|mac] [-TargetPath PATH] [-LogPath PATH]
```

3. 优先关注这些信号：
   - `stack traceback`
   - `[error]`
   - `attempt to`
   - `nil value`
   - `failed`
   - `exception`
   - `panic`
   - `[warn]` 只在它和用户反馈直接相关时深入

4. 需要追源码时，只打开命中的文件和相邻调用点，不预读整片目录。

## 输出要求

始终给出：

- 实际读取的 `log.txt` 路径
- 最关键的 1-3 个异常或警告
- 哪些结论是日志直接证明，哪些只是基于上下文推断
- 下一步最小修复建议
- 如果日志没有错误，只保留关键警告和最近一段运行轨迹，并明确说明未发现崩溃证据

## 常用调用

```bash
/debug
/debug win
/debug --target-path C:\Users\Lzx_8\Desktop\dev\LuaSource_大富翁
/debug --log-path C:\Users\Lzx_8\Desktop\dev\LuaSource_大富翁\log.txt
```

## 注意点

- 日志脚本会输出关键词命中上下文和尾部日志；最终结论由你结合用户症状来归纳。
- 看到重复 `[warn] board_feedback play_sfx_by_key ... cue_name=nil ... with_sound=false` 时，默认先视为非致命声音资源告警，除非用户问题正好是音效异常。
