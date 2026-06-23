# language: zh-CN
# mutation-stamp: sha256=44968d3ac3f4d5186f4f1cb528b787e5e1041169dbba5718bee135d56c176467
# acceptance-mutation-manifest-begin
# {
#   "background_hash": "6a8ef34a5d2d49a20d2efc9a75b6bc342098dfdd95ddb20380e230dcb4e718e3",
#   "feature_name": "道具系统",
#   "feature_path": "features/game/items.feature",
#   "implementation_hash": "sha256:05489e998a1763f1287b16b8f8899aa15ffa9e046bf84ad27277d9c67a908784",
#   "scenarios": [
#     {
#       "index": 0,
#       "mutation_count": 76,
#       "name": "策划案道具卡目录完整",
#       "result": {
#         "Errors": 0,
#         "Killed": 76,
#         "Survived": 0,
#         "Total": 76
#       },
#       "scenario_hash": "62cb9afaff089bce1c542b582cf0e15fcd0a87861608e8809188119ecffc565d",
#       "tested_at": "2026-05-27T16:00:19Z"
#     },
#     {
#       "index": 1,
#       "mutation_count": 0,
#       "name": "落在道具格随机获得道具",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "5157cb437e9a40c8a41ff6dfe154498fdb78d8cbe65757cefcd446de172e287a",
#       "tested_at": "2026-05-27T16:00:19Z"
#     },
#     {
#       "index": 2,
#       "mutation_count": 0,
#       "name": "背包已满时无法获得道具",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "d4767ce5f6ac1565654460012d2c3bc328445f358876622d72b80fe67124dbeb",
#       "tested_at": "2026-05-27T16:00:19Z"
#     },
#     {
#       "index": 3,
#       "mutation_count": 8,
#       "name": "道具系统-004 获得道具时先展示放大卡牌再收入卡槽",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "332d050b5b4e7042bae4abc7ec3aa8b5a19afd3709672381ad70efba3ce2df3d",
#       "tested_at": "2026-06-23T14:00:17Z"
#     },
#     {
#       "index": 4,
#       "mutation_count": 0,
#       "name": "背包已满时黑市购买道具失败",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "e1d603879149d6885f4646032c143e1853f7c937db01f126d22eaab2c1e1841d",
#       "tested_at": "2026-05-27T16:00:20Z"
#     },
#     {
#       "index": 5,
#       "mutation_count": 9,
#       "name": "行动前道具只能在投骰前使用",
#       "result": {
#         "Errors": 0,
#         "Killed": 9,
#         "Survived": 0,
#         "Total": 9
#       },
#       "scenario_hash": "8156e9df300ff6216613220ff7f60f9f9f89412cef3c0ea4b9ef2eaf7affcbcc",
#       "tested_at": "2026-05-27T16:00:23Z"
#     },
#     {
#       "index": 6,
#       "mutation_count": 12,
#       "name": "主动道具只能在自己回合行动前或行动后使用",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "280927660301e449c9da7c77a6abe9a7473238cb371976e51616d00cb33917b0",
#       "tested_at": "2026-05-27T16:00:27Z"
#     },
#     {
#       "index": 7,
#       "mutation_count": 0,
#       "name": "触发型道具未到时机时不能主动使用",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "40008f19ca9553b32876c4bdf04d12a8d73295a41845665e444bbc59633a36de",
#       "tested_at": "2026-05-27T16:00:27Z"
#     },
#     {
#       "index": 8,
#       "mutation_count": 0,
#       "name": "点击道具槽位弹出使用和丢弃按钮",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "aeef9844cfe41b64a86a32d7d6998353c234e39c682ac9e3189a5fa831ca4ded",
#       "tested_at": "2026-05-27T16:00:27Z"
#     },
#     {
#       "index": 9,
#       "mutation_count": 0,
#       "name": "丢弃道具删除该卡并空出卡槽",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "f6c1e12bd85a919fbb04f8b48edb44c323c1f0252d72fa4c2db65126175ccc93",
#       "tested_at": "2026-05-27T16:00:27Z"
#     },
#     {
#       "index": 10,
#       "mutation_count": 2,
#       "name": "路障卡放置在前方或后方格子",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "234d2b26d852e42e8a821a3a61e96ed93e59cab673d212398c54d7a1380f6b38",
#       "tested_at": "2026-05-27T16:00:27Z"
#     },
#     {
#       "index": 11,
#       "mutation_count": 0,
#       "name": "已有路障或地雷的格子不可再放路障",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "9b8a1491e1ee61111774533029af35d785188d25012e4c95359952f472584582",
#       "tested_at": "2026-05-27T16:00:27Z"
#     },
#     {
#       "index": 12,
#       "mutation_count": 2,
#       "name": "地雷卡埋设在当前位置",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "216a0e74e0e6780c734f1ed5555d8477a787e479da9e411165f56a8dbf6a1a7b",
#       "tested_at": "2026-05-27T16:00:28Z"
#     },
#     {
#       "index": 13,
#       "mutation_count": 4,
#       "name": "遥控骰子选择点数",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "aa6c21a04291453d9350b800bb542480809df992dcbb8643e50aa9c793a43be5",
#       "tested_at": "2026-05-27T16:00:29Z"
#     },
#     {
#       "index": 14,
#       "mutation_count": 0,
#       "name": "骰子加倍卡设置倍率",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "c33959f8c16d9e6436b902198df7234412b18a83d421a6f795a6facedc8134d2",
#       "tested_at": "2026-05-27T16:00:29Z"
#     },
#     {
#       "index": 15,
#       "mutation_count": 0,
#       "name": "免费卡设置下次免租状态",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "d545f2b71c2f312da7a47808897cb51bd62cfc3104a349d689c8b1499c64bb54",
#       "tested_at": "2026-05-27T16:00:29Z"
#     },
#     {
#       "index": 16,
#       "mutation_count": 0,
#       "name": "强征卡支付总价值并获得目标地块",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "c404acba1d7f1ce87740682d58c14e03ee3f431a556ce18b72484eea625de6f4",
#       "tested_at": "2026-05-27T16:00:29Z"
#     },
#     {
#       "index": 17,
#       "mutation_count": 0,
#       "name": "免税卡设置下次免税状态",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "31885ba8ebefdf811a86267b43655c7f42a5d0e433b8c37f79305f5b598c6224",
#       "tested_at": "2026-05-27T16:00:29Z"
#     },
#     {
#       "index": 18,
#       "mutation_count": 4,
#       "name": "偷窃卡从目标随机偷取一张道具",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "42ab1f0d554b0166971e80e527b9dfdaee084ba89a837c3466af5625c6e52133",
#       "tested_at": "2026-06-23T14:44:17Z"
#     },
#     {
#       "index": 19,
#       "mutation_count": 1,
#       "name": "偷窃卡目标无道具时不出现在候选列表",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "e84c2a563f594b552066e95352cc1799cf2b0d679f22942fe86cdb285e58bc7b",
#       "tested_at": "2026-06-23T14:44:17Z"
#     },
#     {
#       "index": 20,
#       "mutation_count": 0,
#       "name": "偷窃卡目标无道具时失败",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "e3984a2d170b889bbd0a1e040f05e31875305291503db6a114c97631bfb68d75",
#       "tested_at": "2026-06-23T14:44:17Z"
#     },
#     {
#       "index": 21,
#       "mutation_count": 0,
#       "name": "路过其他玩家不会被动触发偷窃卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "a1ca514c31eea3857f1309d7eb17f4d7aef48fa6404bbe4af4475057b5e6e014",
#       "tested_at": "2026-06-23T14:44:17Z"
#     },
#     {
#       "index": 22,
#       "mutation_count": 12,
#       "name": "均富卡平分双方资金",
#       "result": {
#         "Errors": 0,
#         "Killed": 12,
#         "Survived": 0,
#         "Total": 12
#       },
#       "scenario_hash": "327f3a0083e39082a4aab53924b6801c7bab607c9c0f22c5e045e33eb5c8a784",
#       "tested_at": "2026-06-23T14:44:21Z"
#     },
#     {
#       "index": 23,
#       "mutation_count": 0,
#       "name": "天使守护免疫均富卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "6834cba0c1ceed273e3669905f0184707adb211868a58e0cd5ecd6b5a436c5e0",
#       "tested_at": "2026-06-23T14:44:21Z"
#     },
#     {
#       "index": 24,
#       "mutation_count": 1,
#       "name": "流放卡将目标送往深山",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "bbfab5d460aaa666c5fb421afbd9f047471165121eb1842801f04bf3358fe88e",
#       "tested_at": "2026-06-23T14:44:21Z"
#     },
#     {
#       "index": 25,
#       "mutation_count": 0,
#       "name": "天使守护免疫流放卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "f4373e3defe2984e615ba01ec6d8cbb45ac25dcb3bf41c9b4da96bff9833ae85",
#       "tested_at": "2026-06-23T14:44:21Z"
#     },
#     {
#       "index": 26,
#       "mutation_count": 4,
#       "name": "查税卡对目标收取50%税金",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "bf2b99c3401daa3097b978e6fcdce90c728f80e6ef22d934dc76fd364d983a37",
#       "tested_at": "2026-06-23T14:44:23Z"
#     },
#     {
#       "index": 27,
#       "mutation_count": 0,
#       "name": "查税卡目标持有免税卡时自动抵消",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "126c70bc7dfcc66804a615588e2ee08fb49b8b0360a1a129c7978dd720d1d8f9",
#       "tested_at": "2026-06-23T14:44:23Z"
#     },
#     {
#       "index": 28,
#       "mutation_count": 0,
#       "name": "天使守护免疫查税卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "fbd4097b9fa447e7ff23a2d440bd36076916e963a5e270ce1177d83fbc0f9966",
#       "tested_at": "2026-06-23T14:44:23Z"
#     },
#     {
#       "index": 29,
#       "mutation_count": 2,
#       "name": "怪兽卡摧毁对手建筑",
#       "result": {
#         "Errors": 0,
#         "Killed": 2,
#         "Survived": 0,
#         "Total": 2
#       },
#       "scenario_hash": "31bcb47e962ab71a15b049a74dc608322141c64b482fb515edff44885d6bee1b",
#       "tested_at": "2026-06-23T14:44:24Z"
#     },
#     {
#       "index": 30,
#       "mutation_count": 0,
#       "name": "导弹卡选择目标玩家并轰炸其所在地块",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "aa232fa87c5965f66ae8c4ec9583b699878203ecc3289f7ff8f5b4200271b674",
#       "tested_at": "2026-06-23T14:44:24Z"
#     },
#     {
#       "index": 31,
#       "mutation_count": 0,
#       "name": "导弹卡选择站在自己地块上的目标玩家也摧毁该地块",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "2ebd26093043ab2870bdcdfb792e9a719fed25345698d770fba01abbad130d13",
#       "tested_at": "2026-06-23T14:44:24Z"
#     },
#     {
#       "index": 32,
#       "mutation_count": 0,
#       "name": "天使守护免疫建筑摧毁",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "f78c438a39d3375b9fca57fcc91ed9d2b58d9f2d400d57d45425c6ae3c74729c",
#       "tested_at": "2026-06-23T14:44:24Z"
#     },
#     {
#       "index": 33,
#       "mutation_count": 3,
#       "name": "请神卡夺取目标的神灵",
#       "result": {
#         "Errors": 0,
#         "Killed": 3,
#         "Survived": 0,
#         "Total": 3
#       },
#       "scenario_hash": "93af79155cbe19764c4e5573e0a29c8798afa6fed649a6dfb5b4d1aba3ef454c",
#       "tested_at": "2026-06-23T14:44:25Z"
#     },
#     {
#       "index": 34,
#       "mutation_count": 0,
#       "name": "送神卡将穷神转给目标",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "7252103a76812deced90eefbf228259059b98a868167c4fcee2557fb4bc000c3",
#       "tested_at": "2026-06-23T14:44:25Z"
#     },
#     {
#       "index": 35,
#       "mutation_count": 0,
#       "name": "送神卡可覆盖目标的天使附身",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "ce476234b536e2242fc24d6c67795772b5f86201dc9c116fb6141087f7d9dcba",
#       "tested_at": "2026-06-23T14:44:25Z"
#     },
#     {
#       "index": 36,
#       "mutation_count": 0,
#       "name": "穷神卡令目标附体",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "6491baccf9b2999233d2377a106fa35d3931d9c73d47be67c2d8beb4952d6fe4",
#       "tested_at": "2026-06-23T14:44:25Z"
#     },
#     {
#       "index": 37,
#       "mutation_count": 0,
#       "name": "穷神卡可覆盖目标的天使附身",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "d48a9ecca2496af4414c330c08e98c0dbdb9758fffab76bc1c1f2c8574a78730",
#       "tested_at": "2026-06-23T14:44:25Z"
#     },
#     {
#       "index": 38,
#       "mutation_count": 6,
#       "name": "财神卡和天使卡自身附体",
#       "result": {
#         "Errors": 0,
#         "Killed": 6,
#         "Survived": 0,
#         "Total": 6
#       },
#       "scenario_hash": "aeca0eb95d43d8878444b6b5b0d0e868382b18d5c59995d0e81ef12373fcf905",
#       "tested_at": "2026-06-23T14:44:27Z"
#     },
#     {
#       "index": 39,
#       "mutation_count": 0,
#       "name": "清障卡清除前方障碍物",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "38d95e28a7d72c962becca2fbb2719b785803780ac5d708a3d2227d19a4eb7d6",
#       "tested_at": "2026-06-23T14:44:27Z"
#     },
#     {
#       "index": 40,
#       "mutation_count": 8,
#       "name": "清障卡清除任意玩家布置的障碍",
#       "result": {
#         "Errors": 0,
#         "Killed": 8,
#         "Survived": 0,
#         "Total": 8
#       },
#       "scenario_hash": "9c8a891e0e71cb36b82d709dde21003bcdfe98783d8d83544701e4ef030953ef",
#       "tested_at": "2026-06-23T14:44:30Z"
#     },
#     {
#       "index": 41,
#       "mutation_count": 1,
#       "name": "天使守护让导弹目标玩家退出候选列表",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "d50dce3c545a88cac3d5094d3ae56bb6e77cfbeb8cdc980a2618975f3d78bd2b",
#       "tested_at": "2026-06-23T14:44:30Z"
#     },
#     {
#       "index": 42,
#       "mutation_count": 0,
#       "name": "针对玩家的道具不可对自己使用",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "8421662dd9bafc0c8857a9a3ec4ca9f81e2a4241f9cbc5364a58c356a943563a",
#       "tested_at": "2026-06-23T14:44:30Z"
#     },
#     {
#       "index": 43,
#       "mutation_count": 0,
#       "name": "请神卡目标无神灵时不可使用",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "780378ae07ff7c3741c6beb155392b05b67b54cf86e927ef58b0f31c462a4a7a",
#       "tested_at": "2026-06-23T14:44:30Z"
#     },
#     {
#       "index": 44,
#       "mutation_count": 4,
#       "name": "天使守护让目标退出可选玩家列表",
#       "result": {
#         "Errors": 0,
#         "Killed": 4,
#         "Survived": 0,
#         "Total": 4
#       },
#       "scenario_hash": "d1f24cff82060c8118da3a72db591635ce77bd4802d8008c034f069199d4a63a",
#       "tested_at": "2026-06-23T14:44:31Z"
#     },
#     {
#       "index": 45,
#       "mutation_count": 0,
#       "name": "送神卡使用者无穷神时不可使用",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "eba1a6894982f5f64930f19dd7e836382162ef80d24a07c2ab8697dff24f26d3",
#       "tested_at": "2026-06-23T14:44:31Z"
#     },
#     {
#       "index": 46,
#       "mutation_count": 1,
#       "name": "同组道具单回合内只能使用一次",
#       "result": {
#         "Errors": 0,
#         "Killed": 1,
#         "Survived": 0,
#         "Total": 1
#       },
#       "scenario_hash": "398d27322147eaff7afc0a80c720da04f8f9baa922c8aa9ed46510991e64fb0b",
#       "tested_at": "2026-06-23T14:44:32Z"
#     },
#     {
#       "index": 47,
#       "mutation_count": 0,
#       "name": "道具使用分组限制在回合结束时重置",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "43514308bdb1244a6b96884451e3e2ea0ee36515d96b92fca7007ea392cf0252",
#       "tested_at": "2026-06-23T14:44:32Z"
#     },
#     {
#       "index": 48,
#       "mutation_count": 0,
#       "name": "偷窃时背包已满则失败且不消耗偷窃卡",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "6ce31407fbe643ad0b437151c992c7bd92062fcbd9548a309025bc879e41dee7",
#       "tested_at": "2026-06-23T14:44:32Z"
#     },
#     {
#       "index": 49,
#       "mutation_count": 0,
#       "name": "未激活的地雷不触发",
#       "result": {
#         "Errors": 0,
#         "Killed": 0,
#         "Survived": 0,
#         "Total": 0
#       },
#       "scenario_hash": "d9bdbaa23c0086e19e64dd87738aa964151955b87f1070102611cc2b73daf512",
#       "tested_at": "2026-06-23T14:44:32Z"
#     }
#   ],
#   "tested_at": "2026-06-23T14:44:32Z",
#   "version": 1
# }
# acceptance-mutation-manifest-end

