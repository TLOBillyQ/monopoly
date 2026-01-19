#!/usr/bin/env lua
-- 批量删除src下所有Lua文件的注释

local function strip_comments(content)
    local result = {}
    local i = 1
    local len = #content
    
    while i <= len do
        -- 检查多行注释
        if i <= len - 3 and content:sub(i, i+3) == "--[[" then
            -- 查找多行注释的结束
            local close_pos = content:find("]]", i+4, true)
            if close_pos then
                i = close_pos + 2
            else
                i = len + 1
            end
        else
            -- 查找单行注释
            local comment_pos = content:find("--", i, true)
            
            if comment_pos then
                -- 检查是否在字符串内
                local string_start = 0
                local in_string = false
                local string_char = nil
                
                for j = i, comment_pos - 1 do
                    local c = content:sub(j, j)
                    if (c == '"' or c == "'") and (j == 1 or content:sub(j-1, j-1) ~= "\\") then
                        if not in_string then
                            in_string = true
                            string_char = c
                        elseif c == string_char then
                            in_string = false
                        end
                    end
                end
                
                if in_string then
                    -- 注释符在字符串内，复制这个字符
                    table.insert(result, content:sub(i, i))
                    i = i + 1
                else
                    -- 找到行尾
                    local newline_pos = content:find("\n", comment_pos, true)
                    if newline_pos then
                        -- 添加注释前的内容（不含尾部空格）
                        local line = content:sub(i, comment_pos - 1)
                        line = line:gsub("%s+$", "")
                        if #line > 0 then
                            table.insert(result, line)
                        end
                        table.insert(result, "\n")
                        i = newline_pos + 1
                    else
                        -- 文件最后一行
                        local line = content:sub(i, comment_pos - 1)
                        line = line:gsub("%s+$", "")
                        if #line > 0 then
                            table.insert(result, line)
                        end
                        i = len + 1
                    end
                end
            else
                -- 没有注释，复制到行尾或文件尾
                local newline_pos = content:find("\n", i, true)
                if newline_pos then
                    table.insert(result, content:sub(i, newline_pos))
                    i = newline_pos + 1
                else
                    table.insert(result, content:sub(i))
                    i = len + 1
                end
            end
        end
    end
    
    return table.concat(result)
end

local function process_files()
    local lfs = require "lfs"
    local src_dir = "src"
    local count = 0
    
    local function scan_dir(dir)
        for entry in lfs.dir(dir) do
            if entry ~= "." and entry ~= ".." then
                local path = dir .. "/" .. entry
                local attr = lfs.attributes(path)
                
                if attr.mode == "directory" then
                    scan_dir(path)
                elseif path:match("%.lua$") then
                    print("Processing: " .. path)
                    local file = io.open(path, "r")
                    if file then
                        local content = file:read("*a")
                        file:close()
                        
                        local stripped = strip_comments(content)
                        
                        file = io.open(path, "w")
                        file:write(stripped)
                        file:close()
                        
                        count = count + 1
                    end
                end
            end
        end
    end
    
    scan_dir(src_dir)
    print("\nProcessed " .. count .. " files")
end

process_files()
