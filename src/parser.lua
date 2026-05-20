local M = {}

function M.parse(html, w)
    local pageLines = {}
    if not html then return pageLines end
    
    local currentColor = colors.black
    local currentBg = colors.white
    
    html = html:gsub("[\r\n\t]", " ")
    html = html:gsub("%s+", " ")
    
    local pos = 1
    while pos <= #html do
        local startTag, endTag = html:find("<[^>]+>", pos)
        local textChunk = ""
        local tagChunk = ""
        
        if startTag then
            textChunk = html:sub(pos, startTag - 1)
            tagChunk = html:sub(startTag, endTag)
            pos = endTag + 1
        else
            textChunk = html:sub(pos)
            pos = #html + 1
        end
        
        if #textChunk > 0 then
            textChunk = textChunk:gsub("&nbsp;", " ")
            textChunk = textChunk:gsub("&lt;", "<")
            textChunk = textChunk:gsub("&gt;", ">")
            textChunk = textChunk:gsub("&amp;", "&")
            
            while #textChunk > 0 do
                local availableSpace = w - 2
                local take = textChunk:sub(1, availableSpace)
                table.insert(pageLines, {text = take, fg = currentColor, bg = currentBg})
                textChunk = textChunk:sub(availableSpace + 1)
            end
        end
        
        if #tagChunk > 0 then
            local lowerTag = tagChunk:lower()
            if lowerTag:find("^<h[1-6]") then
                currentColor = colors.red
            elseif lowerTag:find("^</h[1-6]") or lowerTag:find("^</p>") or lowerTag:find("^</div>") then
                currentColor = colors.black
            elseif lowerTag:find("^<a%s") then
                currentColor = colors.blue
            elseif lowerTag:find("^</a>") then
                currentColor = colors.black
            end
            
            local styleMatch = tagChunk:match("style%s*=%s*\"([^\"]+)\"") or tagChunk:match("style%s*=%s*'([^']+)'")
            if styleMatch then
                local colorWord = styleMatch:match("color%s*:%s*([%a%d]+)")
                if colorWord and colors[colorWord] then
                    currentColor = colors[colorWord]
                end
                local bgWord = styleMatch:match("background%-color%s*:%s*([%a%d]+)") or styleMatch:match("background%s*:%s*([%a%d]+)")
                if bgWord and colors[bgWord] then
                    currentBg = colors[bgWord]
                end
            end
        end
    end
    
    if #pageLines == 0 then
        table.insert(pageLines, {text = "Empty page.", fg = colors.gray, bg = colors.white})
    end
    
    return pageLines
end

return M
