---
name: debug
description: 分析大富翁部署目录根部的 log.txt，定位运行时错误、警告和可疑行为。用于用户提到 "/debug"、"分析日志"、"看 log.txt"、"排查发布后异常"、"部署包运行报错" 或需要从 win/mac 部署目录读取日志时触发。
---

# Debug

定位部署根目录的 `log.txt`，提炼关键异常上下文，把日志现象映射回仓库代码。

## 工作流

1. 按优先级定位日志路径：
   - 用户直接给出的 `log.txt` 路径
   - 用户给的部署根目录，拼出 `log.txt`
   - 环境变量 `MONOPOLY_DEPLOY_TARGET/log.txt`
   - 平台默认目录：
     - `win`: `~/Desktop/dev/LuaSource_大富翁/log.txt`
     - `mac`: `~/Documents/eggy/LuaSource_大富翁/log.txt`
   - 未指定平台时用当前宿主；用户明确指定 `win` / `mac` 时以用户为准

2. 运行日志分析脚本：

```bash
pwsh -File .agents/skills/debug/scripts/analyze_log.ps1 [-Platform win|mac] [-TargetPath PATH] [-LogPath PATH]
```

3. 关注信号：
   - `stack traceback`
   - `[error]`
   - `attempt to`
   - `nil value`
   - `failed`
   - `exception`
   - `panic`
   - `[warn]` 与用户反馈直接相关时才深入

4. 追源码时只看命中文件和相邻调用点，不预读整目录。

## 输出

- 实际读取的 `log.txt` 路径
- 最关键的 1-3 个异常或警告
- 哪些由日志直接证明，哪些是上下文推断
- 下一步最小修复建议
- 日志无错误时只保留关键警告和最近运行轨迹，明确说明未发现崩溃证据

## 常用调用

```bash
/debug
/debug win
/debug --target-path C:\Users\Lzx_8\Desktop\dev\LuaSource_大富翁
/debug --log-path C:\Users\Lzx_8\Desktop\dev\LuaSource_大富翁\log.txt
```

## 注意点

- 脚本输出关键词命中上下文和尾部日志；最终结论由你结合用户症状归纳。
- 重复看到 `[warn] board_feedback play_sfx_by_key ... cue_name=nil ... with_sound=false` 时，默认视为非致命声音告警，除非用户问题就是音效异常。

## autotest 部署包

日志里出现 `[autotest]` 行说明这是 autotest 部署（`deploy.ps1 -Autotest ...`，
一次启动自动跑全部 test profile，见 ADR 0026）。不要逐行人肉解析，直接用：

```bash
pwsh -File tools/ops/autotest_report.ps1 [-Wait] [-LogPath PATH]
```

退出码：0 全部通过；1 有 profile 失败（fail 行带 reason/message）；2 没跑完或无输出。
定位单个失败 profile 时，再回到该 profile 的 `[autotest] profile=<名> ...` 行与其
前后的常规日志段。
