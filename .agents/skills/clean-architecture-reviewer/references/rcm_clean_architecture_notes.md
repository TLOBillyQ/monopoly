# Robert C. Martin Clean Architecture 资料笔记

## 资料来源（联网检索）

1. The Clean Architecture（Robert C. Martin, 2012）
- https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html

2. Screaming Architecture（Robert C. Martin, 2011）
- https://blog.cleancoder.com/uncle-bob/2011/09/30/Screaming-Architecture.html

3. A Little Architecture（Robert C. Martin, 2016）
- https://blog.cleancoder.com/uncle-bob/2016/01/04/A-Little-Architecture.html

4. Clean Architecture: A Craftsman's Guide to Software Structure and Design（书籍信息）
- https://www.pearson.com/en-us/subject-catalog/p/clean-architecture-a-craftsmans-guide-to-software-structure-and-design/P200000009590

## 核心理念提炼

### 1) 依赖规则是核心约束

- 所有源码依赖都应指向更内层的策略，而不是外层细节。
- 外层（框架、UI、DB、设备）可以依赖内层；反向不允许。
- 违反该规则会让核心业务被技术选型绑架，导致难测与难演进。

### 2) 架构应“表达业务”，而不是“表达框架”

- 代码组织应优先体现用例和业务能力。
- 如果目录/命名首先暴露的是 Rails、Spring、ORM、HTTP，而不是业务场景，说明架构重心偏离。

### 3) 边界通过端口与适配器穿越

- 用例层定义输入输出端口（接口/协议），外层实现这些端口。
- 调用方向可跨层，但源码依赖方向通过抽象反转保持向内。
- 这能让控制器、网关、Presenter、数据库实现可替换。

### 4) 数据跨边界传递时保持稳定

- 跨边界使用简单、稳定的数据结构（DTO/View Model）。
- 避免把数据库行结构、ORM 实体、框架对象直接泄漏到核心用例层。

### 5) 细节是可替换项，应延迟绑定

- 数据库是 I/O 机制，不是架构中心。
- Web 框架是交付机制，不是业务规则本体。
- 先稳定策略与用例，再接入外部技术细节。

## 审查与重构检查单

1. 是否存在内层模块 import 外层框架/基础设施包？
2. 用例是否可在不启动 Web/DB 的条件下独立测试？
3. 控制器/Handler 是否只做转换与编排，不承载业务决策？
4. 网关/Repository 接口是否位于用例层或内层边界？
5. 是否将 ORM Entity/HTTP Request 对象直接传入用例？
6. 模块命名是否体现业务用例而非技术分层口号？

## 实施策略（增量）

1. 先挑选一个高价值用例做“垂直切片”重构。
2. 抽离 Use Case 与端口接口，保留旧实现作为适配器。
3. 为该用例补齐单元测试与契约测试，再逐步扩展到邻近模块。
4. 每次重构后验证：功能等价、依赖方向更清晰、测试执行更快。
