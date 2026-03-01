-- Compatibility bridge: scheduled retirement in R6.
-- Remove this file after all internal/external callers migrate to src/core/events/MonopolyEvents.lua.
return require("src.core.events.MonopolyEvents")
