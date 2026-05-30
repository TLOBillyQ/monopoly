-- Daily sign-in coin rewards, indexed by sign-in day (1..7). The host calendar
-- panel owns day progression and triggers RewardDay{N}; the Lua side only grants
-- the coins for the claimed day. Source: 蛋仔策划案--大富翁 签到表.
return {
  500,
  1000,
  2000,
  4000,
  6000,
  8000,
  10000,
}

--[[ mutate4lua-manifest
version=2
projectHash=a9aeca0c18cbdbe6
scope.0.id=chunk:src/config/content/sign_in_rewards.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=13
scope.0.semanticHash=06c401ce3dd8f5a2
scope.0.lastMutatedAt=2026-05-29T15:08:01Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=no_sites
scope.0.lastMutationSites=0
scope.0.lastMutationKilled=0
]]
