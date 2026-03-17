local json_reader = {}

local function build_error(text, index)
  error("json decode error at " .. tostring(index) .. ": " .. tostring(text))
end

local function char_at(text, index)
  return string.sub(text, index, index)
end

local function is_whitespace(ch)
  return ch == " " or ch == "\n" or ch == "\r" or ch == "\t"
end

local function skip_whitespace(text, index)
  local cursor = index
  while cursor <= #text and is_whitespace(char_at(text, cursor)) do
    cursor = cursor + 1
  end
  return cursor
end

local function parse_string(text, index)
  local cursor = index + 1
  local parts = {}
  while cursor <= #text do
    local ch = char_at(text, cursor)
    if ch == '"' then
      return table.concat(parts), cursor + 1
    end
    if ch == "\\" then
      local next_ch = char_at(text, cursor + 1)
      if next_ch == '"' or next_ch == "\\" or next_ch == "/" then
        parts[#parts + 1] = next_ch
      elseif next_ch == "b" then
        parts[#parts + 1] = "\b"
      elseif next_ch == "f" then
        parts[#parts + 1] = "\f"
      elseif next_ch == "n" then
        parts[#parts + 1] = "\n"
      elseif next_ch == "r" then
        parts[#parts + 1] = "\r"
      elseif next_ch == "t" then
        parts[#parts + 1] = "\t"
      else
        build_error("unsupported escape sequence", cursor)
      end
      cursor = cursor + 2
    else
      parts[#parts + 1] = ch
      cursor = cursor + 1
    end
  end
  build_error("unterminated string", index)
end

local function digit_value(ch)
  local byte = string.byte(ch or "")
  if byte == nil then
    return nil
  end
  local digit = byte - 48
  if digit < 0 or digit > 9 then
    return nil
  end
  return digit
end

local function parse_number(text, index)
  local cursor = index
  local sign = 1
  if char_at(text, cursor) == "-" then
    sign = -1
    cursor = cursor + 1
  end

  local int_value = 0
  local digit_count = 0
  while cursor <= #text do
    local digit = digit_value(char_at(text, cursor))
    if digit == nil then
      break
    end
    int_value = int_value * 10 + digit
    digit_count = digit_count + 1
    cursor = cursor + 1
  end
  if digit_count == 0 then
    build_error("invalid number", index)
  end

  local value = int_value
  if char_at(text, cursor) == "." then
    cursor = cursor + 1
    local divisor = 1
    local fraction_count = 0
    while cursor <= #text do
      local digit = digit_value(char_at(text, cursor))
      if digit == nil then
        break
      end
      value = value * 10 + digit
      divisor = divisor * 10
      fraction_count = fraction_count + 1
      cursor = cursor + 1
    end
    if fraction_count == 0 then
      build_error("invalid fractional number", index)
    end
    value = value / divisor
  end

  local exponent = 0
  local exp_sign = 1
  local exp_marker = char_at(text, cursor)
  if exp_marker == "e" or exp_marker == "E" then
    cursor = cursor + 1
    local exp_ch = char_at(text, cursor)
    if exp_ch == "-" then
      exp_sign = -1
      cursor = cursor + 1
    elseif exp_ch == "+" then
      cursor = cursor + 1
    end
    local exp_count = 0
    while cursor <= #text do
      local digit = digit_value(char_at(text, cursor))
      if digit == nil then
        break
      end
      exponent = exponent * 10 + digit
      exp_count = exp_count + 1
      cursor = cursor + 1
    end
    if exp_count == 0 then
      build_error("invalid exponent", index)
    end
  end

  value = sign * value
  if exponent ~= 0 then
    value = value * (10 ^ (exp_sign * exponent))
  end
  return value, cursor
end

local function parse_literal(text, index, literal, value)
  if string.sub(text, index, index + #literal - 1) ~= literal then
    build_error("invalid literal", index)
  end
  return value, index + #literal
end

local parse_value

local function parse_array(text, index)
  local cursor = skip_whitespace(text, index + 1)
  local values = {}
  if char_at(text, cursor) == "]" then
    return values, cursor + 1
  end
  while cursor <= #text do
    local value
    value, cursor = parse_value(text, cursor)
    values[#values + 1] = value
    cursor = skip_whitespace(text, cursor)
    local ch = char_at(text, cursor)
    if ch == "]" then
      return values, cursor + 1
    end
    if ch ~= "," then
      build_error("expected ',' or ']'", cursor)
    end
    cursor = skip_whitespace(text, cursor + 1)
  end
  build_error("unterminated array", index)
end

local function parse_object(text, index)
  local cursor = skip_whitespace(text, index + 1)
  local object = {}
  if char_at(text, cursor) == "}" then
    return object, cursor + 1
  end
  while cursor <= #text do
    if char_at(text, cursor) ~= '"' then
      build_error("expected string key", cursor)
    end
    local key
    key, cursor = parse_string(text, cursor)
    cursor = skip_whitespace(text, cursor)
    if char_at(text, cursor) ~= ":" then
      build_error("expected ':' after key", cursor)
    end
    cursor = skip_whitespace(text, cursor + 1)
    object[key], cursor = parse_value(text, cursor)
    cursor = skip_whitespace(text, cursor)
    local ch = char_at(text, cursor)
    if ch == "}" then
      return object, cursor + 1
    end
    if ch ~= "," then
      build_error("expected ',' or '}'", cursor)
    end
    cursor = skip_whitespace(text, cursor + 1)
  end
  build_error("unterminated object", index)
end

function parse_value(text, index)
  local cursor = skip_whitespace(text, index)
  local ch = char_at(text, cursor)
  if ch == '"' then
    return parse_string(text, cursor)
  end
  if ch == "{" then
    return parse_object(text, cursor)
  end
  if ch == "[" then
    return parse_array(text, cursor)
  end
  if ch == "t" then
    return parse_literal(text, cursor, "true", true)
  end
  if ch == "f" then
    return parse_literal(text, cursor, "false", false)
  end
  if ch == "n" then
    return parse_literal(text, cursor, "null", nil)
  end
  if ch == "-" or digit_value(ch) ~= nil then
    return parse_number(text, cursor)
  end
  build_error("unexpected token", cursor)
end

function json_reader.decode(text)
  local raw_text = tostring(text or "")
  local value, cursor = parse_value(raw_text, 1)
  cursor = skip_whitespace(raw_text, cursor)
  if cursor <= #raw_text then
    build_error("trailing content", cursor)
  end
  return value
end

return json_reader
