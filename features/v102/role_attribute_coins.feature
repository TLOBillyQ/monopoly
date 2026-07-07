# language: zh-CN
# mutation-stamp: sha256=6089b2799d2497f9a5942b3d29a67fc684a30c219a9e104c34b7f669cb40dcec
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "局内金币使用角色属性真源",
#   "feature_path": "features/v102/role_attribute_coins.feature",
#   "implementation_hash": "sha256:a575456b5d0f3c9daf11aaf08b343433d8b3ac4db932edc47b16fa69364a004e",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 0,
#       "name": "role_attribute_coins_001 新玩家初始化写入角色属性金币",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "da313996cdd60e972cea81e3451fa9a0acb023a74cdab03d80e8bb85f1112c9e",
#       "tested_at": "2026-07-07T02:59:54Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 0,
#       "name": "role_attribute_coins_002 获得金币通过统一边界写入coin_count",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "536883d3acfe9ff84b6b491b01a65ad61ab21a9b0d374b8fd4f2a3abb02c2e4b",
#       "tested_at": "2026-07-07T02:59:54Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 0,
#       "name": "role_attribute_coins_003 消费金币通过统一边界写入coin_count",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "4b5812843e4ef970a2702932671ba911b81da763344e4fd1c5a5973ebe7ed5fa",
#       "tested_at": "2026-07-07T02:59:54Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 0,
#       "name": "role_attribute_coins_004 双方支付只在双方属性可写时提交",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "ae828be4b762c2cca567b383d8a2bd982f3e240678583fcb777b761447b8685c",
#       "tested_at": "2026-07-07T02:59:54Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "role_attribute_coins_005 双方支付写入失败时回滚已写余额",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "81f4d2f90e6e6635c113d53f8a049be7425c8ad0499a090dfcec399afc8622ee",
#       "tested_at": "2026-07-07T02:59:54Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 0,
#       "name": "role_attribute_coins_006 旧cash测试档案只作为加载输入兼容",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "f4ca9956bb80cff9f6749b3aa5b8f2e8af9f6c345db9a9b6ef29742c8d4b527e",
#       "tested_at": "2026-07-07T02:59:54Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 0,
#       "name": "role_attribute_coins_007 非法coin_count值硬失败且可诊断",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "a82769c2d23fe172a7fc55575a2934f5416cff20143f4eb464b8e18a8e56b92f",
#       "tested_at": "2026-07-07T02:59:54Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 0,
#       "name": "role_attribute_coins_008 缺失Role属性能力时硬失败且可诊断",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "9720e44bd5d3ece3128fec8e0cbc60d64480e8cbb3bd4643e24e3b3ec521747d",
#       "tested_at": "2026-07-07T02:59:54Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 0,
#       "name": "role_attribute_coins_009 静态护栏禁止player.cash运行时余额回流",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "2786c6fa19a84bc402d0f158738dbcaf28fd37545d36f353a6aa60a7eeaf01b2",
#       "tested_at": "2026-07-07T02:59:54Z"
#     }
#   ],
#   "tested_at": "2026-07-07T02:59:54Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end
功能: 局内金币使用角色属性真源

# 本规格是 player.cash 到角色 Fixed 属性 coin_count 的迁移契约。
# 玩家可见界面和普通玩法规格继续表述为“金币”；coin_count 只作为技术属性 id 出现在本规格、错误和测试断言中。

背景:
  假如 游戏已初始化标准棋盘

# role_attribute_coins_001
场景: role_attribute_coins_001 新玩家初始化写入角色属性金币
  当 玩家角色ID为1加入对局
  那么 玩家1的角色Fixed属性coin_count等于起始金币与粉丝团起始金币加成之和
  并且 玩家1的Player对象不包含cash余额字段
  并且 玩家1没有收到金币获得动画
  并且 基础屏为玩家1刷新时显示金币余额

