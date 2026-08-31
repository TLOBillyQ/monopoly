# language: zh-CN

功能: Swarm 全角色会话启动

背景:
  假如 仓库启用了 SwarmForge 迁移工作流

# Swarm 全角色会话启动 001 启动配置为全部角色声明会话
场景大纲: Swarm 全角色会话启动 001 启动配置为全部角色声明会话
  假如 swarm 配置声明角色<角色名>
  当 解析 swarm 启动配置
  那么 角色<角色名>使用受支持的引擎
  并且 角色<角色名>分配唯一会话名

  例子:
    | 角色名 |
    | specifier |
    | coder |
    | refactorer |
    | architect |

# Swarm 全角色会话启动 002 全部角色引擎已安装
场景大纲: Swarm 全角色会话启动 002 全部角色引擎已安装
  假如 swarm 配置声明角色<角色名>
  当 检查角色<角色名>的引擎是否已安装
  那么 角色<角色名>的引擎可用

  例子:
    | 角色名 |
    | specifier |
    | coder |
    | refactorer |
    | architect |

# Swarm 全角色会话启动 003 每个角色使用声明的工作树
场景大纲: Swarm 全角色会话启动 003 每个角色使用声明的工作树
  假如 swarm 配置声明角色<角色名>
  当 解析 swarm 启动配置
  那么 角色<角色名>使用工作树<工作树>

  例子:
    | 角色名 | 工作树 |
    | specifier | master |
    | coder | coder |
    | refactorer | refactorer |
    | architect | architect |
