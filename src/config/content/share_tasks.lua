-- Host editor share-task configuration mirrored in Lua so acceptance and
-- integration contracts can detect drift. Progress tracking and currency
-- delivery are owned by the host task system, not by Lua gameplay code.
return {
  {
    period = "每日",
    name = "每日分享",
    progress_source = "分享次数",
    target_progress = 1,
    reward_currency = "金币",
    reward_amount = 1000,
  },
  {
    period = "永久",
    name = "邀请1人",
    progress_source = "首次进入地图的人数",
    target_progress = 1,
    reward_currency = "金币",
    reward_amount = 1800,
  },
  {
    period = "永久",
    name = "邀请3人",
    progress_source = "首次进入地图的人数",
    target_progress = 3,
    reward_currency = "金币",
    reward_amount = 6800,
  },
  {
    period = "永久",
    name = "邀请5人",
    progress_source = "首次进入地图的人数",
    target_progress = 5,
    reward_currency = "金币",
    reward_amount = 12800,
  },
  {
    period = "永久",
    name = "邀请10人",
    progress_source = "首次进入地图的人数",
    target_progress = 10,
    reward_currency = "金币",
    reward_amount = 36800,
  },
  {
    period = "永久",
    name = "邀请20人",
    progress_source = "首次进入地图的人数",
    target_progress = 20,
    reward_currency = "金币",
    reward_amount = 99800,
  },
}
