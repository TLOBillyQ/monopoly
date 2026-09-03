# Coding Standards

## 命名与 Lua

- 文件、模块、函数、变量使用 `snake_case`；类名使用 `CamelCase`。
- `src/` 的数字判断与转换使用 `src.foundation.number` 的 `NumberUtils`，不使用 `tonumber` 或 `type(value) == "number"`。
- Eggy `Fixed` 参数写浮点字面量，例如 `30.0`。
- Eggy 沙盒的上下界使用 `math.maxval` / `math.minval`。
- 源文件保持 UTF-8、LF；不把生成物或运行时状态写进源码目录。

## 分层与依赖

- 模块职责和放置规则见 [`docs/architecture.md`](docs/architecture.md)。依赖约束以 `tools/packages/arch_view/config.json` 与 `test/guards/` 的可执行规则为准。
- `foundation` 是唯一 substrate，只含无玩法语义的通用能力，不依赖七层；`host` 是 L2 宿主适配层。
- `state` 与 `config` 不依赖上层；装配、mixin 安装和跨边界接线放在 `src/app`。
- 业务规则不接触 UI 节点或 Eggy API；宿主能力经 port 进入内层。
- `src/ui/manager` 是现有 host-EUI adapter 例外，不把该待遇扩散到其他 UI 模块。

## 宿主调用

- `EggyAPI.lua` / `EggyEditorAPI.lua` 是第三方注解线索，不是运行时事实；不得修改成项目实现。
- 宿主对象类名不稳定，业务逻辑不依赖 `type()` 返回的宿主类名。
- 已取证的宿主签名采用单次直调；`pcall` 只隔离宿主异常，成功按接口规定的明确信号判定（无返回值的调用回读状态翻转），不以“没有抛异常”为成功——宿主参数错误只记 ERROR 返回 nil，不抛异常。
- 宿主对象或方法缺失、调用异常与跳过路径必须留下可诊断日志，不静默吞掉。

## 测试

- 测试观察公共接缝和可见行为，不钉私有函数或内部调用次数；mock 只放在宿主、时间、随机数等系统边界。
- 改 `src/rules/**` 前先补或调整 behavior spec；产品外显行为放 `features/**/*.feature`，实现回归留在 `test/behavior/`。
- Acceptance step/driver 调真实 `src` 公共面，不复制业务常量或平行实现规则。
- 期望值来自规格、字面例子或独立真源，不用与实现相同的算法重算期望值。

## mutate4lua manifest

- `src` 文件尾部的 mutate4lua manifest 与源码同属一个提交。
- 删除或改名函数后运行 `lua tools/cli.lua mutate <file> --update-manifest` 重生成；首次纳入差分基线先跑 `--mutate-all`。
- survived、timeout 或仅差分通过都不能证明全量基线。
