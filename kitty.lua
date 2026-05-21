local parser = {}

function parser.parse(html, w)
    local pageLines = {}
    if not html then return pageLines end
    local currentColor = colors.black
    local currentBg = colors.white
    local currentHref = nil
    local currentTransform = "none"
    
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
            
            if currentTransform == "uppercase" then
                textChunk = textChunk:upper()
            elseif currentTransform == "lowercase" then
                textChunk = textChunk:lower()
            end
            
            while #textChunk > 0 do
                local availableSpace = w - 2
                local take = textChunk:sub(1, availableSpace)
                table.insert(pageLines, {text = take, fg = currentColor, bg = currentBg, href = currentHref})
                textChunk = textChunk:sub(availableSpace + 1)
            end
        end
        
        if #tagChunk > 0 then
            local lowerTag = tagChunk:lower()
            
            if lowerTag:find("^<h[1-6]") or lowerTag:find("^<p") or lowerTag:find("^<div") then
                if #pageLines > 0 and pageLines[#pageLines].text ~= "" then
                    table.insert(pageLines, {text = "", fg = colors.black, bg = colors.white})
                end
                
                if lowerTag:find("^<h1") then
                    currentColor = colors.red
                    currentTransform = "uppercase"
                elseif lowerTag:find("^<h2") then
                    currentColor = colors.orange
                    currentTransform = "none"
                elseif lowerTag:find("^<h3") then
                    currentColor = colors.yellow
                    currentTransform = "none"
                elseif lowerTag:find("^<h[4-6]") then
                    currentColor = colors.magenta
                    currentTransform = "none"
                elseif lowerTag:find("^<p") then
                    currentColor = colors.black
                    currentTransform = "none"
                end
            elseif lowerTag:find("^</h[1-6]") or lowerTag:find("^</p>") or lowerTag:find("^</div>") then
                currentColor = colors.black
                currentTransform = "none"
                table.insert(pageLines, {text = "", fg = colors.black, bg = colors.white})
            elseif lowerTag:find("^<a%s") then
                currentColor = colors.blue
                currentHref = tagChunk:match("href%s*=%s*\"([^\"]+)\"") or tagChunk:match("href%s*=%s*'([^']+)'")
            elseif lowerTag:find("^</a>") then
                currentColor = colors.black
                currentHref = nil
            elseif lowerTag:find("^<br") then
                table.insert(pageLines, {text = "", fg = currentColor, bg = currentBg})
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
                local textTransform = styleMatch:match("text%-transform%s*:%s*([%a%d]+)")
                if textTransform then
                    currentTransform = textTransform
                end
            end
        end
    end
    
    if #pageLines == 0 then
        table.insert(pageLines, {text = "Empty page.", fg = colors.gray, bg = colors.white})
    end
    return pageLines
end

local mon = peripheral.find("monitor")
if not mon then
    error("No monitor found. Please attach a landscape monitor.")
end
term.redirect(mon)
mon.setTextScale(1)

local w, h = term.getSize()
local currentURL = "http://"
local pageLines = {}
local scrollOffset = 1
local kbY = h - 5

local keys = {
    {"1","2","3","4","5","6","7","8","9","0","-","=","<"},
    {"q","w","e","r","t","y","u","i","o","p","[","]","/"},
    {"a","s","d","f","g","h","j","k","l",";","'",":","."},
    {"z","x","c","v","b","n","m",",","_","@","~","GO"}
}

local function fetchPage(url)
    if not url:find("^http://") and not url:find("^https://") then
        url = "http://" .. url
    end
    pageLines = {{text = "Loading...", fg = colors.gray, bg = colors.white}}
    scrollOffset = 1
    local response, err = http.get(url)
    if not response then
        if err == "Domain not permitted" then
            pageLines = {
                {text = "Error: Could not connect.", fg = colors.red, bg = colors.white},
                {text = tostring(err), fg = colors.gray, bg = colors.white},
                {text = "Enable HTTP!", fg = colors.green, bg = colors.white}
            }
        else
            pageLines = {
                {text = "Error: Could not connect.", fg = colors.red, bg = colors.white},
                {text = tostring(err), fg = colors.gray, bg = colors.white}
            }
        end
    else
        local html = response.readAll()
        response.close()
        pageLines = parser.parse(html, w)
    end