功能: 道具系统

背景:
  假如 游戏已初始化标准棋盘
  并且 玩家背包上限为5格

场景大纲: 策划案道具卡目录完整
  假如 策划案道具卡目录包含<道具名>
  那么 道具<道具名>的编号为<编号>
  并且 道具<道具名>的键为<键>
  并且 道具<道具名>的使用时机为<使用时机>

例子:
  | 道具名     | 编号 | 键              | 使用时机         |
  | 免费卡     | 2001 | free_rent       | post_action      |
  | 遥控骰子卡 | 2002 | remote_dice     | pre_action       |
  | 骰子加倍卡 | 2003 | dice_multiplier | pre_move         |
  | 路障卡     | 2004 | roadblock       | manual           |
  | 地雷卡     | 2005 | mine            | manual           |
  | 清障卡     | 2006 | clear_obstacles | pre_action       |
  | 偷窃卡     | 2007 | steal           | manual           |
  | 怪兽卡     | 2008 | monster         | manual           |
  | 强征卡     | 2009 | strong          | post_action      |
  | 免税卡     | 2010 | tax_free        | tax_prompt       |
  | 均富卡     | 2011 | share_wealth    | manual           |
  | 流放卡     | 2012 | exile           | manual           |
  | 导弹卡     | 2013 | missile         | manual           |
  | 查税卡     | 2014 | tax             | manual           |
  | 请神卡     | 2015 | invite_deity    | manual           |
  | 送神卡     | 2016 | send_poor       | trigger_poor_god |
  | 财神卡     | 2017 | rich            | manual           |
  | 穷神卡     | 2018 | poor            | manual           |
  | 天使卡     | 2019 | angel           | manual           |

