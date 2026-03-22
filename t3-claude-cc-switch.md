# 让 t3 启动的 Claude 走 CC Switch 管理（零改动优先）

## 简述

目标：**不改 t3 源码**，让 t3 启动出来的 Claude 会话实际使用 **CC Switch 管理的 Claude 配置/代理**。  
推荐默认方案：**走 CC Switch 的 Claude Takeover（本地代理接管）**，因为它对“任何会调用 Claude CLI/Claude API 的进程”都最稳，包括 t3 拉起的 Claude 会话。

关键依据：

- t3 已支持 `claudeAgent` provider，底层通过 Anthropic Claude Agent SDK 启动 Claude，且默认可执行文件就是 `claude`，并把当前进程环境传给 SDK。  
  参考：  
  - `apps/server/src/provider/Layers/ClaudeAdapter.ts`  
    https://github.com/pingdotgg/t3code/blob/main/apps/server/src/provider/Layers/ClaudeAdapter.ts  
  - `packages/contracts/src/orchestration.ts`  
    https://github.com/pingdotgg/t3code/blob/main/packages/contracts/src/orchestration.ts
- t3 协议层支持 `providerOptions.claudeAgent.binaryPath`，但当前 Web 设置页只暴露了 `codexBinaryPath`，**没有 Claude binaryPath 的 UI**。  
  参考：  
  - `apps/web/src/components/ChatView.tsx`  
    https://github.com/pingdotgg/t3code/blob/main/apps/web/src/components/ChatView.tsx  
  - `apps/web/src/appSettings.ts`  
    https://github.com/pingdotgg/t3code/blob/main/apps/web/src/appSettings.ts
- CC Switch 的 Claude Takeover 会把 Claude 的 `ANTHROPIC_BASE_URL` 指向本地代理，实现热切换、日志、故障转移。  
  参考：  
  - README  
    https://github.com/farion1231/cc-switch  
  - App Takeover 文档  
    https://github.com/farion1231/cc-switch/blob/main/docs/user-manual/en/4-proxy/4.2-takeover.md

## 推荐落地方案

### 方案 A：CC Switch Takeover 接管 Claude（推荐）

这是默认实施方案，不需要改 t3。

实施思路：

1. 在 CC Switch 中正常配置 Claude provider，并确认普通 `claude` CLI 已受它管理。
2. 启动 CC Switch 的本地 Proxy Service。
3. 打开 **Claude Takeover**。
4. 在 t3 中使用 `claudeAgent` provider 发起会话。
5. 因为 t3 启动的本质仍是 Claude CLI/Claude SDK 流程，只要它读取的是同一套 Claude 配置，CC Switch 接管后的本地代理就会生效。

为什么推荐它：

- 不依赖 t3 是否暴露 Claude binaryPath UI。
- 可直接获得 CC Switch 的能力：热切换、用量记录、故障转移。
- CC Switch 文档明确说明 Claude Takeover 后切换 provider **无需重启 CLI**。

### 方案 B：只让 t3 读取 CC Switch 管理后的 Claude 配置

这是备选方案，适合你只想“统一 provider 配置”，不一定要本地代理能力。

实施思路：

1. 确认 t3 启动的 `claude` 命令，实际读到的是 CC Switch 正在维护的 Claude 配置目录。
2. 若 CC Switch 使用默认 Claude 配置目录，则保证 t3 所在运行环境也使用同一目录。
3. 若存在多环境（如 macOS host + WSL / 不同 HOME / 不同 shell PATH），统一：
   - `claude` 可执行文件解析结果
   - `HOME` / Claude config 目录
   - t3 后端进程环境变量
4. 验证切换 CC Switch provider 后，t3 新发起的 Claude 请求是否跟随变化。

适用场景：

- 只要“provider 跟着 CC Switch 切换”
- 不需要 CC Switch Proxy/Failover/Usage 统计

## 实施细节

### 环境约束

实现前必须满足：

- t3 里实际选择的是 `claudeAgent`，不是 `codex`
- t3 后端机器上 `claude` 命令可执行
- t3 与 CC Switch 作用在**同一 Claude 配置目录语义**上
- 若开启 Takeover，t3 进程能访问 `127.0.0.1:<cc-switch-proxy-port>`

### 推荐执行顺序

1. **先验证基线**
   - 在终端直接运行 `claude`，确认它当前已被 CC Switch 管理
   - 在 CC Switch 里切一个明显不同的 provider，确认终端侧 Claude 行为变化

2. **再验证 t3 与终端是否同源**
   - 在 t3 中创建一个 Claude 会话
   - 发一个能暴露 provider/模型/响应风格差异的简单请求
   - 对比终端中 `claude` 的行为

3. **最后打开 Takeover**
   - 启动 Proxy Service
   - 开 Claude Takeover
   - 再在 t3 中发请求，确认请求开始走 CC Switch 本地代理

## 需要改动的公共接口 / 类型

- **零改动方案**：无代码改动，公共 API / 接口 / 类型 **不变**
- 仅记录一个事实：t3 协议层其实已支持 `providerOptions.claudeAgent.binaryPath`，只是当前 UI 没暴露

## 验收标准

满足以下即视为成功：

1. 在 CC Switch 切换 Claude provider 后，t3 新发起的 `claudeAgent` 对话跟随切换
2. 开启 Claude Takeover 后，t3 的 Claude 请求进入 CC Switch Proxy
3. 不修改 t3 源码前提下，流程可重复、稳定
4. 若切换 provider，无需重装或手改 t3 配置文件

## 测试场景

### 核心场景

- t3 `claudeAgent` + CC Switch 默认 Claude 配置目录
- CC Switch 切换 provider 后，t3 新会话生效
- CC Switch 开启 Claude Takeover 后，t3 请求可被代理接管

### 边界场景

- t3 与 CC Switch 不在同一 `HOME`
- t3 从 GUI 启动，PATH 与终端不同
- `claude` 命令存在多个安装位置
- CC Switch 配置目录被 override 到 WSL/自定义目录
- Takeover 已开，但 t3 所在环境无法访问本地代理端口

### 失败判定与排查方向

- t3 响应一直不随 CC Switch 切换变化：优先检查是否读到同一 Claude 配置目录
- t3 能跑 Claude，但不走 Takeover：优先检查 `ANTHROPIC_BASE_URL` 是否被接管
- 终端有效、t3 无效：优先检查 t3 后端启动环境的 PATH/HOME

## 默认假设

- 默认采用 **方案 A：CC Switch Claude Takeover**
- 默认不修改 t3 源码
- 默认你的目标是“让 t3 发起的 Claude 请求纳入 CC Switch 的 provider/代理切换体系”
- 默认优先保证“可用性与稳定性”，而不是先做 t3 的原生设置页支持

## 后续可选增强

如果零改动方案跑通，再做第二阶段改造会更稳：

1. 给 t3 设置页补 `claudeBinaryPath`
2. 可选补 `claudeConfigDir` / 启动环境提示
3. 在 Claude provider 健康检查里显示当前实际解析到的 binary/config

这样可以让 t3 对 CC Switch 的接入从“环境约定”升级成“显式配置”。