end

local function drawUI()
    term.setBackgroundColor(colors.lightGray)
    term.clear()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.purple)
    term.setTextColor(colors.white)
    term.clearLine()
    term.write(" KITTY ")
    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    term.write(" URL: " .. currentURL:sub(1, w - 8))
    term.setCursorPos(w - 2, 2)
    term.setBackgroundColor(colors.green)
    term.write("GO")
    local contentHeight = kbY - 4
    for i = 1, contentHeight do
        local lineIdx = i + scrollOffset - 1
        term.setCursorPos(1, i + 2)
        if pageLines[lineIdx] then
            term.setBackgroundColor(pageLines[lineIdx].bg)
            term.setTextColor(pageLines[lineIdx].fg)
            term.clearLine()
            term.write(" " .. pageLines[lineIdx].text)
        else
            term.setBackgroundColor(colors.white)
            term.clearLine()
        end
    end
    term.setCursorPos(w, 3)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.write("^")
    term.setCursorPos(w, kbY - 2)
    term.write("v")
    term.setBackgroundColor(colors.black)
    for rowIdx, row in ipairs(keys) do
        local startX = math.floor((w - (#row * 3)) / 2) + 1
        for colIdx, key in ipairs(row) do
            term.setCursorPos(startX + (colIdx - 1) * 3, kbY + rowIdx - 1)
            if key == "GO" then
                term.setBackgroundColor(colors.green)
                term.setTextColor(colors.white)
                term.write("GO")
            elseif key == "<" then
                term.setBackgroundColor(colors.red)
                term.setTextColor(colors.white)
                term.write("<-")
            else
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
                term.write(" " .. key .. " ")
            end
        end
    end
    term.setCursorPos(math.floor((w - 12) / 2) + 1, h)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.write("[  SPACE  ]")
end

local function handleTouch(x, y)
    if y == 2 and x >= w - 2 then
        fetchPage(currentURL)
        return
    end
    if x == w then
        if y == 3 and scrollOffset > 1 then
            scrollOffset = scrollOffset - 1
            return
        elseif y == kbY - 2 and scrollOffset < #pageLines - (kbY - 5) then
            scrollOffset = scrollOffset + 1
            return
        end
    end
    if y >= 3 and y < kbY - 1 and x < w then
        local lineIdx = y - 3 + scrollOffset
        if pageLines[lineIdx] and pageLines[lineIdx].href then
            local href = pageLines[lineIdx].href
            if href:find("^https?://") then
                currentURL = href
            elseif href:sub(1, 1) == "/" then
                local base = currentURL:match("^(https?://[^/]+)") or currentURL
                currentURL = base .. href
            else
                local base = currentURL:match("^(https?://.*/)") or (currentURL .. "/")
                currentURL = base .. href
            end
            fetchPage(currentURL)
            return
        end
    end
    if y >= kbY and y < kbY + #keys then
        local rowIdx = y - kbY + 1
        local row = keys[rowIdx]
        local startX = math.floor((w - (#row * 3)) / 2) + 1
        local colIdx = math.floor((x - startX) / 3) + 1
        if colIdx >= 1 and colIdx <= #row then
            local key = row[colIdx]
            if key == "GO" then
                fetchPage(currentURL)
            elseif key == "<" then
                if #currentURL > 7 then
                    currentURL = currentURL:sub(1, #currentURL - 1)
                end
            else
                currentURL = currentURL .. key
            end
            return
        end
    end
    if y == h and x >= math.floor((w - 12) / 2) + 1 and x <= math.floor((w - 12) / 2) + 11 then
        currentURL = currentURL .. " "
    end
end

pageLines = {
    {text = "Welcome to KITTY!", fg = colors.purple, bg = colors.white},
    {text = "Use the keyboard below to type a URL.", fg = colors.black, bg = colors.white},
    {text = "Version 1.1.0. Clickable links supported!", fg = colors.gray, bg = colors.white}
}

while true do
    drawUI()
    local event, side, x, y = os.pullEvent("monitor_touch")
    handleTouch(x, y)
end
