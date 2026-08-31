# language: zh-CN
# mutation-stamp: sha256=79a3a498830ffbe8fc86dde73ec22c11f8da8040372c39a0b939e65e90503c1a
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "41a1310face39a86c9c1753418b407174152c4916cae0b21a6b72721856c7ab9",
#   "feature_name": "Swarm 全角色会话启动",
#   "feature_path": "features/swarmforge/swarm_launch.feature",
#   "implementation_hash": "sha256:2e4e27acbfa6291d4ff04b44e4221f5f5ce5f189d06315b50194570c6c64e2ae",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 4,
#       "name": "Swarm 全角色会话启动 001 启动配置为全部角色声明会话",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "8d74a6b2ff0f7d9e95560b94da471c4daa3eb61d561de8fdc7c3b7e404186405",
#       "tested_at": "2026-08-31T03:38:54Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 4,
#       "name": "Swarm 全角色会话启动 002 全部角色引擎已安装",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "d07019f8cf7ab86c735145f619fc56dcb744c9ab34e7ca99b1f03ebd93ef8837",
#       "tested_at": "2026-08-31T03:38:55Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 8,
#       "name": "Swarm 全角色会话启动 003 每个角色使用声明的工作树",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "062d5857d9d81470c7b2400b4ba2964a23cbd5fa4839ba19982e64a48a7e77a2",
#       "tested_at": "2026-08-31T03:38:56Z"
#     }
#   ],
#   "tested_at": "2026-08-31T03:38:56Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

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