场景: 落在道具格随机获得道具
  假如 玩家落在道具格
  并且 背包未满
  当 落地结算执行
  那么 玩家随机获得一张道具卡
  并且 道具按权重抽取

场景: 背包已满时无法获得道具
  假如 玩家背包已有5张道具
  当 玩家触发获得道具
  那么 道具不入包
  并且 弹出背包已满提示

# 道具系统-004 获得道具时先展示放大卡牌再收入卡槽
场景大纲: 道具系统-004 获得道具时先展示放大卡牌再收入卡槽
  假如 玩家通过<来源>实时成功获得道具卡
  并且 玩家背包未满
  当 来源表现<来源表现>完成
  那么 道具获得展示使用已有卡牌展示屏展示新获得的道具卡图
  并且 道具获得展示只出现在获得者视角
  并且 未提前关闭时道具获得展示持续3秒后自动结束
  并且 玩家提前关闭时只结束当前道具获得展示
  并且 多张新道具卡按获得顺序逐张继续展示
  并且 每张展示结束后道具卡视觉收入玩家卡槽

例子:
  | 来源   | 来源表现     |
  | 购买   | 购买结果     |
  | 道具格 | 道具格结算   |
  | 机会卡 | 机会卡展示   |
  | 偷窃   | 偷窃结果提示 |

