# language: zh-CN

功能: 差分变异测试契约

背景:
  假如 mutate4lua 已按 swarmforge/tools.lock bootstrap 到位
  并且 项目通过 tools/quality/mutate.lua 暴露 CLI
  并且 manifest 以 --[[ mutate4lua-manifest ]] 块写在源文件尾

场景大纲: 通过运行后再次变异零变异
  假如 源文件<源文件>没有 manifest 尾块
  当 执行 mutate <源文件> --update-manifest 且全 scope pass
  那么 源文件追加 mutate4lua-manifest 尾块
  并且 立即重跑 mutate <源文件> 产生 0 个变异点
  并且 manifest 尾块字节级保持不变

例子:
  | 源文件                       |
  | src/foundation/identity.lua  |
  | src/rules/market/effects.lua |

场景大纲: 空白与注释编辑不触发再次变异
  假如 源文件<源文件>已有 manifest 尾块且最近一次为全 scope pass
  并且 仅以<编辑类型>方式重新保存源文件
  当 执行 mutate <源文件>
  那么 mutate4lua 产生 0 个变异点
  并且 manifest 尾块字节级保持不变

例子:
  | 源文件                       | 编辑类型     |
  | src/rules/market/effects.lua | 增加空行     |
  | src/rules/market/effects.lua | 调整缩进     |
  | src/rules/market/effects.lua | 增加单行注释 |
  | src/rules/market/effects.lua | 删除已有注释 |

场景大纲: 单函数 scope 内的语义编辑只重测该函数与包含它的 chunk
  假如 源文件<源文件>已有 manifest 尾块且最近一次为全 scope pass
  并且 仅在函数 scope <被改 scope id>内将<原文>替换为<新文>
  当 执行 mutate <源文件>
  那么 mutate4lua 对函数 scope <被改 scope id>枚举变异点
  并且 mutate4lua 也对 chunk scope <chunk id>枚举位于其中的顶层变异点
  并且 其他函数 scope 在该次运行中跳过
  并且 跳过的函数 scope 在最终 manifest 中 semanticHash 不变
  并且 chunk scope hash 因 token 集变化必然被重新计算

例子:
  | 源文件                       | 被改 scope id                                | chunk id                              | 原文 | 新文 |
  | src/rules/market/effects.lua | function:module.register_effect_executors:40 | chunk:src/rules/market/effects.lua    | ~=   | ==   |

场景大纲: --mutate-all 完全忽略 manifest
  假如 源文件<源文件>已有 manifest 尾块
  当 执行 mutate <源文件> --mutate-all
  那么 mutate4lua 对所有 scope 枚举变异点
  并且 该次运行不调用差分跳过逻辑
  并且 该次运行的写入策略与不带 --mutate-all 一致

例子:
  | 源文件                       |
  | src/rules/market/effects.lua |

场景大纲: 失败变异不刷新 manifest
  假如 源文件<源文件>已有 manifest 尾块
  并且 该次 mutate 运行产生<survived 数>个 survived 与<timeout 数>个 timeout
  当 mutate 运行结束
  那么 manifest 尾块字节级保持不变
  并且 survived 与 timeout 信息仅出现在 --json 输出与 CI 产物
  并且 manifest 不记录 survived 或 timeout 状态

例子:
  | 源文件                       | survived 数 | timeout 数 |
  | src/rules/market/effects.lua | 1           | 0          |
  | src/rules/market/effects.lua | 0           | 1          |
  | src/rules/market/effects.lua | 2           | 1          |

场景大纲: 删除函数后 pass 写入丢弃旧 scope entry
  假如 源文件<源文件>的 manifest 含 scope id <旧 scope id>
  并且 源文件中已删除该函数
  并且 其余 scope 全 pass
  当 执行 mutate <源文件>
  那么 写入后的 manifest 不再含 scope id <旧 scope id>
  并且 mutate4lua 不输出"已删除 scope"警告
  并且 删除条目对源码 scope 数量与扫描结果一致

例子:
  | 源文件                       | 旧 scope id                                   |
  | src/rules/market/effects.lua | function:module.register_effect_executors:40  |

场景大纲: 新增函数被视为变更并 pass 后写入 manifest
  假如 源文件<源文件>的 manifest 尚不含 scope id <新 scope id>
  并且 源文件中新增对应函数
  当 执行 mutate <源文件>
  那么 mutate4lua 对该新函数的变异点全部枚举
  并且 全 pass 时 manifest 写入<新 scope id>条目
  并且 写入的条目包含与源码一致的 semanticHash

例子:
  | 源文件                       | 新 scope id              |
  | src/rules/market/effects.lua | function:module.guard:48 |

场景大纲: --lines 模式从不刷新 manifest
  假如 源文件<源文件>已有 manifest 尾块
  当 执行 mutate <源文件> --lines <行号集>
  那么 manifest 尾块字节级保持不变
  并且 该约束在<运行结果>条件下均成立

例子:
  | 源文件                       | 行号集 | 运行结果       |
  | src/rules/market/effects.lua | 12     | 全 kill        |
  | src/rules/market/effects.lua | 12,18  | 出现 survived  |
  | src/rules/market/effects.lua | 12,18  | 出现 timeout   |

场景大纲: --update-manifest 将 v1 显式迁移到 v2
  假如 源文件<源文件>含 version=<旧版本>的 manifest 尾块
  并且 源文件相对上次 manifest 的源码未发生语义变化
  当 执行 mutate <源文件> --update-manifest
  那么 manifest 尾块 version 字段改写为<新版本>
  并且 每个 scope 的 id 字段与旧 manifest 一致
  并且 每个 scope 的 semanticHash 字段与旧 manifest 一致
  并且 manifest 不含 lastMutationStatus 字段

例子:
  | 源文件                       | 旧版本 | 新版本 |
  | src/rules/market/effects.lua | 1      | 2      |

场景大纲: manifest 尾块结构异常时回退为全量变异
  假如 源文件<源文件>的 manifest 尾块呈现<异常情况>
  当 执行 mutate <源文件>
  那么 mutate4lua 将差分基线视为不存在
  并且 对所有 scope 枚举变异点
  并且 不抛出未处理异常

例子:
  | 源文件                       | 异常情况               |
  | src/rules/market/effects.lua | 缺失结尾 ]] 标记       |
  | src/rules/market/effects.lua | 起始标记后内容截断     |
  | src/rules/market/effects.lua | manifest 块为空        |
