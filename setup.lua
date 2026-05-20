local URLS = {
    "https://raw.githubusercontent.com/TriumphyTheReal/Kitty/main/src/kitty.lua",
    "https://raw.githubusercontent.com/TriumphyTheReal/Kitty/main/src/parser.lua",
}
fs.makeDir("/kitty")
local function drawBar(curr, total, name)
    term.clear()
    local w, h = term.getSize()
    local midY = math.floor(h / 2)
    
    term.setCursorPos(2, midY - 1)
    term.write("Downloading: " .. name)
    
    local barW = w - 4
    local fill = math.floor((curr / total) * barW)
    term.setCursorPos(2, midY + 1)
    term.write("[" .. string.rep("=", fill) .. string.rep(" ", barW - fill) .. "]")
end

for i, url in ipairs(URLS) do
    -- Grabs just the filename from the end of the URL
    local filename = url:match("^.*/([^?]*)$") or "file_" .. i
    
    drawBar(i - 1, #URLS, filename)
    
    local res = assert(http.get(url), "Failed to download " .. filename)
    local f = fs.open(filename, "w")
    f.write(res.readAll())
    f.close()
    res.close()
    
    drawBar(i, #URLS, filename)
    sleep(0.2)
end

fs.move("parser.lua", "/kitty/parser.lua")

print("\nDone! Rebooting...")
sleep(1.5)
os.reboot()