场景: 背包已满时黑市购买道具失败
  假如 玩家背包已有5张道具
  当 玩家在黑市购买道具
  那么 购买失败
  并且 提示你的卡槽满了

场景大纲: 行动前道具只能在投骰前使用
  假如 玩家持有<道具>
  并且 <道具>属于行动前使用道具
  当 玩家在<阶段>尝试使用<道具>
  那么 道具使用结果为<结果>

例子:
  | 道具       | 阶段     | 结果                 |
  | 遥控骰子卡 | 行动前   | 使用成功             |
  | 遥控骰子卡 | 行动中   | 提示该卡只能在行动前使用 |
  | 遥控骰子卡 | 行动后   | 提示该卡只能在行动前使用 |

场景大纲: 主动道具只能在自己回合行动前或行动后使用
  假如 玩家持有<道具>
  并且 <道具>属于主动使用道具
  当 玩家在<阶段>尝试使用<道具>
  那么 道具使用结果为<结果>

例子:
  | 道具   | 阶段       | 结果                   |
  | 偷窃卡 | 行动前     | 使用成功               |
  | 偷窃卡 | 行动后     | 使用成功               |
  | 偷窃卡 | 行动中     | 提示该卡需在你的回合使用 |
  | 偷窃卡 | 他人回合   | 提示该卡需在你的回合使用 |

