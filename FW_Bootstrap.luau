-- FW thin bootstrap — put in executor autoexec folder
-- hosts: https://raw.githubusercontent.com/f4n5/loader/refs/heads/main/

local BASE = "https://raw.githubusercontent.com/f4n5/loader/refs/heads/main/"

local function httpget(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 50 and not body:find("<!DOCTYPE") then return body end
    for _, req in ipairs({
        function() return (syn and syn.request or request or http and http.request)({Url=url, Method="GET"}) end,
    }) do
        local ok2, r = pcall(req)
        if ok2 and r then
            local b = r.Body or r.body
            if type(b) == "string" and #b > 50 then return b end
        end
    end
    return nil
end

local function loadMod(file, genvKey)
    local body = httpget(BASE .. file)
    if not body then return end
    local fn, err = loadstring(body)
    if not fn then warn("[FW] compile", file, err) return end
    local ok, mod = pcall(fn)
    if ok and type(mod) == "table" and type(getgenv) == "function" then
        getgenv()[genvKey] = mod
    end
end

-- preload skin/wrap tables (optional, silent fail)
pcall(loadMod, "FW_Skins.luau", "FW_Skins")
pcall(loadMod, "FW_Wraps.luau", "FW_Wraps")
pcall(loadMod, "FW_SkinToWeapon.luau", "FW_SkinToWeapon")

local main = httpget(BASE .. "Loader.luau")
if not main then
    warn("[FW] failed to fetch Loader.luau")
    return
end
local fn, err = loadstring(main)
if not fn then
    warn("[FW] Loader compile error:", err)
    return
end
local ok, runErr = pcall(fn)
if not ok then
    warn("[FW] Loader runtime:", runErr)
end
