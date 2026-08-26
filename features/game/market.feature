# language: zh-CN
# mutation-stamp: sha256=61632875b11c24121c2f24d227e88a0b680fa1e1554d5142c6dcecc508f9ecdc
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "10c39f71faa0d8d861ad59cadc227a6488b69c0ceff8d5de53357199bca9d95c",
#   "feature_name": "黑市",
#   "feature_path": "features/game/market.feature",
#   "implementation_hash": "c3857238abbc22a1a331316ea2e5aaa46f4b6f8aa4907e022a72fca7101857d7",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 0,
#       "name": "背包已满时道具类商品从黑市列表移除",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "b4a32005857f1e38ea32e973bf0cc52f63967302e3e5e844b4f595f02cdb62db",
#       "tested_at": "2026-05-25T07:33:38Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 0,
#       "name": "黑市只展示道具商品并去掉皮肤分页和皮肤购买入口",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "566c7c628b724881714a5ebe9abc3fbcf7825a0510704efdd1a15b90c45b1656",
#       "tested_at": "2026-05-25T07:33:38Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 0,
#       "name": "商品售罄后仍可见但标记为不可购买",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "19b8435c4aa30583424fc9a124f4df8ba0ecc143ce34b37ab8fbbea1e027e029",
#       "tested_at": "2026-05-25T07:33:38Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 0,
#       "name": "库存充足时商品标记为可购买",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "b47ebce88608b4a7b1bd1cbac2d43195e8cff50ed99b0513a5a6dd1f91a4d76d",
#       "tested_at": "2026-05-25T07:33:38Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "禁用商品从黑市完全隐藏",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "f054b5a7eab29ebab5b60ba31e24932b51aec2d903011336933654b4d35b4bcc",
#       "tested_at": "2026-05-25T07:33:38Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 0,
#       "name": "购买失败后黑市选择窗口保持开放",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "8308ff41d1d72ac0f9b933fe33804b82c23a4e928159165a34eaad0b95e195b6",
#       "tested_at": "2026-05-25T07:33:38Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 0,
#       "name": "尝试购买已售罄商品失败后刷新售罄状态",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "64b152511de2e2fdc565c86effe749b4520d2a0b54d55af7ab2cd638955238bc",
#       "tested_at": "2026-05-25T07:33:38Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 0,
#       "name": "道具购买成功后黑市窗口保持开放可继续选购",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "2e534c10a3fa9459a02e47e9c28618fb792c24ba8d335278c236a8c574e5a8af",
#       "tested_at": "2026-05-25T07:33:38Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 0,
#       "name": "电脑玩家路过黑市不自动购买",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "4e966ec6bc4ff5f650497e55a91144984d09e51c196e2e190d03cc3d3f4debac",
#       "tested_at": "2026-05-25T07:33:38Z"
#     },
#     {
#       "index": 9,
#       "mutation_count": 0,
#       "name": "当前选中商品不可购买时自动切到首个可购买商品",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "eecd448000c1a679b9cf58cdd34146ce88f0687e423b5bc7f2577938ce9c736d",
#       "tested_at": "2026-05-25T07:33:38Z"
#     }
#   ],
#   "tested_at": "2026-05-25T07:33:38Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 黑市

背景:
  假如 游戏已初始化标准棋盘

场景: 背包已满时道具类商品从黑市列表移除
  假如 玩家的背包已满
  当 玩家打开黑市
  那么 黑市列表中不展示任何道具商品

场景: 黑市只展示道具商品并去掉皮肤分页和皮肤购买入口
  假如 黑市配置已加载
  当 玩家查看黑市陈列
  那么 黑市列表只展示道具商品
  并且 黑市不展示皮肤分页
  并且 黑市不存在皮肤购买入口

场景: 商品售罄后仍可见但标记为不可购买
  假如 某商品的全局库存限额为1
  并且 该商品已被购买1次
  当 玩家查看黑市
  那么 该商品仍出现在列表中
  并且 该商品标记为已售罄
  并且 该商品不可点击购买

场景: 库存充足时商品标记为可购买
  假如 某商品的全局库存限额为2
  并且 该商品已被购买1次
  当 玩家查看黑市
  那么 该商品不标记为已售罄
  并且 该商品可以购买

场景: 禁用商品从黑市完全隐藏
  假如 配置中存在市场禁用的商品
  当 玩家打开黑市
  那么 禁用商品不出现在列表中
  并且 禁用商品无法被购买

场景: 购买失败后黑市选择窗口保持开放
  假如 玩家黑市选择窗口已打开
  当 玩家购买失败
  那么 黑市选择窗口仍保持开放
  并且 玩家可以继续选购

场景: 尝试购买已售罄商品失败后刷新售罄状态
  假如 玩家黑市选择窗口已打开
  并且 某商品已售罄
  当 玩家尝试购买该已售罄商品
  那么 购买被拒绝
  并且 该商品在选择窗口中保持售罄标记
  并且 全局库存限额不被消耗

场景: 道具购买成功后黑市窗口保持开放可继续选购
  假如 玩家金币充足
  并且 玩家背包未满
  当 玩家在黑市成功购买一个道具
  那么 黑市选择窗口仍保持开放
  并且 玩家可以继续选购其他商品

场景: 电脑玩家路过黑市不自动购买
  假如 当前行动玩家是电脑
  当 电脑玩家路过黑市
  那么 电脑玩家不自动购买任何商品
  并且 电脑玩家金币保持不变

场景: 当前选中商品不可购买时自动切到首个可购买商品
  假如 玩家黑市选择窗口已打开
  并且 当前选中的商品变为不可购买
  当 选择列表刷新
  那么 自动选中列表中首个可购买的商品
