# Domain Docs

## 探索前先读

- 领域术语读根部 [`CONTEXT.md`](../../CONTEXT.md)，并沿用其中的首选词。
- 模块职责与放置读 [`docs/architecture.md`](../architecture.md)。
- 决策理由与例外读 [`docs/decisions.md`](../decisions.md)，只引用登记簿仍保留的编号。

需要的术语不在 `CONTEXT.md` 时，先判断它是项目特有概念还是通用编程词；只有前者进入术语表。术语定义不写实现细节。

新 ADR 只在决策难以逆转、离开上下文会显得意外、且确有方案取舍时加入 `docs/decisions.md`。沿用全局递增编号，用短段落记录决定与原因；可执行约束优先落到代码、配置或 guard。

输出与现行决策矛盾时显式指出并说明重开理由，不静默覆盖。
