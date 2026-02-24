# Robert C. Martin 核心原则摘录与速记

说明：以下引用均为短句（<=25字），便于在审查中快速引用；其余内容为简要归纳。

## SRP（单一职责原则）

引用：
- "A class should have only one reason to change."  
  来源：https://en.wikipedia.org/wiki/Single-responsibility_principle
- "Gather together the things that change for the same reasons. Separate those things that change for different reasons."  
  来源：https://blog.cleancoder.com/uncle-bob/2014/05/08/SingleReponsibilityPrinciple.html

速记：
- “责任”更接近“变化原因/角色”。围绕同一变化原因聚合代码；不同变化原因应拆分。

## SOLID（五原则助记）

引用：
- "The SOLID acronym was coined around 2004 by Michael Feathers."  
  来源：https://en.wikipedia.org/wiki/SOLID

速记：
- Robert C. Martin 提出五条面向对象设计原则；SOLID 是其助记缩写。

## DIP（依赖倒置原则）

引用：
- "Depend in the direction of abstraction. High level modules should not depend upon low level details."  
  来源：https://blog.cleancoder.com/uncle-bob/2020/10/18/Solid-Relevance.html

速记：
- 业务规则/高层策略应依赖抽象接口，细节实现反向依赖抽象，降低耦合。
