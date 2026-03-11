local common = require("lib.common")

local loc_counter = {}

function loc_counter.count_effective_lines(content)
  local text = tostring(content or "")
  if text == "" then
    return 0
  end

  local effective_line_count = 0
  local in_block_comment = false

  for line in (text .. "\n"):gmatch("(.-)\n") do
    local current_line = line

    while true do
      if in_block_comment then
        local block_comment_end = current_line:find("]]", 1, true)
        if block_comment_end == nil then
          current_line = ""
          break
        end
        current_line = current_line:sub(block_comment_end + 2)
        in_block_comment = false
      else
        local block_comment_start = current_line:find("--[[", 1, true)
        local line_comment_start = current_line:find("--", 1, true)

        if line_comment_start == nil then
          break
        end

        if block_comment_start ~= nil and block_comment_start == line_comment_start then
          local before_comment = current_line:sub(1, block_comment_start - 1)
          local block_comment_end = current_line:find("]]", block_comment_start + 4, true)
          if block_comment_end ~= nil then
            current_line = before_comment .. current_line:sub(block_comment_end + 2)
          else
            current_line = before_comment
            in_block_comment = true
            break
          end
        else
          current_line = current_line:sub(1, line_comment_start - 1)
          break
        end
      end
    end

    if current_line:match("%S") ~= nil then
      effective_line_count = effective_line_count + 1
    end
  end

  return effective_line_count
end

function loc_counter.count_file(path)
  local content, err = common.read_file(path)
  if content == nil then
    return nil, err
  end
  return loc_counter.count_effective_lines(content)
end

return loc_counter