场景: 触发型道具未到时机时不能主动使用
  假如 玩家持有触发型道具
  当 玩家手动点击使用该道具
  那么 道具使用结果为提示该卡未到使用时机

场景: 点击道具槽位弹出使用和丢弃按钮
  假如 玩家在槽位1持有遥控骰子卡
  当 玩家点击道具槽位1
  那么 道具操作面板显示使用按钮
  并且 道具操作面板显示丢弃按钮

场景: 丢弃道具删除该卡并空出卡槽
  假如 玩家在槽位1持有遥控骰子卡
  并且 玩家点击道具槽位1
  当 玩家点击丢弃按钮
  那么 槽位1变为空
  并且 遥控骰子卡从玩家背包移除

场景大纲: 路障卡放置在前方或后方格子
  假如 玩家使用路障卡
  并且 可选范围为前后各<可选距离>格
  当 玩家选择放置位置
  那么 路障放置在指定格子
  并且 路障候选范围为<预期距离>格
  并且 路障卡被消耗

例子:
  | 可选距离 | 预期距离 |
  | 3        | 3        |

场景: 已有路障或地雷的格子不可再放路障
  假如 格子已存在路障或地雷
  当 玩家选择路障放置目标
  那么 该格子不出现在候选列表中

场景大纲: 地雷卡埋设在当前位置
  假如 玩家位于格子<当前位置>
  当 玩家使用地雷卡
  那么 地雷埋设在格子<埋设位置>
  并且 地雷状态为已激活
  并且 地雷记录布置者和布置回合

