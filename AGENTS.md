# 指导原则

使用直白简练的现代汉语

## 可执行计划
 
- 编写复杂功能或进行重大重构时，应按照 .agent/PLANS.md 中所述使用可执行计划，贯穿设计到实现的整个过程。

## 自定义提示词

- “交付可执行计划”：在./pilots/下创建可执行文档`x_*.md`，x是递增的数字序号前缀
- “清理可执行计划”：将./pilots/下已完成的可执行文档归档到./pilots/archive/下，但保持数字序号递增
- “按顺序执行计划”：按数字从小到大一次执行./pilots/下的未完成计划

## Coding Rules

当做代码修改时，遵守 CodingDiscipline (见.agent/CODING.md)

## 本项目

关于本项目的信息，见.agent/THIS.md