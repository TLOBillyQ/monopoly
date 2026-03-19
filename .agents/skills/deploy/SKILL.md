---
name: deploy
description: 部署大富翁项目到目标目录。用于用户提到"部署"、"发布"、"deploy"、"打包"或需要运行 tools/ops/deploy.ps1 时触发。
---

# Deploy Skill

## 功能

执行大富翁项目的部署流程，将项目文件拷贝到目标部署目录。

## 部署流程

1. **检查项目根目录** - 确认包含 main.lua、src/、tools/ 等必要文件
2. **确定目标路径** - 按以下优先级：
   - 用户传入的 `--target-path` 参数
   - 环境变量 `MONOPOLY_DEPLOY_TARGET`
   - 默认路径：
     - Windows: `~/Desktop/dev/LuaSource_大富翁-发布`
     - macOS: `~/Documents/eggy/LuaSource_大富翁-发布`
3. **拷贝目录** - 复制 `src/` 和 `vendor/third_party/` 到目标目录
4. **拷贝文件** - 复制 `main.lua`、`Data/UIManagerNodes.lua`、`Data/Prefab.lua`
5. **可选注入 Profile** - 如指定 `--startup-profile`，会在 main.lua 开头注入 `STARTUP_TEST_PROFILE` 变量
6. **统计代码行数** - 计算有效 Lua 代码行数（不含空行和注释）

## 使用方法

### 基本部署
```bash
/deploy
```

### 指定目标路径
```bash
/deploy --target-path /path/to/target
```

### 指定启动 Profile（用于测试）
```bash
/deploy --startup-profile test_quick_3_rounds
```

### 组合使用
```bash
/deploy --target-path /custom/path --startup-profile profile_name
```

## 执行命令

始终使用以下命令执行部署：

```bash
pwsh -File tools/ops/deploy.ps1 [--target-path PATH] [--startup-profile NAME]
```

## 输出检查

部署成功后，检查输出中：
- ✓ 目录拷贝成功提示
- ✓ 文件拷贝成功提示
- 有效代码行数统计（Effective LOC）

## 常见环境变量

- `MONOPOLY_DEPLOY_TARGET` - 覆盖默认部署目标路径