例子:
  | 当前位置 | 埋设位置 |
  | 5        | 5        |

场景大纲: 遥控骰子选择点数
  假如 玩家使用遥控骰子
  当 玩家选择点数<选择点数>
  那么 下次掷骰每颗骰子固定为<固定点数>
  并且 遥控骰子被消耗

例子:
  | 选择点数 | 固定点数 |
  | 1        | 1        |
  | 6        | 6        |

场景: 骰子加倍卡设置倍率
  假如 玩家使用骰子加倍卡
  当 效果生效
  那么 玩家的骰子倍率设为2
  并且 骰子加倍卡被消耗

场景: 免费卡设置下次免租状态
  假如 玩家使用免费卡
  当 效果生效
  那么 玩家的免租状态设为待触发
  并且 免费卡被消耗

场景: 强征卡支付总价值并获得目标地块
  假如 玩家落在目标地块且持有强征卡
  当 玩家选择使用强征卡
  那么 目标地块归玩家所有
  并且 玩家支付目标地块总价值
  并且 强征卡被消耗

场景: 免税卡设置下次免税状态
  假如 玩家使用免税卡
  当 效果生效
  那么 玩家的免税状态设为待触发
  并且 免税卡被消耗

场景大纲: 偷窃卡从目标随机偷取一张道具
  假如 玩家对目标使用偷窃卡
  并且 玩家背包未满
  并且 目标持有<目标初始道具数>张道具
  当 效果执行
  那么 目标随机失去一张道具
  并且 目标剩余<目标剩余道具数>张道具
  并且 该道具转入玩家背包
  并且 偷窃获得展示使用已有卡牌展示屏展示该道具卡图
  并且 偷窃获得展示只出现在玩家视角
  并且 偷窃卡被消耗