# role_attribute_coins_002
场景: role_attribute_coins_002 获得金币通过统一边界写入coin_count
  假如 玩家1的角色Fixed属性coin_count为1000
  当 通过金币边界给玩家1增加500金币
  那么 玩家1的角色Fixed属性coin_count为1500
  并且 查询玩家1当前金币返回1500
  并且 金币变化表现事件记录玩家1本次变化量为500
  并且 玩家1的Player对象不包含cash余额字段

# role_attribute_coins_003
场景: role_attribute_coins_003 消费金币通过统一边界写入coin_count
  假如 玩家1的角色Fixed属性coin_count为10000
  当 玩家1通过金币边界消费5000金币
  那么 玩家1的角色Fixed属性coin_count为5000
  并且 查询玩家1当前金币返回5000
  并且 金币变化表现事件记录玩家1本次变化量为-5000
  并且 玩家1的Player对象不包含cash余额字段

# role_attribute_coins_004
场景: role_attribute_coins_004 双方支付只在双方属性可写时提交
  假如 玩家1的角色Fixed属性coin_count为10000
  并且 玩家2的角色Fixed属性coin_count为2000
  当 玩家1通过金币边界支付3000金币给玩家2
  那么 玩家1的角色Fixed属性coin_count为7000
  并且 玩家2的角色Fixed属性coin_count为5000
  并且 金币变化表现事件记录玩家1本次变化量为-3000
  并且 金币变化表现事件记录玩家2本次变化量为3000
  并且 玩家1和玩家2的Player对象都不包含cash余额字段

# role_attribute_coins_005
场景: role_attribute_coins_005 双方支付写入失败时回滚已写余额
  假如 玩家1的角色Fixed属性coin_count为10000
  并且 玩家2的角色Fixed属性coin_count为2000
  并且 玩家2的角色Fixed属性coin_count下一次写入会失败
  当 玩家1通过金币边界支付3000金币给玩家2
  那么 本次金币支付硬失败
  并且 错误信息包含玩家2
  并且 错误信息包含coin_count
  并且 错误信息包含回滚结果
  并且 玩家1的角色Fixed属性coin_count仍为10000
  并且 玩家2的角色Fixed属性coin_count仍为2000

# role_attribute_coins_006
场景: role_attribute_coins_006 旧cash测试档案只作为加载输入兼容
  假如 测试档案为玩家1提供旧cash输入12000
  当 测试档案加载完成
  那么 玩家1的角色Fixed属性coin_count为12000
  并且 查询玩家1当前金币返回12000
  并且 运行时玩家状态不包含cash余额字段
  并且 acceptance状态输出不包含cash余额字段

# role_attribute_coins_007
场景: role_attribute_coins_007 非法coin_count值硬失败且可诊断
  假如 玩家1的角色Fixed属性coin_count为非法值"12.5"
  当 查询玩家1当前金币
  那么 金币读取硬失败
  并且 错误信息包含玩家1
  并且 错误信息包含coin_count
  并且 错误信息包含有限整数

# role_attribute_coins_008
场景: role_attribute_coins_008 缺失Role属性能力时硬失败且可诊断
  假如 玩家1的Role不支持get_attr_raw_fixed或set_attr_raw_fixed
  当 通过金币边界给玩家1增加500金币
  那么 金币写入硬失败
  并且 错误信息包含玩家1
  并且 错误信息包含coin_count
  并且 错误信息包含get_attr_raw_fixed或set_attr_raw_fixed

# role_attribute_coins_009
场景: role_attribute_coins_009 静态护栏禁止player.cash运行时余额回流
  当 执行角色属性金币静态护栏
  那么 src目录不直接读写player.cash或cash余额字段
  并且 spec目录不构造或断言运行时player.cash余额字段
  并且 tools/acceptance目录不构造或断言运行时player.cash余额字段
  并且 旧profile输入兼容与cash_receive表现命名作为受控例外保留
