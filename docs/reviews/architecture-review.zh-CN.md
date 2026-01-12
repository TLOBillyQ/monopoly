# 架构设计评审（Hollywood 原则 / DIP / SOLID）

> 目的：用“可执行”的方式描述当前 `src/` 的架构现状、主要风险与改造路线；评审维度是 **Hollywood 原则**、**依赖倒置（DIP）** 与 **SOLID**。
>
> 范围：以当前分支代码为准（`src/app.lua`、`src/core/*`、`src/gameplay/*`、`src/visual/*`、`src/config/*`、`scripts/regression.lua`）。
>
> 约束：优先对齐 `docs/backlog.md` 的 **M1（不改玩法）**：本评审的 P0/P1 建议都以“结构与稳定性”为目标，不引入新玩法。

---