例子:
  | 目标初始道具数 | 目标剩余道具数 |
  | 1              | 0              |
  | 3              | 2              |

场景大纲: 偷窃卡目标无道具时不出现在候选列表
  假如 目标持有0张道具
  当 玩家尝试对目标使用<道具>
  那么 目标不出现在候选列表中

例子:
  | 道具   |
  | 偷窃卡 |

场景: 偷窃卡目标无道具时失败
  假如 玩家对目标使用偷窃卡
  并且 目标持有0张道具
  当 效果执行
  那么 偷窃失败
  并且 提示目标没有道具

场景: 路过其他玩家不会被动触发偷窃卡
  假如 玩家持有偷窃卡并路过持有道具的目标
  当 路过后的落地结算执行
  那么 不弹出偷窃选择
  并且 偷窃卡未被消耗
  并且 目标仍持有道具

场景大纲: 均富卡平分双方资金
  假如 玩家持有<余额>金币
  并且 目标持有<目标余额>金币
  并且 使用前双方总额为<总余额>金币
  当 玩家对目标使用均富卡
  那么 双方各持有<平分后>金币

例子:
  | 余额 | 目标余额 | 总余额 | 平分后 |
  | 2000 | 8000     | 10000  | 5000   |
  | 1000 | 3000     | 4000   | 2000   |
  | 5001 | 4999     | 10000  | 5000   |

场景: 天使守护免疫均富卡
  假如 目标拥有天使守护
  当 玩家对目标使用均富卡
  那么 均富无效
  并且 天使守护抵消提示

场景大纲: 流放卡将目标送往深山
  假如 玩家对目标使用流放卡
  当 效果执行
  那么 目标被传送到深山格
  并且 目标需停留<停留回合>回合

例子:
  | 停留回合 |
  | 2        |

场景: 天使守护免疫流放卡
  假如 目标拥有天使守护
  当 玩家对目标使用流放卡
  那么 流放无效
  并且 天使守护抵消提示

场景大纲: 查税卡对目标收取50%税金
  假如 目标持有<余额>金币
  当 玩家对目标使用查税卡
  那么 目标被收取<税金>金币

例子:
  | 余额  | 税金 |
  | 10000 | 5000 |
  | 3000  | 1500 |

场景: 查税卡目标持有免税卡时自动抵消
  假如 目标持有免税卡
  当 玩家对目标使用查税卡
  那么 目标的免税卡被消耗
  并且 目标不被收税

场景: 天使守护免疫查税卡
  假如 目标拥有天使守护
  当 玩家对目标使用查税卡
  那么 查税无效
  并且 天使守护抵消提示

场景大纲: 怪兽卡摧毁对手建筑
  假如 对手在范围<攻击距离>格内有等级大于0的地块
  当 玩家使用怪兽卡选择该地块
  那么 地块等级重置为0
  并且 怪兽攻击范围为<预期距离>格
  并且 怪兽卡被消耗

例子:
  | 攻击距离 | 预期距离 |
  | 3        | 3        |

场景: 导弹卡选择目标玩家并轰炸其所在地块
  假如 对手位于目标地块上
  并且 地块等级大于0
  当 玩家使用导弹卡选择该对手
  那么 导弹轰炸该对手所在地块
  并且 地块等级重置为0
  并且 该对手被送往医院

场景: 导弹卡选择站在自己地块上的目标玩家也摧毁该地块
  假如 玩家自己的地块等级大于0
  并且 对手位于该地块上
  当 玩家使用导弹卡选择该对手
  那么 导弹轰炸该对手所在地块
  并且 地块等级重置为0
  并且 该对手被送往医院

场景: 天使守护免疫建筑摧毁
  假如 对手拥有天使守护
  并且 对手的地块等级大于0
  当 玩家对该地块使用怪兽卡
  那么 建筑不被摧毁
  并且 天使守护抵消提示

