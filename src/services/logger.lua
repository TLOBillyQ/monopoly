local logger = {}

function logger.info(...)
  print("[INFO]", ...)
end

function logger.warn(...)
  print("[WARN]", ...)
end

function logger.event(...)
  print("[EVENT]", ...)
end

return logger
