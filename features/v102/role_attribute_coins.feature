# language: zh-CN
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