场景大纲: 请神卡夺取目标的神灵
  假如 目标身上附有<神灵类型>
  当 玩家对目标使用请神卡
  那么 <神灵类型>转移到玩家身上

例子:
  | 神灵类型 |
  | 财神     |
  | 穷神     |
  | 天使     |

场景: 送神卡将穷神转给目标
  假如 玩家身上附有穷神
  当 玩家对目标使用送神卡
  那么 穷神转移到目标身上

场景: 送神卡可覆盖目标的天使附身
  假如 目标拥有天使守护
  并且 玩家身上附有穷神
  当 玩家对目标使用送神卡
  那么 目标天使附身被清除
  并且 穷神转移到目标身上

场景: 穷神卡令目标附体
  假如 玩家对目标使用穷神卡
  当 效果生效
  那么 目标获得穷神守护
  并且 目标神灵持续10回合

场景: 穷神卡可覆盖目标的天使附身
  假如 目标拥有天使守护
  当 玩家对目标使用穷神卡
  那么 目标天使附身被清除
  并且 目标获得穷神守护

场景大纲: 财神卡和天使卡自身附体
  假如 玩家使用<道具名>
  当 效果生效
  那么 玩家获得<神灵类型>守护
  并且 持续<持续回合>回合

例子:
  | 道具名 | 神灵类型 | 持续回合 |
  | 财神卡 | 财神     | 10       |
  | 天使卡 | 天使     | 10       |

场景: 清障卡清除前方障碍物
  假如 玩家前方12格内有路障和地雷
  当 玩家使用清障卡
  那么 前方12格内的路障和地雷被清除
  并且 清障卡被消耗

场景大纲: 清障卡清除任意玩家布置的障碍
  假如 玩家前方12格内有<布置者>布置的<障碍>
  当 玩家使用清障卡
  那么 前方12格内的<障碍>被清除
  并且 清障卡被消耗

例子:
  | 布置者 | 障碍 |
  | 自己   | 路障 |
  | 自己   | 地雷 |
  | 对手   | 路障 |
  | 对手   | 地雷 |

场景大纲: 天使守护让导弹目标玩家退出候选列表
  假如 目标拥有天使守护
  当 玩家尝试对目标使用<道具>
  那么 目标不出现在候选列表中

例子:
  | 道具   |
  | 导弹卡 |

场景: 针对玩家的道具不可对自己使用
  假如 玩家持有需指定目标的道具
  当 玩家尝试对自己使用该道具
  那么 自己不出现在目标候选列表中

场景: 请神卡目标无神灵时不可使用
  假如 目标身上没有任何神灵
  当 玩家尝试对目标使用请神卡
  那么 目标不出现在候选列表中

场景大纲: 天使守护让目标退出可选玩家列表
  假如 目标拥有天使守护
  当 玩家尝试对目标使用<道具>
  那么 目标不出现在候选列表中

例子:
  | 道具   |
  | 偷窃卡 |
  | 均富卡 |
  | 流放卡 |
  | 查税卡 |

场景: 送神卡使用者无穷神时不可使用
  假如 玩家身上没有穷神
  当 玩家尝试使用送神卡
  那么 送神卡不可用

场景大纲: 同组道具单回合内只能使用一次
  假如 玩家持有两张<道具名>
  当 玩家在本回合已使用一张<道具名>
  那么 第二张<道具名>在本回合不可再选用

例子:
  | 道具名   |
  | 遥控骰子 |

场景: 道具使用分组限制在回合结束时重置
  假如 玩家本回合已使用过遥控骰子
  当 玩家的回合结束并进入下一回合
  那么 玩家可以再次使用遥控骰子

场景: 偷窃时背包已满则失败且不消耗偷窃卡
  假如 玩家背包已满且持有偷窃卡
  并且 目标持有道具
  当 效果执行
  那么 偷窃失败
  并且 偷窃卡未被消耗
  并且 弹出背包已满提示

场景: 未激活的地雷不触发
  假如 玩家当前位于格子2
  并且 格子3放置了未激活的地雷
  当 玩家移动1步到达格子3
  那么 地雷不触发
  并且 玩家不被送往医院
