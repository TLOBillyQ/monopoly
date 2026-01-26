# Refactoring - Eggy 适配版本

本目录是大富翁游戏的 Eggitor 平台适配版本，作为最终发布到 Eggitor 工程的根目录。

## 目录结构

- `src/` - 核心游戏逻辑（从仓库根目录 `src/` 同步）
- `Data/` - UI 节点配置
- `UIManager/` - UI 管理器和组件
- `Utils/` - 工具类库
- `plans/` - 重构执行计划
- `main.lua` - Eggy 内部入口
- `eggy_main.lua` - 外部引导入口
- `init.lua` - 初始化逻辑

## 配置数据来源

**重要：** `src/config/` 目录下的所有配置文件均从 `design/*.xlsx` 导出生成，通过 `export_xlsx.bat` 脚本自动生成。

- **唯一真源：** `design/*.xlsx` 策划表
- **生成脚本：** `export_xlsx.bat`
- **生成产物：** `src/config/*.lua`
- **同步规则：** 严禁手工编辑 `src/config/` 中的配置文件

如需更新配置数值，请：
1. 修改 `design/*.xlsx` 策划表
2. 运行 `export_xlsx.bat` 重新生成配置
3. 配置会自动同步到 `Refactoring/src/config/`

## 执行计划

重构工作按照 `plans/00-master-plan.md` 中定义的顺序执行，包含 12 个子计划：

1. ✅ structure-bootstrap - 目录与骨架
2. data-config-port - 配置同步
3. entry-flow - 入口与回合流程
4. ui-nodes-manager - UI 管理器
5. gameplay-items-chance - 玩法与道具
6. eca-bridge - ECA 触发器
7. visual-timeout-anim - 表现层
8. ai-behavior - AI 行为
9. land-ownership - 地块购买
10. land-upgrade - 地块升级
11. market-blackshop - 市场系统
12. item-active-usage - 主动道具

详见 `plans/` 目录下的各子计划文档。
