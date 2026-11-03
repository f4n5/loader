--==============================================================
-- Fanware Aim | Rivals build
-- Tabs: Combat | Players | Rage | Configs
-- Menu: RightShift
-- loadstring / encryptor safe bootstrap
--==============================================================
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")

-- loadstring-safe LocalPlayer wait (never call nil :Wait on missing signal)
local LocalPlayer
do
    local ok, lp = pcall(function() return Players.LocalPlayer end)
    if ok then LocalPlayer = lp end
    local tries = 0
    while not LocalPlayer and tries < 200 do
        tries = tries + 1
        task.wait(0.05)
        local ok2, lp2 = pcall(function() return Players.LocalPlayer end)
        if ok2 and lp2 then LocalPlayer = lp2 break end
        local ok3, list = pcall(function() return Players:GetPlayers() end)
        if ok3 and list and list[1] then LocalPlayer = list[1] break end
    end
end
if not LocalPlayer then
    warn("[FW Aim] LocalPlayer missing — abort")
    return
end

local Camera
do
    local ok, cam = pcall(function()
        return Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
    end)
    if ok then Camera = cam end
end

-- safe UI parent for loadstring / encryptor / locked CoreGui
local function isfunc(v)
    return type(v) == "function"
end
local function GetUIParent()
    local ok, parent = pcall(function()
        local gh = gethui
        if isfunc(gh) then
            local h = gh()
            if h then return h end
        end
        return nil
    end)
    if ok and parent then return parent end
    local ok2, pg = pcall(function()
        return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 8)
    end)
    if ok2 and pg then return pg end
    local ok3, cg = pcall(function() return CoreGui end)
    if ok3 and cg then return cg end
    local ok4, pg2 = pcall(function() return LocalPlayer:WaitForChild("PlayerGui", 8) end)
    if ok4 and pg2 then return pg2 end
    return nil
end
local UIParent = GetUIParent()
if not UIParent then
    pcall(function() UIParent = CoreGui end)
end
if not UIParent then
    warn("[FW Aim] no UI parent — menu disabled, combat still runs")
end

--==============================================================
-- CONFIG
--==============================================================
local CFG = {
    Aimbot          = false,
    AimAlways       = false,
    AimTarget       = "Head",
    AimSmooth       = 5,
    AimStick        = 5,
    AimFOV          = 350,
    AimMaxDist      = 800,
    AimWall         = true,
    AimTeam         = true,
    AimPred         = 0,
    AimShowFOV      = true,
    AimNPCs         = false, -- target Rivals dummies / NPC humanoids
    SpoofLeaderstats = false,
    SpoofLevel       = 1,
    SpoofStreak      = 0,
    SpoofRank        = 0,
    SkinEnabled     = false,
    SkinUserId      = 0,     -- copy avatar from this user id (0 = off)
    SkinToolTint    = false, -- tint ONLY on button / if enabled — no loop
    SkinTintR       = 90,
    SkinTintG       = 140,
    SkinTintB       = 255,
    SkinForceAvatar = false, -- ApplyDescription from SkinUserId
    DeathLock       = false,
    DeathLockTarget = "Head",
    DeathLockWall   = true,
    DeathLockTeam   = true,
    DeathLockFOV    = 700,
    DeathLockStick  = 6,    -- 1 soft .. 10 firm (not infinite snap)
    DeathLockOnDead = true, -- keep locking corpse / dead body
    Silent          = false,
    SilentFOV       = 180,
    SilentPart      = "Head",
    SilentTeam      = true,
    SilentHitChance = 100,
    ProxWhitelist   = true,
    ProxDist        = 12,
    ManualWL        = {},   -- { [UserId] = true } permanent whitelist
    ManualBL        = {},   -- { [UserId] = true } force targetable
    AimRequireFP    = true, -- aimbot/deathlock/silent only in first person
    TriggerBot      = false,
    TriggerWall     = true,
    TriggerTeam     = true,
    HitboxExpand    = false,
    HitboxSize      = 2.5,
    HitboxTeam      = true,
    NotifyRivalDead = true,
    NotifyTeamDead  = true,
    NotifyCheater   = true,
    UI_Accent       = {90, 140, 255},
    UI_Bg           = {16, 16, 22},
    UI_Panel        = {28, 28, 36},
    ESP             = false,
    ESPBox          = true,
    ESPName         = true,
    ESPDist         = true,
    ESPHealth       = true,
    ESPTracer       = false,
    ESPSkeleton     = false,
    ESPChams        = false,
    ESPTeam         = true,
    ESPMaxDist      = 2000,
    Fly             = false,
    FlySpeed        = 60,
    Noclip          = false,
    TPBehind        = false,
    TPBehindDist    = 4,
    AutoExec        = false,
    ConfigName      = "default",
}

local CONFIG_FILE = "FanwareAim_Config.txt"
local AUTOEXEC_FILE = "FanwareAim_AutoExec.txt"

local function new(class, props)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    return o
end
local function corner(p, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = p })
end
local function stroke(p, c, t)
    return new("UIStroke", { Color = c or Color3.fromRGB(60, 60, 70), Thickness = t or 1, Parent = p })
end

local function GetRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function GetPart(char, kind)
    if not char then return nil end
    if kind == "Head" then
        return char:FindFirstChild("Head") or GetRoot(char)
    elseif kind == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or GetRoot(char)
    elseif kind == "HumanoidRootPart" then
        return GetRoot(char)
    end
    return char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or GetRoot(char)
end

local function IsAlive(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

-- Rivals dummies / NPCs — any Model named Dummy / DPS Dummy (or *dummy*) under Workspace
local function IsNPCModel(model)
    if not model or not model:IsA("Model") then return false end
    -- name gate first (cheap)
    local n = string.lower(model.Name or "")
    if not (n == "dummy" or n == "dps dummy" or n:find("dummy", 1, true)) then
        return false
    end
    if Players:GetPlayerFromCharacter(model) then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return false end
    -- direct children only — no GetDescendants
    local root = model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Head")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("UpperTorso")
        or model.PrimaryPart
    if not root then
        for _, d in ipairs(model:GetChildren()) do
            if d:IsA("BasePart") then root = d break end
        end
    end
    return root ~= nil
end

local _npcCache, _npcCacheAt = {}, 0
local function CollectNPCModels()
    if not CFG.AimNPCs then return {} end
    local now = tick()
    if (now - _npcCacheAt) < 2.5 then
        return _npcCache
    end
    local out = {}
    local seen = {}
    local function add(m)
        if m and not seen[m] and IsNPCModel(m) then
            seen[m] = true
            out[#out + 1] = m
        end
    end
    -- only ShootingRangeEntities + a few known folders — never full Workspace:GetDescendants
    local folders = {
        Workspace:FindFirstChild("ShootingRangeEntities"),
        Workspace:FindFirstChild("Dummies"),
        Workspace:FindFirstChild("Dummy"),
        Workspace:FindFirstChild("NPCs"),
        Workspace:FindFirstChild("Training"),
    }
    for _, folder in ipairs(folders) do
        if folder then
            local ok, kids = pcall(function() return folder:GetChildren() end)
            if ok then
                for _, ch in ipairs(kids) do
                    if ch:IsA("Model") then
                        add(ch)
                    else
                        local ok2, sub = pcall(function() return ch:GetChildren() end)
                        if ok2 then
                            for _, s in ipairs(sub) do
                                if s:IsA("Model") then add(s) end
                            end
                        end
                    end
                end
            end
        end
    end
    _npcCache = out
    _npcCacheAt = now
    return out
end

local fpStable = false
local fpEnterAt = 0
local FP_DWELL = 0.12 -- seconds camera must stay close before we trust FP

local function IsFirstPersonRaw()
    local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
    if not head then return false end
    local d = (Camera.CFrame.Position - head.Position).Magnitude
    -- also treat locked mouse / very close zoom as FP
    if d < 1.5 then return true end
    if LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then return true end
    return false
end

local function IsFirstPerson()
    return fpStable
end

local function UpdateFirstPersonStable(dt)
    local raw = IsFirstPersonRaw()
    if raw then
        if fpEnterAt == 0 then fpEnterAt = tick() end
        if (tick() - fpEnterAt) >= FP_DWELL then
            fpStable = true
        end
    else
        fpEnterAt = 0
        fpStable = false
    end
    return fpStable
end

local function IsEnemy(plr)
    if not plr or plr == LocalPlayer then return false end
    local myTeam, theirTeam = LocalPlayer.Team, plr.Team
    -- check 1: Team instance
    if myTeam and theirTeam then
        if myTeam == theirTeam then return false end
        return true
    end
    -- check 2: TeamColor (Rivals often keys on color)
    local myColor, theirColor = LocalPlayer.TeamColor, plr.TeamColor
    if myColor and theirColor and tostring(myColor) ~= "" and tostring(theirColor) ~= "" then
        if myColor == theirColor then return false end
        -- if both have colors and they differ, enemy
        if myTeam or theirTeam then return true end
    end
    if LocalPlayer.Neutral or plr.Neutral then return true end
    if not myTeam or not theirTeam then return true end
    return true
end

local function IsSameTeam(plr)
    if not plr or plr == LocalPlayer then return false end
    if LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team then return true end
    if LocalPlayer.TeamColor and plr.TeamColor and LocalPlayer.TeamColor == plr.TeamColor then return true end
    return false
end

-- Manual WL / BL only. Teamcheck is a 1–2 sample on FP enter (see RenderStepped), not continuous.
local function IsWhitelistedAlly(plr)
    if not plr then return false end
    if CFG.ManualBL and CFG.ManualBL[plr.UserId] then return false end
    if CFG.ManualWL and CFG.ManualWL[plr.UserId] then return true end
    return false
end

local function CanTarget(plr)
    if not plr or plr == LocalPlayer then return false end
    if CFG.ManualBL and CFG.ManualBL[plr.UserId] then
        return true -- force enemy
    end
    if IsWhitelistedAlly(plr) then return false end
    -- no continuous team scan; lists are set on FP enter / cleared on 3rd
    return true
end

-- FP: sample at +2s and +4.5s only. 2nd sample locks WL. 3rd for ~2.5s → BL all.
local lastWasFP = false
local fpSessionStart = 0 -- tick when entered FP
local teamSampleFlags = { false, false } -- [1]=2s done, [2]=4.5s done
local thirdPersonSince = 0 -- tick when entered 3rd; 0 = in FP
local THIRD_BL_DELAY = 2.5 -- seconds in 3rd before blacklist-all
local function OnCameraModeTick()
    return IsFirstPerson()
end

local function RunTeamSample()
    local myRoot = GetRoot(LocalPlayer.Character)
    if not myRoot then return nil end
    local maxD = CFG.ProxDist or 12
    local bestPlr, bestD = nil, maxD
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and IsSameTeam(plr) then
            local root = GetRoot(plr.Character)
            if root and IsAlive(plr.Character) then
                local d = (root.Position - myRoot.Position).Magnitude
                if d <= maxD and d < bestD then
                    bestD = d
                    bestPlr = plr
                end
            end
        end
    end
    if bestPlr then
        CFG.ManualWL = CFG.ManualWL or {}
        CFG.ManualBL = CFG.ManualBL or {}
        CFG.ManualBL[bestPlr.UserId] = nil
        CFG.ManualWL[bestPlr.UserId] = true
        if refreshPlayerLists then pcall(refreshPlayerLists) end
    end
    return bestPlr
end

local function AimAllowedByCamera()
    if CFG.AimRequireFP == false then return true end
    return IsFirstPerson()
end

local function GetPlayerUnderMouse()
    local mouse = UserInputService:GetMouseLocation()
    local ray = Camera:ViewportPointToRay(mouse.X, mouse.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
    if not hit then return nil end
    local model = hit.Instance:FindFirstAncestorOfClass("Model")
    if not model then return nil end
    return Players:GetPlayerFromCharacter(model)
end

local function ToggleManualWL(plr)
    if not plr then return end
    CFG.ManualWL = CFG.ManualWL or {}
    CFG.ManualBL = CFG.ManualBL or {}
    if CFG.ManualWL[plr.UserId] then
        CFG.ManualWL[plr.UserId] = nil
    else
        CFG.ManualWL[plr.UserId] = true
        CFG.ManualBL[plr.UserId] = nil
    end
    if refreshPlayerLists then pcall(refreshPlayerLists) end
end

local function ToggleManualBL(plr)
    if not plr then return end
    CFG.ManualWL = CFG.ManualWL or {}
    CFG.ManualBL = CFG.ManualBL or {}
    if CFG.ManualBL[plr.UserId] then
        CFG.ManualBL[plr.UserId] = nil
    else
        CFG.ManualBL[plr.UserId] = true
        CFG.ManualWL[plr.UserId] = nil
    end
    if refreshPlayerLists then pcall(refreshPlayerLists) end
end

local function ClearManualLists()
    CFG.ManualWL = {}
    CFG.ManualBL = {}
    if refreshPlayerLists then pcall(refreshPlayerLists) end
end

-- forward declare; assigned when Configs UI builds
refreshPlayerLists = nil

local function ListManualNames(tbl)
    local names = {}
    for uid, on in pairs(tbl or {}) do
        if on then
            local p = Players:GetPlayerByUserId(uid)
            table.insert(names, p and p.Name or tostring(uid))
        end
    end
    table.sort(names)
    return #names > 0 and table.concat(names, ", ") or "(none)"
end

local function HasWallBetween(fromPos, toPos, ignore)
    local dir = toPos - fromPos
    local dist = dir.Magnitude
    if dist < 1 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore or { LocalPlayer.Character }
    params.IgnoreWater = true
    local hit = Workspace:Raycast(fromPos, dir.Unit * (dist - 1.5), params)
    if not hit then return false end
    local model = hit.Instance:FindFirstAncestorOfClass("Model")
    if model and Players:GetPlayerFromCharacter(model) then return false end
    if hit.Instance.CanCollide == false or hit.Instance.Transparency >= 0.9 then return false end
    return true
end

local function IsVisible(part)
    if not part then return false end
    local origin = Camera.CFrame.Position
    local ignore = { LocalPlayer.Character }
    local model = part:FindFirstAncestorOfClass("Model")
    if model then table.insert(ignore, model) end
    return not HasWallBetween(origin, part.Position, ignore)
end

local function GetClosest(targetType, maxFOV, maxDist, wallCheck, teamCheck)
    local mouse = UserInputService:GetMouseLocation()
    local bestPlr, bestPart, bestDist = nil, nil, maxFOV or math.huge
    local origin = Camera.CFrame.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok
        if teamCheck then
            ok = CanTarget(plr)
        else
            ok = plr ~= LocalPlayer and not IsWhitelistedAlly(plr)
        end
        if ok then
            local char = plr.Character
            if char and IsAlive(char) then
                local part = GetPart(char, targetType)
                if part then
                    local d3 = (part.Position - origin).Magnitude
                    if not maxDist or d3 <= maxDist then
                        local sp, on = Camera:WorldToViewportPoint(part.Position)
                        if on and sp.Z > 0 then
                            local d2 = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                            if d2 < bestDist then
                                if not wallCheck or IsVisible(part) then
                                    bestDist = d2
                                    bestPlr = plr
                                    bestPart = part
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    -- Rivals dummies / NPCs (only when AimNPCs and a combat module is actually on)
    if CFG.AimNPCs and (CFG.Aimbot or CFG.Silent or CFG.DeathLock or CFG.TriggerBot) then
        for _, model in ipairs(CollectNPCModels()) do
            local part = GetPart(model, targetType)
            if not part then
                part = model:FindFirstChild("Head")
                    or model:FindFirstChild("HumanoidRootPart")
                    or model.PrimaryPart
            end
            if part then
                local d3 = (part.Position - origin).Magnitude
                if not maxDist or d3 <= maxDist then
                    local sp, on = Camera:WorldToViewportPoint(part.Position)
                    if on and sp.Z > 0 then
                        local d2 = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                        if d2 < bestDist then
                            if not wallCheck or IsVisible(part) then
                                bestDist = d2
                                bestPlr = nil -- NPC, no Player
                                bestPart = part
                            end
                        end
                    end
                end
            end
        end
    end
    return bestPlr, bestPart
end


-- DeathLock target search: optional include dead characters (no IsAlive gate)
local function GetClosestDeathLock(targetType, maxFOV, maxDist, wallCheck, teamCheck, allowDead)
    local mouse = UserInputService:GetMouseLocation()
    local bestPlr, bestPart, bestDist = nil, nil, maxFOV or math.huge
    local origin = Camera.CFrame.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok
        if teamCheck then
            ok = CanTarget(plr)
        else
            ok = plr ~= LocalPlayer and not IsWhitelistedAlly(plr)
        end
        if ok then
            local char = plr.Character
            if char then
                local alive = IsAlive(char)
                if alive or allowDead then
                    local part = GetPart(char, targetType)
                    -- corpses sometimes lose Head briefly; fall back to any BasePart
                    if not part and allowDead then
                        part = char:FindFirstChild("Head")
                            or char:FindFirstChild("HumanoidRootPart")
                            or char:FindFirstChild("UpperTorso")
                            or char:FindFirstChild("Torso")
                            or char.PrimaryPart
                    end
                    if part then
                        local d3 = (part.Position - origin).Magnitude
                        if not maxDist or d3 <= maxDist then
                            local sp, on = Camera:WorldToViewportPoint(part.Position)
                            if on and sp.Z > 0 then
                                local d2 = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                                if d2 < bestDist then
                                    if not wallCheck or IsVisible(part) then
                                        bestDist = d2
                                        bestPlr = plr
                                        bestPart = part
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
        -- dummies / NPCs for deathlock
    if CFG.AimNPCs and (CFG.DeathLock or CFG.Aimbot or CFG.Silent) then
        for _, model in ipairs(CollectNPCModels()) do
            local part = GetPart(model, targetType)
            if not part then
                part = model:FindFirstChild("Head")
                    or model:FindFirstChild("HumanoidRootPart")
                    or model.PrimaryPart
            end
            if part then
                local d3 = (part.Position - origin).Magnitude
                if not maxDist or d3 <= maxDist then
                    local sp, on = Camera:WorldToViewportPoint(part.Position)
                    if on and sp.Z > 0 then
                        local d2 = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                        if d2 < bestDist then
                            if not wallCheck or IsVisible(part) then
                                bestDist = d2
                                bestPlr = nil
                                bestPart = part
                            end
                        end
                    end
                end
            end
        end
    end
    return bestPlr, bestPart
end

local function GetClosest3D(maxDist, teamCheck)
    local origin = Camera.CFrame.Position
    local bestRoot, bestD = nil, maxDist or math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        -- always skip WL; BL / non-WL are fair game
        local ok
        if teamCheck then
            ok = CanTarget(plr)
        else
            ok = plr ~= LocalPlayer and not IsWhitelistedAlly(plr)
        end
        if ok then
            local root = GetRoot(plr.Character)
            if root and IsAlive(plr.Character) then
                local d = (root.Position - origin).Magnitude
                if d < bestD then
                    bestD = d
                    bestRoot = root
                end
            end
        end
    end
    return bestRoot
end

-- UI
pcall(function()
    if UIParent then
        local old = UIParent:FindFirstChild("FanwareAimUI")
        if old then old:Destroy() end
    end
    local old2 = CoreGui and CoreGui:FindFirstChild("FanwareAimUI")
    if old2 then old2:Destroy() end
end)

local ScreenGui = new("ScreenGui", {
    Name = "FanwareAimUI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    Parent = UIParent, -- may be nil; Instance still created, parent later if needed
})
if not UIParent then
    pcall(function()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then ScreenGui.Parent = pg; UIParent = pg end
    end)
end

local function Notify(msg, color)
    pcall(function()
        local parent = UIParent or LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui
        if not parent then return end
        local g = Instance.new("ScreenGui")
        g.Name = "FanwareAimNotify"
        g.ResetOnSpawn = false
        g.Parent = parent
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 320, 0, 40)
        f.Position = UDim2.new(0.5, -160, 0.12, 0)
        f.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
        f.BorderSizePixel = 0
        f.Parent = g
        corner(f, 8)
        stroke(f, color or Color3.fromRGB(90, 140, 255), 1)
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -16, 1, 0)
        t.Position = UDim2.new(0, 8, 0, 0)
        t.BackgroundTransparency = 1
        t.Text = msg
        t.TextColor3 = color or Color3.fromRGB(220, 230, 255)
        t.Font = Enum.Font.GothamMedium
        t.TextSize = 13
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = f
        task.delay(2.4, function()
            pcall(function() g:Destroy() end)
        end)
    end)
end

local main = new("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, 520, 0, 420),
    Position = UDim2.new(0.5, -260, 0.5, -210),
    BackgroundColor3 = Color3.fromRGB(16, 16, 22),
    BorderSizePixel = 0,
    Active = true,
    Visible = true,
})
corner(main, 10)
stroke(main, Color3.fromRGB(70, 70, 90), 1)

local topBar = new("Frame", {
    Parent = main,
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = Color3.fromRGB(22, 22, 30),
    BorderSizePixel = 0,
})
corner(topBar, 10)
new("Frame", {
    Parent = topBar,
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = Color3.fromRGB(22, 22, 30),
    BorderSizePixel = 0,
})

new("TextLabel", {
    Parent = topBar,
    Size = UDim2.new(1, -40, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "FW  <font color=\"#6a9cff\">Aim</font>  ·  Rivals",
    RichText = true,
    TextColor3 = Color3.fromRGB(240, 240, 245),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local closeBtn = new("TextButton", {
    Parent = topBar,
    Size = UDim2.new(0, 28, 0, 22),
    Position = UDim2.new(1, -34, 0.5, -11),
    BackgroundColor3 = Color3.fromRGB(40, 40, 52),
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Color3.fromRGB(220, 220, 230),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
})
corner(closeBtn, 6)
closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

do
    local dragging, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    topBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local side = new("Frame", {
    Parent = main,
    Size = UDim2.new(0, 100, 1, -42),
    Position = UDim2.new(0, 6, 0, 38),
    BackgroundColor3 = Color3.fromRGB(20, 20, 28),
    BorderSizePixel = 0,
})
corner(side, 8)
new("UIListLayout", {
    Parent = side,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
})
new("UIPadding", { Parent = side, PaddingTop = UDim.new(0, 6) })

local pages = {}

local function makePage(name)
    local page = new("ScrollingFrame", {
        Parent = main,
        Size = UDim2.new(1, -120, 1, -48),
        Position = UDim2.new(0, 112, 0, 40),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(60, 90, 180),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    })
    new("UIListLayout", { Parent = page, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    new("UIPadding", {
        Parent = page,
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 6),
    })
    pages[name] = page
    return page
end

local function selectTab(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for _, btn in ipairs(side:GetChildren()) do
        if btn:IsA("TextButton") then
            btn.BackgroundColor3 = (btn.Name == name) and Color3.fromRGB(50, 90, 200) or Color3.fromRGB(32, 32, 42)
        end
    end
end

local function makeTabBtn(name)
    local btn = new("TextButton", {
        Parent = side,
        Name = name,
        Size = UDim2.new(1, -12, 0, 30),
        BackgroundColor3 = Color3.fromRGB(32, 32, 42),
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        AutoButtonColor = false,
    })
    corner(btn, 6)
    btn.MouseButton1Click:Connect(function() selectTab(name) end)
    makePage(name)
    return btn
end

makeTabBtn("Combat")
makeTabBtn("Players")
makeTabBtn("Rage")
makeTabBtn("Visuals")
makeTabBtn("Configs")
makeTabBtn("Dex")
selectTab("Combat")

local function makeSection(page, title)
    local f = new("Frame", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        LayoutOrder = #page:GetChildren(),
    })
    new("TextLabel", {
        Parent = f,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Color3.fromRGB(120, 160, 255),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function makeToggle(page, label, default, callback)
    local holder = new("Frame", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        LayoutOrder = #page:GetChildren(),
    })
    corner(holder, 6)
    new("TextLabel", {
        Parent = holder,
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local state = default or false
    local track = new("Frame", {
        Parent = holder,
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -50, 0.5, -10),
        BackgroundColor3 = state and Color3.fromRGB(50, 90, 200) or Color3.fromRGB(60, 60, 70),
        BorderSizePixel = 0,
    })
    corner(track, 10)
    local knob = new("Frame", {
        Parent = track,
        Size = UDim2.new(0, 16, 0, 16),
        Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    })
    corner(knob, 8)
    local click = new("TextButton", {
        Parent = holder,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    })
    click.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(track, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(50, 90, 200) or Color3.fromRGB(60, 60, 70)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }):Play()
        if callback then callback(state) end
    end)
    return {
        Set = function(v)
            state = v and true or false
            track.BackgroundColor3 = state and Color3.fromRGB(50, 90, 200) or Color3.fromRGB(60, 60, 70)
            knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        end,
        Get = function() return state end,
    }
end

local activeDropdownList = nil
local function makeDropdown(page, label, options, default, callback)
    local holder = new("Frame", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        LayoutOrder = #page:GetChildren(),
    })
    corner(holder, 6)
    new("TextLabel", {
        Parent = holder,
        Size = UDim2.new(0.5, -10, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local selected = default or options[1]
    local btn = new("TextButton", {
        Parent = holder,
        Size = UDim2.new(0, 110, 0, 22),
        Position = UDim2.new(1, -120, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(40, 40, 50),
        BorderSizePixel = 0,
        Text = selected,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.Gotham,
        TextSize = 12,
    })
    corner(btn, 6)
    local open = false
    local function closeMenu()
        if activeDropdownList then activeDropdownList:Destroy() activeDropdownList = nil end
        open = false
    end
    btn.MouseButton1Click:Connect(function()
        if open then closeMenu() return end
        if activeDropdownList then activeDropdownList:Destroy() end
        open = true
        local absPos, absSize = btn.AbsolutePosition, btn.AbsoluteSize
        local list = new("Frame", {
            Parent = ScreenGui,
            Size = UDim2.new(0, absSize.X, 0, #options * 24),
            Position = UDim2.fromOffset(absPos.X, absPos.Y + absSize.Y + 2),
            BackgroundColor3 = Color3.fromRGB(30, 30, 38),
            BorderSizePixel = 0,
            ZIndex = 100,
        })
        corner(list, 6)
        stroke(list, Color3.fromRGB(70, 70, 85), 1)
        new("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder })
        for _, opt in ipairs(options) do
            local ob = new("TextButton", {
                Parent = list,
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = Color3.fromRGB(30, 30, 38),
                BorderSizePixel = 0,
                Text = opt,
                TextColor3 = Color3.fromRGB(220, 220, 225),
                Font = Enum.Font.Gotham,
                TextSize = 12,
                ZIndex = 101,
            })
            ob.MouseButton1Click:Connect(function()
                selected = opt
                btn.Text = opt
                closeMenu()
                if callback then callback(opt) end
            end)
            ob.MouseEnter:Connect(function() ob.BackgroundColor3 = Color3.fromRGB(45, 50, 70) end)
            ob.MouseLeave:Connect(function() ob.BackgroundColor3 = Color3.fromRGB(30, 30, 38) end)
        end
        activeDropdownList = list
    end)
    return { Get = function() return selected end, Set = function(v) selected = v btn.Text = v end }
end

local function makeSlider(page, label, min, max, default, callback)
    local holder = new("Frame", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        LayoutOrder = #page:GetChildren(),
    })
    corner(holder, 6)
    new("TextLabel", {
        Parent = holder,
        Size = UDim2.new(0.6, 0, 0, 18),
        Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local val = default or min
    local valLabel = new("TextLabel", {
        Parent = holder,
        Size = UDim2.new(0.4, -10, 0, 18),
        Position = UDim2.new(0.6, 0, 0, 4),
        BackgroundTransparency = 1,
        Text = tostring(val),
        TextColor3 = Color3.fromRGB(140, 180, 255),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local bar = new("Frame", {
        Parent = holder,
        Size = UDim2.new(1, -20, 0, 6),
        Position = UDim2.new(0, 10, 1, -14),
        BackgroundColor3 = Color3.fromRGB(45, 45, 55),
        BorderSizePixel = 0,
    })
    corner(bar, 3)
    local fill = new("Frame", {
        Parent = bar,
        Size = UDim2.new((val - min) / math.max(max - min, 1), 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(50, 90, 200),
        BorderSizePixel = 0,
    })
    corner(fill, 3)
    local function applyVal(v, fire)
        val = math.clamp(tonumber(v) or min, min, max)
        local rel = (val - min) / math.max(max - min, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        if math.abs(val - math.floor(val)) > 0.001 then
            valLabel.Text = string.format("%.2f", val)
        else
            valLabel.Text = tostring(math.floor(val + 0.5))
        end
        if fire and callback then callback(val) end
    end
    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local rel = (input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
            local raw = min + rel * (max - min)
            if (max - min) >= 5 and min == math.floor(min) and max == math.floor(max) then
                applyVal(math.floor(raw + 0.5), true)
            else
                applyVal(raw, true)
            end
        end
    end)
    return { Get = function() return val end, Set = function(v) applyVal(v, false) end }
end

local function makeButton(page, label, callback)
    local btn = new("TextButton", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(40, 40, 52),
        BorderSizePixel = 0,
        Text = label,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        AutoButtonColor = true,
        LayoutOrder = #page:GetChildren(),
    })
    corner(btn, 6)
    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    return btn
end

local function makeTextBox(page, placeholder, height)
    local box = new("TextBox", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, height or 80),
        BackgroundColor3 = Color3.fromRGB(24, 24, 32),
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = placeholder or "",
        TextColor3 = Color3.fromRGB(220, 220, 230),
        PlaceholderColor3 = Color3.fromRGB(100, 100, 120),
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ClearTextOnFocus = false,
        MultiLine = true,
        LayoutOrder = #page:GetChildren(),
    })
    corner(box, 6)
    stroke(box, Color3.fromRGB(50, 50, 65), 1)
    new("UIPadding", {
        Parent = box,
        PaddingTop = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    })
    return box
end

-- COMBAT
local combat = pages["Combat"]
makeSection(combat, "AIMBOT")
makeToggle(combat, "Aimbot", CFG.Aimbot, function(v) CFG.Aimbot = v end)
makeToggle(combat, "Always On (ignore RMB)", CFG.AimAlways, function(v) CFG.AimAlways = v end)
makeDropdown(combat, "Target", { "Head", "Torso", "Nearest" }, CFG.AimTarget, function(v) CFG.AimTarget = v end)
makeSlider(combat, "Smoothness", 1, 20, CFG.AimSmooth, function(v) CFG.AimSmooth = v end)
makeSlider(combat, "Stickiness", 1, 10, CFG.AimStick, function(v) CFG.AimStick = v end)
makeSlider(combat, "Prediction", 0, 0.25, CFG.AimPred, function(v) CFG.AimPred = v end)
makeSlider(combat, "FOV", 50, 700, CFG.AimFOV, function(v) CFG.AimFOV = v end)
makeSlider(combat, "Max Distance", 100, 2000, CFG.AimMaxDist, function(v) CFG.AimMaxDist = v end)
makeToggle(combat, "Wall Check", CFG.AimWall, function(v) CFG.AimWall = v end)
makeToggle(combat, "Team Check", CFG.AimTeam, function(v) CFG.AimTeam = v end)
makeToggle(combat, "Show FOV Circle", CFG.AimShowFOV, function(v) CFG.AimShowFOV = v end)
makeToggle(combat, "Aim at Dummies / NPCs", CFG.AimNPCs ~= false, function(v) CFG.AimNPCs = v end)

makeSection(combat, "TEAM WHITELIST (FP close ally)")
makeToggle(combat, "Proximity Whitelist", CFG.ProxWhitelist, function(v) CFG.ProxWhitelist = v end)
makeSlider(combat, "Whitelist Distance", 4, 20, CFG.ProxDist, function(v) CFG.ProxDist = v end)
makeToggle(combat, "Aim only in First Person", CFG.AimRequireFP ~= false, function(v) CFG.AimRequireFP = v end)

makeSection(combat, "DEATH LOCK")
makeToggle(combat, "Death Lock", CFG.DeathLock, function(v) CFG.DeathLock = v end)
makeDropdown(combat, "DL Target", { "Head", "Torso", "Nearest" }, CFG.DeathLockTarget, function(v) CFG.DeathLockTarget = v end)
makeSlider(combat, "DL FOV", 100, 1200, CFG.DeathLockFOV or 700, function(v) CFG.DeathLockFOV = v end)
makeSlider(combat, "DL Stickiness", 1, 10, CFG.DeathLockStick or 10, function(v) CFG.DeathLockStick = v end)
makeToggle(combat, "DL Lock Dead Bodies", CFG.DeathLockOnDead ~= false, function(v) CFG.DeathLockOnDead = v end)
makeToggle(combat, "DL Wall Check", CFG.DeathLockWall, function(v) CFG.DeathLockWall = v end)
makeToggle(combat, "DL Team Check", CFG.DeathLockTeam, function(v) CFG.DeathLockTeam = v end)

makeSection(combat, "SILENT AIM")
makeToggle(combat, "Silent Aim", CFG.Silent, function(v) CFG.Silent = v end)
makeDropdown(combat, "Silent Part", { "Head", "Torso", "HumanoidRootPart" }, CFG.SilentPart, function(v) CFG.SilentPart = v end)
makeSlider(combat, "Silent FOV", 40, 400, CFG.SilentFOV, function(v) CFG.SilentFOV = v end)
makeSlider(combat, "Hit Chance %", 1, 100, CFG.SilentHitChance, function(v) CFG.SilentHitChance = v end)
makeToggle(combat, "Silent Team Check", CFG.SilentTeam, function(v) CFG.SilentTeam = v end)

makeSection(combat, "TRIGGERBOT (RMB only)")
makeToggle(combat, "Triggerbot", CFG.TriggerBot, function(v) CFG.TriggerBot = v end)
makeToggle(combat, "Trigger Wall Check", CFG.TriggerWall ~= false, function(v) CFG.TriggerWall = v end)
makeToggle(combat, "Trigger Team Check", CFG.TriggerTeam ~= false, function(v) CFG.TriggerTeam = v end)

local combatStatus = new("TextLabel", {
    Parent = combat,
    Size = UDim2.new(1, 0, 0, 20),
    BackgroundTransparency = 1,
    Text = "status: idle",
    TextColor3 = Color3.fromRGB(140, 150, 170),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 999,
})

-- PLAYERS
local playersPage = pages["Players"]
makeSection(playersPage, "ESP")
makeToggle(playersPage, "ESP Enabled", CFG.ESP, function(v) CFG.ESP = v end)
makeToggle(playersPage, "Boxes", CFG.ESPBox, function(v) CFG.ESPBox = v end)
makeToggle(playersPage, "Names", CFG.ESPName, function(v) CFG.ESPName = v end)
makeToggle(playersPage, "Distance", CFG.ESPDist, function(v) CFG.ESPDist = v end)
makeToggle(playersPage, "Health Bar", CFG.ESPHealth, function(v) CFG.ESPHealth = v end)
makeToggle(playersPage, "Tracers", CFG.ESPTracer, function(v) CFG.ESPTracer = v end)
makeToggle(playersPage, "Skeleton", CFG.ESPSkeleton, function(v) CFG.ESPSkeleton = v end)
makeToggle(playersPage, "Chams (Highlight)", CFG.ESPChams, function(v) CFG.ESPChams = v end)
makeToggle(playersPage, "Team Check (enemies only)", CFG.ESPTeam, function(v) CFG.ESPTeam = v end)
makeSlider(playersPage, "ESP Max Distance", 100, 3000, CFG.ESPMaxDist, function(v) CFG.ESPMaxDist = v end)

-- RAGE
local rage = pages["Rage"]
makeSection(rage, "MOVEMENT")
makeToggle(rage, "Fly", CFG.Fly, function(v) CFG.Fly = v end)
makeSlider(rage, "Fly Speed", 10, 200, CFG.FlySpeed, function(v) CFG.FlySpeed = v end)
makeToggle(rage, "Noclip", CFG.Noclip, function(v) CFG.Noclip = v end)

makeSection(rage, "HITBOX EXPANDER")
makeToggle(rage, "Hitbox Expand", CFG.HitboxExpand, function(v) CFG.HitboxExpand = v end)
makeSlider(rage, "Hitbox Size", 1, 8, CFG.HitboxSize or 2.5, function(v) CFG.HitboxSize = v end)
makeToggle(rage, "Hitbox Team Check", CFG.HitboxTeam ~= false, function(v) CFG.HitboxTeam = v end)

makeSection(rage, "TELEPORT")
makeToggle(rage, "TP Behind Target (hold V)", CFG.TPBehind, function(v) CFG.TPBehind = v end)
makeSlider(rage, "Behind Distance", 2, 12, CFG.TPBehindDist, function(v) CFG.TPBehindDist = v end)
makeButton(rage, "TP to Closest Enemy", function()
    local root = GetClosest3D(2000, true)
    local myRoot = GetRoot(LocalPlayer.Character)
    if root and myRoot then
        myRoot.CFrame = root.CFrame * CFrame.new(0, 0, CFG.TPBehindDist or 4)
    end
end)

-- CONFIGS
local configs = pages["Configs"]
makeSection(configs, "IMPORT / EXPORT")
local configBox = makeTextBox(configs, "paste config text here / export appears here", 120)

local function applyConfigTable(t)
    if type(t) ~= "table" then return false end
    for k, v in pairs(t) do
        if CFG[k] ~= nil then CFG[k] = v end
    end
    CFG.ManualWL = CFG.ManualWL or {}
    CFG.ManualBL = CFG.ManualBL or {}
    -- JSON may stringify UserId keys
    local function normalizeMap(m)
        local out = {}
        if type(m) ~= "table" then return out end
        for k, v in pairs(m) do
            if v then out[tonumber(k) or k] = true end
        end
        return out
    end
    CFG.ManualWL = normalizeMap(CFG.ManualWL)
    CFG.ManualBL = normalizeMap(CFG.ManualBL)
    return true
end

makeButton(configs, "Export Config → box", function()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(CFG) end)
    if ok and encoded then
        configBox.Text = encoded
    else
        local parts = {}
        for k, v in pairs(CFG) do table.insert(parts, string.format("%s=%s", tostring(k), tostring(v))) end
        configBox.Text = table.concat(parts, "\n")
    end
end)

makeButton(configs, "Import Config ← box", function()
    local raw = configBox.Text
    if not raw or #raw < 2 then return end
    local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(t) == "table" then
        applyConfigTable(t)
        configBox.Text = "imported ok"
        return
    end
    for line in string.gmatch(raw, "[^\r\n]+") do
        local k, v = line:match("^(%S+)%s*=%s*(.+)$")
        if k and CFG[k] ~= nil then
            if v == "true" then CFG[k] = true
            elseif v == "false" then CFG[k] = false
            else
                local n = tonumber(v)
                CFG[k] = n ~= nil and n or v
            end
        end
    end
    configBox.Text = "imported (line format)"
end)

makeButton(configs, "Save to file (workspace)", function()
    pcall(function()
        if type(writefile) == "function" then
            writefile(CONFIG_FILE, HttpService:JSONEncode(CFG))
        end
    end)
end)

makeButton(configs, "Load from file", function()
    pcall(function()
        if type(isfile) == "function" and type(readfile) == "function" and isfile(CONFIG_FILE) then
            local body = readfile(CONFIG_FILE)
            local ok, t = pcall(function() return HttpService:JSONDecode(body) end)
            if ok and type(t) == "table" then applyConfigTable(t) end
        end
    end)
end)

makeSection(configs, "UI COLORS")
CFG.UI_AccentName = CFG.UI_AccentName or "Blue"
CFG.UI_BgName = CFG.UI_BgName or "Dark"
CFG.UI_Accent = CFG.UI_Accent or {90, 140, 255}
CFG.UI_Bg = CFG.UI_Bg or {16, 16, 22}

local ACCENT_MAP = {
    Blue = {90, 140, 255},
    Purple = {160, 90, 255},
    Red = {230, 70, 70},
    Green = {70, 200, 110},
    Orange = {255, 160, 50},
    White = {230, 230, 235},
}
local BG_MAP = {
    Dark = {16, 16, 22},
    Charcoal = {22, 22, 26},
    Navy = {12, 16, 28},
    Black = {8, 8, 10},
}

local function accentColor()
    local a = CFG.UI_Accent or {90, 140, 255}
    return Color3.fromRGB(a[1] or 90, a[2] or 140, a[3] or 255)
end
local function bgColor()
    local b = CFG.UI_Bg or {16, 16, 22}
    return Color3.fromRGB(b[1] or 16, b[2] or 16, b[3] or 22)
end

local function applyTheme()
    local ac = accentColor()
    local bg = bgColor()
    pcall(function()
        if main then main.BackgroundColor3 = bg end
        if topBar then
            topBar.BackgroundColor3 = Color3.fromRGB(
                math.clamp((CFG.UI_Bg[1] or 16) + 6, 0, 255),
                math.clamp((CFG.UI_Bg[2] or 16) + 6, 0, 255),
                math.clamp((CFG.UI_Bg[3] or 22) + 8, 0, 255)
            )
        end
        for _, d in ipairs(ScreenGui:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                -- accent-ish blues
                local c = d.TextColor3
                local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
                if (r >= 80 and r <= 130 and g >= 130 and g <= 180 and b >= 220) or (r == 120 and g == 160 and b == 255) then
                    d.TextColor3 = ac
                end
            end
            if d:IsA("Frame") and d:GetAttribute("FW_ThemedBg") then
                d.BackgroundColor3 = bg
            end
            if d:IsA("UIStroke") and d:GetAttribute("FW_ThemedStroke") then
                d.Color = ac
            end
            -- tab buttons selected state often use accent
            if d:IsA("TextButton") and d.Parent and d.Parent.Name == "Tabs" then
                -- leave; selectTab handles
            end
        end
        -- retint FOV circle if present
        if FOVCircle and FOVCircle.Parent then
            pcall(function() FOVCircle.Color3 = ac end)
        end
    end)
end

makeDropdown(configs, "Accent", {"Blue", "Purple", "Red", "Green", "Orange", "White"}, CFG.UI_AccentName or "Blue", function(v)
    CFG.UI_AccentName = v
    CFG.UI_Accent = ACCENT_MAP[v] or ACCENT_MAP.Blue
    applyTheme()
    Notify("accent → " .. v, accentColor())
end)
makeDropdown(configs, "Background", {"Dark", "Charcoal", "Navy", "Black"}, CFG.UI_BgName or "Dark", function(v)
    CFG.UI_BgName = v
    CFG.UI_Bg = BG_MAP[v] or BG_MAP.Dark
    applyTheme()
    Notify("background → " .. v, accentColor())
end)
-- apply saved theme once UI exists
task.defer(applyTheme)

makeSection(configs, "NOTIFICATIONS")
makeToggle(configs, "Notify rival death (closest)", CFG.NotifyRivalDead ~= false, function(v) CFG.NotifyRivalDead = v end)
makeToggle(configs, "Notify team death (WL)", CFG.NotifyTeamDead ~= false, function(v) CFG.NotifyTeamDead = v end)
makeToggle(configs, "Notify possible cheater", CFG.NotifyCheater ~= false, function(v) CFG.NotifyCheater = v end)

makeSection(configs, "PLAYER LISTS")
new("TextLabel", {
    Parent = configs,
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundTransparency = 1,
    Text = "Click a name to move it WL↔BL. Under-mouse buttons add. In FP, teammates can be WL'd from BL. Aim-only-FP still blocks all aim in 3rd.",
    TextColor3 = Color3.fromRGB(130, 140, 160),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = #configs:GetChildren(),
})

local wlHeader = new("TextLabel", {
    Parent = configs,
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "WHITELIST (click → blacklist)",
    TextColor3 = Color3.fromRGB(120, 200, 140),
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = #configs:GetChildren(),
})
local wlListFrame = new("Frame", {
    Parent = configs,
    Size = UDim2.new(1, 0, 0, 8),
    BackgroundTransparency = 1,
    LayoutOrder = #configs:GetChildren(),
})
new("UIListLayout", { Parent = wlListFrame, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })

local blHeader = new("TextLabel", {
    Parent = configs,
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "BLACKLIST (click → whitelist)",
    TextColor3 = Color3.fromRGB(220, 120, 120),
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = #configs:GetChildren(),
})
local blListFrame = new("Frame", {
    Parent = configs,
    Size = UDim2.new(1, 0, 0, 8),
    BackgroundTransparency = 1,
    LayoutOrder = #configs:GetChildren(),
})
new("UIListLayout", { Parent = blListFrame, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })

local function clearChildren(frame)
    for _, c in ipairs(frame:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
end

local function makeListRow(parent, plrName, uid, kind)
    local btn = new("TextButton", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = kind == "wl" and Color3.fromRGB(28, 40, 34) or Color3.fromRGB(42, 28, 30),
        BorderSizePixel = 0,
        Text = "  " .. plrName .. "  [" .. tostring(uid) .. "]",
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = true,
        LayoutOrder = #parent:GetChildren(),
    })
    corner(btn, 5)
    btn.MouseButton1Click:Connect(function()
        CFG.ManualWL = CFG.ManualWL or {}
        CFG.ManualBL = CFG.ManualBL or {}
        if kind == "wl" then
            -- move WL -> BL
            CFG.ManualWL[uid] = nil
            CFG.ManualBL[uid] = true
        else
            -- move BL -> WL (allowed; FP teammate path also uses this)
            CFG.ManualBL[uid] = nil
            CFG.ManualWL[uid] = true
        end
        refreshPlayerLists()
    end)
    return btn
end

function refreshPlayerLists()
    clearChildren(wlListFrame)
    clearChildren(blListFrame)
    local wlCount, blCount = 0, 0
    local wlEntries, blEntries = {}, {}
    for uid, on in pairs(CFG.ManualWL or {}) do
        if on then
            local id = tonumber(uid) or uid
            local p = Players:GetPlayerByUserId(id)
            table.insert(wlEntries, { name = p and p.Name or ("id:" .. tostring(id)), uid = id })
        end
    end
    for uid, on in pairs(CFG.ManualBL or {}) do
        if on then
            local id = tonumber(uid) or uid
            local p = Players:GetPlayerByUserId(id)
            table.insert(blEntries, { name = p and p.Name or ("id:" .. tostring(id)), uid = id })
        end
    end
    table.sort(wlEntries, function(a, b) return a.name:lower() < b.name:lower() end)
    table.sort(blEntries, function(a, b) return a.name:lower() < b.name:lower() end)
    for _, e in ipairs(wlEntries) do
        makeListRow(wlListFrame, e.name, e.uid, "wl")
        wlCount = wlCount + 1
    end
    for _, e in ipairs(blEntries) do
        makeListRow(blListFrame, e.name, e.uid, "bl")
        blCount = blCount + 1
    end
    wlListFrame.Size = UDim2.new(1, 0, 0, math.max(8, wlCount * 29))
    blListFrame.Size = UDim2.new(1, 0, 0, math.max(8, blCount * 29))
    wlHeader.Text = "WHITELIST (click → blacklist)  ·  " .. wlCount
    blHeader.Text = "BLACKLIST (click → whitelist)  ·  " .. blCount
end

makeButton(configs, "Whitelist player under mouse", function()
    local plr = GetPlayerUnderMouse()
    if plr then ToggleManualWL(plr) refreshPlayerLists() end
end)
makeButton(configs, "Blacklist player under mouse", function()
    local plr = GetPlayerUnderMouse()
    if plr then ToggleManualBL(plr) refreshPlayerLists() end
end)
makeButton(configs, "Clear all manual WL / BL", function()
    ClearManualLists()
    refreshPlayerLists()
end)
refreshPlayerLists()

makeSection(configs, "AUTOEXECUTE")
-- Real autoexec = put this loadstring in your executor autoexec folder (Wave/Solara/etc):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/f4n5/loader/refs/heads/main/Loader.luau"))()
-- Toggle below also writes a workspace bootstrap + saves config for next run.
local AUTOEXEC_LOADSTRING = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/f4n5/loader/refs/heads/main/Loader.luau"))()'

makeToggle(configs, "AutoExecute on inject", CFG.AutoExec, function(v)
    CFG.AutoExec = v
    pcall(function()
        if type(writefile) ~= "function" then
            Notify("executor has no writefile — paste loadstring into autoexec folder manually", Color3.fromRGB(230, 180, 100))
            return
        end
        if v then
            -- save current config
            writefile(CONFIG_FILE, HttpService:JSONEncode(CFG))
            -- workspace bootstrap: reload config into getgenv then run loader from github
            local bootstrap = string.format([[
-- FW Loader autoexec bootstrap (workspace)
-- Prefer putting this loadstring in the executor autoexec folder:
-- %s
local HttpService = game:GetService("HttpService")
local genv = (type(getgenv) == "function" and getgenv()) or _G
pcall(function()
    if type(isfile) == "function" and type(readfile) == "function" and isfile("%s") then
        local body = readfile("%s")
        local ok, t = pcall(function() return HttpService:JSONDecode(body) end)
        if ok and type(t) == "table" then genv.FanwareAimAutoCFG = t end
    end
end)
local URL = "https://raw.githubusercontent.com/f4n5/loader/refs/heads/main/Loader.luau"
local ok, body = pcall(function() return game:HttpGet(URL) end)
if ok and type(body) == "string" and #body > 100 and not body:find("<!DOCTYPE") then
    local fn, err = loadstring(body)
    if fn then pcall(fn) else warn("[FW] compile", err) end
else
    warn("[FW] HttpGet Loader failed")
end
]], AUTOEXEC_LOADSTRING, CONFIG_FILE, CONFIG_FILE)
            writefile(AUTOEXEC_FILE, bootstrap)
            -- also try common autoexec folder names if executor supports makefolder
            for _, folder in ipairs({"autoexec", "Autoexec", "AutoExec", "scripts/autoexec"}) do
                pcall(function()
                    if type(makefolder) == "function" then makefolder(folder) end
                    writefile(folder .. "/FW_Loader.luau", AUTOEXEC_LOADSTRING .. "\n")
                end)
            end
            Notify("AutoExec ON — wrote bootstrap + tried autoexec/FW_Loader.luau", Color3.fromRGB(90, 200, 140))
        else
            if type(isfile) == "function" and isfile(AUTOEXEC_FILE) and type(delfile) == "function" then
                pcall(delfile, AUTOEXEC_FILE)
            end
            Notify("AutoExec OFF", Color3.fromRGB(230, 180, 100))
        end
    end)
end)

makeButton(configs, "Copy autoexec loadstring", function()
    local s = AUTOEXEC_LOADSTRING
    if setclipboard then pcall(setclipboard, s) end
    Notify("copied loadstring", Color3.fromRGB(90, 200, 140))
end)

new("TextLabel", {
    Parent = configs,
    Size = UDim2.new(1, 0, 0, 56),
    BackgroundTransparency = 1,
    Text = "AutoExec: turn ON + Save Config. Put Loader.luau (or the loadstring below) in your executor's autoexec folder so it runs on every inject. Config file FanwareAim_Config.txt is written to workspace and reloaded on start.",
    TextColor3 = Color3.fromRGB(130, 140, 160),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 998,
})

pcall(function()
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    if genv and genv.FanwareAimAutoCFG then
        applyConfigTable(genv.FanwareAimAutoCFG)
        genv.FanwareAimAutoCFG = nil
    elseif type(isfile) == "function" and type(readfile) == "function" and isfile(CONFIG_FILE) then
        local body = readfile(CONFIG_FILE)
        local ok, t = pcall(function() return HttpService:JSONDecode(body) end)
        if ok and type(t) == "table" then applyConfigTable(t) end
    end
end)






-- VISUALS — skin by Primary/Secondary/Melee/Utility + charm swap
do
    local vis = pages["Visuals"]
    if vis then

    local EconSkins = (getgenv and getgenv().FW_Skins) or {}
    local EconSkinToWeapon = (getgenv and getgenv().FW_SkinToWeapon) or {}

    local WEAPON_CLASS = {
        ["Assault Rifle"] = "Primary", ["Bow"] = "Primary", ["Burst Rifle"] = "Primary",
        ["Crossbow"] = "Primary", ["Distortion"] = "Primary", ["Energy Rifle"] = "Primary",
        ["Flamethrower"] = "Primary", ["Grenade Launcher"] = "Primary", ["Minigun"] = "Primary",
        ["Paintball Gun"] = "Primary", ["Permafrost"] = "Primary", ["RPG"] = "Primary",
        ["Shotgun"] = "Primary", ["Sniper"] = "Primary", ["Warpstone"] = "Primary",
        ["Daggers"] = "Secondary", ["Energy Pistols"] = "Secondary", ["Exogun"] = "Secondary",
        ["Flare Gun"] = "Secondary", ["Freeze Ray"] = "Secondary", ["Gunblade"] = "Secondary",
        ["Handgun"] = "Secondary", ["Revolver"] = "Secondary", ["Shorty"] = "Secondary",
        ["Slingshot"] = "Secondary", ["Spray"] = "Secondary", ["Uzi"] = "Secondary",
        ["Warper"] = "Secondary", ["Wildcat"] = "Secondary",
        ["Battle Axe"] = "Melee", ["Chainsaw"] = "Melee", ["Fists"] = "Melee",
        ["Katana"] = "Melee", ["Knife"] = "Melee", ["Maul"] = "Melee",
        ["Scythe"] = "Melee", ["Spear"] = "Melee", ["Trowel"] = "Melee",
        ["Flashbang"] = "Utility", ["Grappler"] = "Utility", ["Grenade"] = "Utility",
        ["Jump Pad"] = "Utility", ["Medkit"] = "Utility", ["Molotov"] = "Utility",
        ["Riot Shield"] = "Utility", ["Satchel"] = "Utility", ["Smoke Grenade"] = "Utility",
        ["Subspace Tripmine"] = "Utility", ["War Horn"] = "Utility",
    }
    local CLASS_ORDER = { "Primary", "Secondary", "Melee", "Utility" }

    local function ensureSkinsLoaded(cb)
        if next(EconSkins) then if cb then cb(true) end return end
        task.spawn(function()
            local base = "https://raw.githubusercontent.com/f4n5/loader/refs/heads/main/"
            for _, pair in ipairs({
                { "FW_Skins.luau", "FW_Skins" },
                { "FW_SkinToWeapon.luau", "FW_SkinToWeapon" },
            }) do
                local ok, body = pcall(function() return game:HttpGet(base .. pair[1]) end)
                if ok and type(body) == "string" and #body > 50 and not body:find("<!DOCTYPE") then
                    local ok2, mod = pcall(function() return loadstring(body)() end)
                    if ok2 and type(mod) == "table" and getgenv then getgenv()[pair[2]] = mod end
                end
            end
            EconSkins = (getgenv and getgenv().FW_Skins) or EconSkins
            EconSkinToWeapon = (getgenv and getgenv().FW_SkinToWeapon) or EconSkinToWeapon
            if cb then cb(next(EconSkins) ~= nil) end
        end)
    end

    makeSection(vis, "VISUALS")
    new("TextLabel", {
        Parent = vis,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Text = "Toggle a panel. Skins grouped by Primary / Secondary / Melee / Utility.",
        TextColor3 = Color3.fromRGB(140, 150, 170),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    })

    -- ===== SKIN PANEL =====
    local skinPanel = new("Frame", {
        Parent = vis,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(16, 16, 22),
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = 20,
    })
    corner(skinPanel, 8)
    do
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 6) pad.PaddingBottom = UDim.new(0, 6)
        pad.PaddingLeft = UDim.new(0, 6) pad.PaddingRight = UDim.new(0, 6)
        pad.Parent = skinPanel
        local lay = Instance.new("UIListLayout")
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 4)
        lay.Parent = skinPanel
    end

    local classFilter = "Primary"
    local classRow = new("Frame", {
        Parent = skinPanel,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
    })
    local classLay = Instance.new("UIListLayout")
    classLay.FillDirection = Enum.FillDirection.Horizontal
    classLay.Padding = UDim.new(0, 4)
    classLay.Parent = classRow

    local skinSearch = new("TextBox", {
        Parent = skinPanel,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Color3.fromRGB(22, 22, 30),
        BorderSizePixel = 0,
        PlaceholderText = "search skin or weapon...",
        Text = "",
        TextColor3 = Color3.fromRGB(210, 220, 240),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ClearTextOnFocus = false,
        LayoutOrder = 2,
    })
    corner(skinSearch, 6)

    local skinWeaponLbl = new("TextLabel", {
        Parent = skinPanel,
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "weapon: —",
        TextColor3 = Color3.fromRGB(160, 170, 190),
        Font = Enum.Font.Code,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 3,
    })

    local skinListHolder = new("Frame", {
        Parent = skinPanel,
        Size = UDim2.new(1, 0, 0, 200),
        BackgroundColor3 = Color3.fromRGB(12, 12, 16),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = 4,
    })
    corner(skinListHolder, 6)
    local skinScroll = Instance.new("ScrollingFrame")
    skinScroll.Size = UDim2.new(1, -4, 1, -4)
    skinScroll.Position = UDim2.new(0, 2, 0, 2)
    skinScroll.BackgroundTransparency = 1
    skinScroll.BorderSizePixel = 0
    skinScroll.ScrollBarThickness = 4
    skinScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    skinScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    skinScroll.Parent = skinListHolder
    local skinLayout = Instance.new("UIListLayout")
    skinLayout.Parent = skinScroll
    skinLayout.SortOrder = Enum.SortOrder.LayoutOrder
    skinLayout.Padding = UDim.new(0, 2)

    local selectedSkinName = CFG.SkinId or ""
    local selectedSkinWeapon = CFG.SkinWeapon or ""

    local function clearSkinRows()
        for _, c in ipairs(skinScroll:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
    end

    local function addSkinHeader(text, order)
        local lab = Instance.new("TextLabel")
        lab.Size = UDim2.new(1, -6, 0, 20)
        lab.BackgroundTransparency = 1
        lab.Text = "  " .. text
        lab.TextColor3 = Color3.fromRGB(100, 140, 200)
        lab.Font = Enum.Font.GothamBold
        lab.TextSize = 11
        lab.TextXAlignment = Enum.TextXAlignment.Left
        lab.LayoutOrder = order
        lab.Parent = skinScroll
    end

    local function addSkinRow(text, order, onClick, isDefault, iconId)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 26)
        btn.BackgroundColor3 = isDefault and Color3.fromRGB(30, 40, 36) or Color3.fromRGB(26, 26, 34)
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.LayoutOrder = order
        btn.Parent = skinScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        if iconId then
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.new(0, 22, 0, 22)
            img.Position = UDim2.new(0, 4, 0.5, -11)
            img.BackgroundTransparency = 1
            img.Image = iconId
            img.ScaleType = Enum.ScaleType.Fit
            img.Parent = btn
        end
        local lab = Instance.new("TextLabel")
        lab.Size = UDim2.new(1, iconId and -30 or -8, 1, 0)
        lab.Position = UDim2.new(0, iconId and 28 or 6, 0, 0)
        lab.BackgroundTransparency = 1
        lab.Text = text
        lab.TextColor3 = isDefault and Color3.fromRGB(140, 220, 160) or Color3.fromRGB(210, 215, 230)
        lab.Font = Enum.Font.Code
        lab.TextSize = 11
        lab.TextXAlignment = Enum.TextXAlignment.Left
        lab.Parent = btn
        if onClick then btn.MouseButton1Click:Connect(onClick) end
        return btn
    end

    local function skinsForWeapon(weaponName)
        local list = {}
        for skin, wpn in pairs(EconSkinToWeapon) do
            if wpn == weaponName then list[#list + 1] = skin end
        end
        -- also any EconSkins whose mapped weapon matches
        if #list == 0 then
            for skin, _ in pairs(EconSkins) do
                if EconSkinToWeapon[skin] == weaponName then list[#list + 1] = skin end
            end
        end
        table.sort(list)
        return list
    end

    local function weaponsInClass(className)
        local list = {}
        for wpn, cls in pairs(WEAPON_CLASS) do
            if cls == className then list[#list + 1] = wpn end
        end
        table.sort(list)
        return list
    end

    local function fillSkinList()
        clearSkinRows()
        local filter = string.lower(skinSearch.Text or "")
        local order = 0
        order = order + 1
        addSkinRow("[DEFAULT] restore base", order, function()
            selectedSkinName = ""
            CFG.SkinId = ""
            skinWeaponLbl.Text = "weapon: (default)"
            Notify("default — re-equip weapon in game", Color3.fromRGB(90, 200, 140))
        end, true)

        local weapons = weaponsInClass(classFilter)
        for _, wpn in ipairs(weapons) do
            local skins = skinsForWeapon(wpn)
            -- ViewModels fallback names under cases that map to this weapon
            if #skins == 0 then
                pcall(function()
                    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
                    local vms = ps and ps:FindFirstChild("Assets") and ps.Assets:FindFirstChild("ViewModels")
                    if not vms then return end
                    for _, folder in ipairs(vms:GetChildren()) do
                        if folder.Name ~= "Weapons" then
                            for _, sk in ipairs(folder:GetChildren()) do
                                local mapped = EconSkinToWeapon[sk.Name]
                                if mapped == wpn or string.find(string.lower(sk.Name), string.lower(wpn), 1, true) then
                                    skins[#skins + 1] = sk.Name
                                end
                            end
                        end
                    end
                end)
                table.sort(skins)
            end
            local showWeapon = filter == "" or string.find(string.lower(wpn), filter, 1, true)
            local matchedSkins = {}
            for _, s in ipairs(skins) do
                if filter == "" or string.find(string.lower(s), filter, 1, true) or showWeapon then
                    if filter == "" or string.find(string.lower(s), filter, 1, true) or string.find(string.lower(wpn), filter, 1, true) then
                        matchedSkins[#matchedSkins + 1] = s
                    end
                end
            end
            if filter ~= "" and not showWeapon and #matchedSkins == 0 then
                -- skip
            else
                order = order + 1
                addSkinHeader(wpn .. "  (" .. tostring(#matchedSkins > 0 and #matchedSkins or #skins) .. ")", order)
                local useList = #matchedSkins > 0 and matchedSkins or (filter == "" and skins or matchedSkins)
                for _, skinName in ipairs(useList) do
                    order = order + 1
                    local captured = skinName
                    local capturedW = wpn
                    local iconId = nil
                    local sdata = EconSkins[skinName]
                    if sdata then
                        iconId = sdata.image or sdata.imagehighres -- low-quality / list icon first
                    end
                    addSkinRow(skinName, order, function()
                        selectedSkinName = captured
                        selectedSkinWeapon = capturedW
                        CFG.SkinId = captured
                        CFG.SkinWeapon = capturedW
                        skinWeaponLbl.Text = "weapon: " .. capturedW .. "  ·  skin: " .. captured
                        if iconId then
                            skinWeaponLbl.Text = skinWeaponLbl.Text .. "  ·  icon ok"
                        end
                        Notify(captured .. " → " .. capturedW, Color3.fromRGB(90, 200, 140))
                    end, false, iconId)
                end
            end
        end
    end

    skinSearch:GetPropertyChangedSignal("Text"):Connect(fillSkinList)

    local function setClass(cls)
        classFilter = cls
        for _, c in ipairs(classRow:GetChildren()) do
            if c:IsA("TextButton") then
                c.BackgroundColor3 = (c.Name == cls) and Color3.fromRGB(40, 60, 100) or Color3.fromRGB(28, 28, 36)
            end
        end
        fillSkinList()
    end

    for _, cls in ipairs(CLASS_ORDER) do
        local b = Instance.new("TextButton")
        b.Name = cls
        b.Size = UDim2.new(0, 78, 1, 0)
        b.BackgroundColor3 = (cls == "Primary") and Color3.fromRGB(40, 60, 100) or Color3.fromRGB(28, 28, 36)
        b.BorderSizePixel = 0
        b.Text = cls
        b.TextColor3 = Color3.fromRGB(210, 215, 230)
        b.Font = Enum.Font.Gotham
        b.TextSize = 11
        b.Parent = classRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        local captured = cls
        b.MouseButton1Click:Connect(function() setClass(captured) end)
    end

    local function getViewModels()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local assets = ps and ps:FindFirstChild("Assets")
        return assets and assets:FindFirstChild("ViewModels")
    end

    local function getEquipCosmeticRemote()
        local rs = game:GetService("ReplicatedStorage")
        local remotes = rs:FindFirstChild("Remotes")
        local data = remotes and remotes:FindFirstChild("Data")
        return data and data:FindFirstChild("EquipCosmetic")
    end

    local function fireEquipCosmetic(kind, a, b)
        local remote = getEquipCosmeticRemote()
        if not remote then return false end
        local attempts = {
            function() remote:FireServer(a, b) end,
            function() remote:FireServer(kind, a, b) end,
            function() remote:FireServer({ Type = kind, Name = b, Weapon = a }) end,
            function() remote:FireServer({ cosmeticType = kind, weapon = a, id = b }) end,
            function() remote:FireServer({ Weapon = a, Skin = b }) end,
            function() remote:FireServer(b) end,
            function() remote:InvokeServer(kind, a, b) end,
            function() remote:InvokeServer({ Type = kind, Name = b, Weapon = a }) end,
        }
        local okAny = false
        for _, fn in ipairs(attempts) do if pcall(fn) then okAny = true end end
        return okAny
    end

    local function applyViewModelMesh(skinName, weaponName)
        local vms = getViewModels()
        if not vms then return false, "no ViewModels" end
        local skinModel = nil
        for _, folder in ipairs(vms:GetChildren()) do
            if folder.Name ~= "Weapons" then
                local s = folder:FindFirstChild(skinName)
                if s then skinModel = s break end
            end
        end
        if not skinModel then return false, "skin model missing" end
        local weapons = vms:FindFirstChild("Weapons")
        local weaponPath = weapons and weapons:FindFirstChild(weaponName)
        if not weaponPath then return false, "weapon path missing: " .. tostring(weaponName) end
        local childCount = 0
        for _ in ipairs(skinModel:GetChildren()) do childCount = childCount + 1 end
        if childCount == 0 then return false, "skin empty" end
        local ok = pcall(function()
            weaponPath:ClearAllChildren()
            for _, c in ipairs(skinModel:GetChildren()) do
                c:Clone().Parent = weaponPath
            end
        end)
        if not ok then return false, "clone failed" end
        -- verify something landed
        if #weaponPath:GetChildren() == 0 then return false, "clone empty" end
        return true, "mesh ok"
    end

    -- Replace HUD / hotbar ImageLabels that show the default weapon icon with skin.image
    local function applySkinIcon(weaponName, skinName, imageId)
        if not imageId or imageId == "" then return false end
        local changed = 0
        local function trySet(img)
            if not img or not img:IsA("ImageLabel") and not img:IsA("ImageButton") then return end
            pcall(function()
                img.Image = imageId
                changed = changed + 1
            end)
        end
        local function scan(root, depth)
            if not root or depth > 8 then return end
            for _, d in ipairs(root:GetChildren()) do
                local n = string.lower(d.Name or "")
                local wn = string.lower(weaponName or "")
                local sn = string.lower(skinName or "")
                if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                    if (wn ~= "" and n:find(wn:gsub("%s+", ""), 1, true))
                        or (sn ~= "" and n:find(sn:gsub("%s+", ""), 1, true))
                        or n:find("icon", 1, true) or n:find("slot", 1, true)
                        or n:find("weapon", 1, true) or n:find("skin", 1, true) then
                        trySet(d)
                    end
                end
                if d:IsA("Frame") or d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("ScreenGui") or d:IsA("Folder") then
                    scan(d, depth + 1)
                end
            end
        end
        pcall(function()
            local ps = LocalPlayer:FindFirstChild("PlayerScripts")
            local ui = ps and ps:FindFirstChild("UserInterface")
            if ui then scan(ui, 0) end
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then scan(pg, 0) end
        end)
        if getgenv then
            getgenv().FW_SkinIcons = getgenv().FW_SkinIcons or {}
            getgenv().FW_SkinIcons[weaponName] = imageId
            getgenv().FW_SkinIcons[skinName] = imageId
        end
        return changed > 0
    end

    local function applyAnimsAndSounds(skinName)
        local data = EconSkins[skinName]
        if not data then return false end
        if getgenv then
            getgenv().FW_ActiveSkinAnims = data.anims
            getgenv().FW_ActiveSkinAnimsReverse = data.animsReverse
            getgenv().FW_ActiveSkinName = skinName
        end
        -- preview: play one equip/shoot sound from AnimationLibrary.SoundCallbacks if present
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local sc = rs:FindFirstChild("Modules") and rs.Modules:FindFirstChild("AnimationLibrary") and rs.Modules.AnimationLibrary:FindFirstChild("SoundCallbacks")
            if not sc or not data.anims then return end
            local tryKeys = {}
            for logical, cbName in pairs(data.anims) do
                if logical == "equip" or logical == "Shoot1" or logical == "shoot1" or logical == "idle" then
                    tryKeys[#tryKeys + 1] = cbName
                end
            end
            for _, key in ipairs(tryKeys) do
                local mod = sc:FindFirstChild(key)
                if mod then
                    -- SoundCallbacks modules often return functions; can't always extract id.
                    -- Store active key for hooks.
                    if getgenv then getgenv().FW_ActiveSoundKey = key end
                    break
                end
            end
        end)
        if data.rootoffset then
            pcall(function()
                local vms = getViewModels()
                local weapons = vms and vms:FindFirstChild("Weapons")
                local wname = EconSkinToWeapon[skinName] or selectedSkinWeapon
                local wp = weapons and weapons:FindFirstChild(wname)
                if not wp then return end
                local root = wp:FindFirstChild("Root") or wp:FindFirstChild("Handle") or wp.PrimaryPart
                if root and root:IsA("BasePart") and #data.rootoffset >= 12 then
                    local r = data.rootoffset
                    root.CFrame = CFrame.new(r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12])
                end
            end)
        end
        return true
    end

    local applySkinBtn = new("TextButton", {
        Parent = skinPanel,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Color3.fromRGB(50, 90, 70),
        BorderSizePixel = 0,
        Text = "Apply skin (mesh + anims + remote)",
        TextColor3 = Color3.fromRGB(230, 240, 235),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        LayoutOrder = 10,
    })
    corner(applySkinBtn, 6)
    applySkinBtn.MouseButton1Click:Connect(function()
        if selectedSkinName == "" then
            Notify("pick a skin", Color3.fromRGB(230, 120, 100))
            return
        end
        local w = selectedSkinWeapon ~= "" and selectedSkinWeapon or (EconSkinToWeapon[selectedSkinName] or "")
        local data = EconSkins[selectedSkinName]
        local okR = false
        if w ~= "" then
            okR = fireEquipCosmetic("Skin", w, selectedSkinName) == true
        end
        local okM, meshMsg = applyViewModelMesh(selectedSkinName, w)
        local okA = applyAnimsAndSounds(selectedSkinName)
        -- HUD / slot icon: try replace default weapon icons with skin.image (low quality list icon)
        local okI = false
        if data and data.image then
            okI = applySkinIcon(w, selectedSkinName, data.image)
        end
        local parts = {}
        parts[#parts+1] = okM and "mesh" or "meshX"
        parts[#parts+1] = okA and "animTag" or "animX"
        parts[#parts+1] = okR and "remote" or "remoteX"
        parts[#parts+1] = okI and "icon" or "iconX"
        local any = okM or okA or okR or okI
        Notify(selectedSkinName .. "  " .. table.concat(parts, " · "),
            any and Color3.fromRGB(90, 200, 140) or Color3.fromRGB(230, 120, 100))
    end)

    -- ===== CHARM PANEL =====
    local charmPanel = new("Frame", {
        Parent = vis,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(16, 16, 22),
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = 40,
    })
    corner(charmPanel, 8)
    do
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 6) pad.PaddingBottom = UDim.new(0, 6)
        pad.PaddingLeft = UDim.new(0, 6) pad.PaddingRight = UDim.new(0, 6)
        pad.Parent = charmPanel
        local lay = Instance.new("UIListLayout")
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 4)
        lay.Parent = charmPanel
    end

    new("TextLabel", {
        Parent = charmPanel,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "1) Pick the charm you OWN (equipped). 2) Pick the charm look you want. Apply swaps owned → visual.",
        TextColor3 = Color3.fromRGB(140, 150, 170),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    })

    local ownedCharm = CFG.CharmOwned or ""
    local wantCharm = CFG.CharmWant or ""

    local ownedLbl = new("TextLabel", {
        Parent = charmPanel,
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "owned: —",
        TextColor3 = Color3.fromRGB(160, 170, 190),
        Font = Enum.Font.Code,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
    })
    local wantLbl = new("TextLabel", {
        Parent = charmPanel,
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "replace with: —",
        TextColor3 = Color3.fromRGB(160, 170, 190),
        Font = Enum.Font.Code,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 3,
    })

    local charmSearch = new("TextBox", {
        Parent = charmPanel,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Color3.fromRGB(22, 22, 30),
        BorderSizePixel = 0,
        PlaceholderText = "search charms...",
        Text = "",
        TextColor3 = Color3.fromRGB(210, 220, 240),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ClearTextOnFocus = false,
        LayoutOrder = 4,
    })
    corner(charmSearch, 6)

    local charmListHolder = new("Frame", {
        Parent = charmPanel,
        Size = UDim2.new(1, 0, 0, 160),
        BackgroundColor3 = Color3.fromRGB(12, 12, 16),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = 5,
    })
    corner(charmListHolder, 6)
    local charmScroll = Instance.new("ScrollingFrame")
    charmScroll.Size = UDim2.new(1, -4, 1, -4)
    charmScroll.Position = UDim2.new(0, 2, 0, 2)
    charmScroll.BackgroundTransparency = 1
    charmScroll.BorderSizePixel = 0
    charmScroll.ScrollBarThickness = 4
    charmScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    charmScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    charmScroll.Parent = charmListHolder
    local charmLayout = Instance.new("UIListLayout")
    charmLayout.Parent = charmScroll
    charmLayout.SortOrder = Enum.SortOrder.Name
    charmLayout.Padding = UDim.new(0, 2)

    local charmPickMode = "owned" -- or "want"

    local modeRow = new("Frame", {
        Parent = charmPanel,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = 4.5,
    })
    -- layout order fix: put mode before list — reparent order via LayoutOrder
    modeRow.LayoutOrder = 4
    charmSearch.LayoutOrder = 5
    charmListHolder.LayoutOrder = 6

    local function styleModeBtn(btn, on)
        btn.BackgroundColor3 = on and Color3.fromRGB(40, 60, 100) or Color3.fromRGB(28, 28, 36)
    end
    local btnOwned = Instance.new("TextButton")
    btnOwned.Size = UDim2.new(0.5, -4, 1, 0)
    btnOwned.BackgroundColor3 = Color3.fromRGB(40, 60, 100)
    btnOwned.BorderSizePixel = 0
    btnOwned.Text = "1 · Select OWNED"
    btnOwned.TextColor3 = Color3.fromRGB(210, 215, 230)
    btnOwned.Font = Enum.Font.Gotham
    btnOwned.TextSize = 11
    btnOwned.Parent = modeRow
    Instance.new("UICorner", btnOwned).CornerRadius = UDim.new(0, 6)
    local btnWant = Instance.new("TextButton")
    btnWant.Size = UDim2.new(0.5, -4, 1, 0)
    btnWant.Position = UDim2.new(0.5, 4, 0, 0)
    btnWant.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    btnWant.BorderSizePixel = 0
    btnWant.Text = "2 · Select LOOK"
    btnWant.TextColor3 = Color3.fromRGB(210, 215, 230)
    btnWant.Font = Enum.Font.Gotham
    btnWant.TextSize = 11
    btnWant.Parent = modeRow
    Instance.new("UICorner", btnWant).CornerRadius = UDim.new(0, 6)
    btnOwned.MouseButton1Click:Connect(function()
        charmPickMode = "owned"
        styleModeBtn(btnOwned, true) styleModeBtn(btnWant, false)
    end)
    btnWant.MouseButton1Click:Connect(function()
        charmPickMode = "want"
        styleModeBtn(btnOwned, false) styleModeBtn(btnWant, true)
    end)

    local function listCharms()
        for _, c in ipairs(charmScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local filter = string.lower(charmSearch.Text or "")
        local names = {}
        pcall(function()
            local ps = LocalPlayer:FindFirstChild("PlayerScripts")
            local assets = ps and ps:FindFirstChild("Assets")
            local charms = assets and assets:FindFirstChild("Charms")
            if not charms then return end
            for _, ch in ipairs(charms:GetChildren()) do
                if ch:IsA("Model") or ch:IsA("Folder") or ch:IsA("BasePart") then
                    local n = ch.Name
                    if filter == "" or string.find(string.lower(n), filter, 1, true) then
                        names[#names + 1] = n
                    end
                end
            end
        end)
        table.sort(names)
        for _, name in ipairs(names) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -6, 0, 22)
            btn.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
            btn.BorderSizePixel = 0
            btn.Text = "  " .. name
            btn.TextColor3 = Color3.fromRGB(210, 215, 230)
            btn.Font = Enum.Font.Code
            btn.TextSize = 11
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.Parent = charmScroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            local captured = name
            btn.MouseButton1Click:Connect(function()
                if charmPickMode == "owned" then
                    ownedCharm = captured
                    CFG.CharmOwned = captured
                    ownedLbl.Text = "owned: " .. captured
                    Notify("owned charm: " .. captured, Color3.fromRGB(90, 200, 140))
                else
                    wantCharm = captured
                    CFG.CharmWant = captured
                    wantLbl.Text = "replace with: " .. captured
                    Notify("look: " .. captured, Color3.fromRGB(90, 200, 140))
                end
            end)
        end
        Notify(#names .. " charms", Color3.fromRGB(90, 200, 140))
    end

    charmSearch:GetPropertyChangedSignal("Text"):Connect(listCharms)

    local function applyCharmSwap()
        if ownedCharm == "" or wantCharm == "" then
            Notify("set OWNED and LOOK first", Color3.fromRGB(230, 120, 100))
            return
        end
        local remote = getEquipCosmeticRemote()
        local remotesData = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        remotesData = remotesData and remotesData:FindFirstChild("Data")
        local fav = remotesData and remotesData:FindFirstChild("FavoriteCosmetic")
        if remote then
            pcall(function() remote:FireServer("Charm", wantCharm) end)
            pcall(function() remote:FireServer("Charm", ownedCharm, wantCharm) end)
            pcall(function() remote:FireServer({ Type = "Charm", Name = wantCharm }) end)
            pcall(function() remote:FireServer({ Type = "Charm", From = ownedCharm, To = wantCharm }) end)
            pcall(function() remote:FireServer({ cosmeticType = "Charm", id = wantCharm }) end)
            pcall(function() remote:InvokeServer("Charm", wantCharm) end)
        end
        if fav then
            pcall(function() fav:FireServer("Charm", wantCharm) end)
            pcall(function() fav:FireServer(wantCharm) end)
        end
        if getgenv then
            getgenv().FW_CharmSwap = getgenv().FW_CharmSwap or {}
            getgenv().FW_CharmSwap[ownedCharm] = wantCharm
        end
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local charmsFolder = ps and ps:FindFirstChild("Assets") and ps.Assets:FindFirstChild("Charms")
        local wantM = charmsFolder and charmsFolder:FindFirstChild(wantCharm)
        local ownedM = charmsFolder and charmsFolder:FindFirstChild(ownedCharm)
        if not wantM then
            Notify("look charm model missing in Assets.Charms", Color3.fromRGB(230, 120, 100))
            return
        end
        -- Prefer parenting a clone of WANT onto the live equipped charm attachment (do not edit Assets library)
        local applied = 0
        local function attachClone(parent)
            if not parent then return end
            for _, c in ipairs(parent:GetChildren()) do
                if c.Name == "FW_CharmOverlay" then c:Destroy() end
            end
            local cl = wantM:Clone()
            cl.Name = "FW_CharmOverlay"
            -- hide original children of owned live model if any
            for _, ch in ipairs(parent:GetChildren()) do
                if ch ~= cl and (ch:IsA("BasePart") or ch:IsA("MeshPart") or ch:IsA("Model")) then
                    pcall(function()
                        if ch:IsA("BasePart") then ch.Transparency = 1 end
                        for _, d in ipairs(ch:GetDescendants()) do
                            if d:IsA("BasePart") then d.Transparency = 1 end
                            if d:IsA("Decal") then d.Transparency = 1 end
                        end
                    end)
                end
            end
            cl.Parent = parent
            applied = applied + 1
        end
        local char = LocalPlayer.Character
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if d.Name == ownedCharm then
                    attachClone(d)
                end
            end
            -- charms often under tools
            for _, t in ipairs(char:GetChildren()) do
                if t:IsA("Tool") or t:IsA("Model") then
                    local ch = t:FindFirstChild(ownedCharm, true)
                    if ch then attachClone(ch) end
                    -- sometimes charm is a child named Charm / Attachment
                    for _, a in ipairs(t:GetDescendants()) do
                        if a.Name == "Charm" or a.Name == "CharmAttachment" then
                            attachClone(a)
                        end
                    end
                end
            end
        end
        pcall(function()
            local cam = workspace.CurrentCamera
            if cam then
                for _, d in ipairs(cam:GetDescendants()) do
                    if d.Name == ownedCharm or d.Name == "Charm" then attachClone(d) end
                end
            end
        end)
        Notify(applied > 0 and ("charm live x" .. applied) or "charm tagged (no live mesh found)", Color3.fromRGB(90, 200, 140))
    end

    local applyCharmBtn = new("TextButton", {
        Parent = charmPanel,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Color3.fromRGB(70, 60, 110),
        BorderSizePixel = 0,
        Text = "Apply charm swap",
        TextColor3 = Color3.fromRGB(230, 240, 235),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        LayoutOrder = 10,
    })
    corner(applyCharmBtn, 6)
    applyCharmBtn.MouseButton1Click:Connect(applyCharmSwap)

    makeButton(charmPanel, "Refresh charm list", listCharms)

    -- toggles
    makeToggle(vis, "Skin changer", false, function(v)
        skinPanel.Visible = v
        if v then
            ensureSkinsLoaded(function()
                fillSkinList()
            end)
            fillSkinList()
        end
    end)

    makeToggle(vis, "Charm changer", false, function(v)
        charmPanel.Visible = v
        if v then listCharms() end
    end)


    -- ===== LEADERSTATS SPOOF =====
    local spoofPanel = new("Frame", {
        Parent = vis,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(16, 16, 22),
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = 70,
    })
    corner(spoofPanel, 8)
    do
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 6) pad.PaddingBottom = UDim.new(0, 6)
        pad.PaddingLeft = UDim.new(0, 6) pad.PaddingRight = UDim.new(0, 6)
        pad.Parent = spoofPanel
        local lay = Instance.new("UIListLayout")
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 6)
        lay.Parent = spoofPanel
    end

    new("TextLabel", {
        Parent = spoofPanel,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Text = "Local only — sets IntValues under CustomLeaderstats / leaderstats. Others still see real server values.",
        TextColor3 = Color3.fromRGB(140, 150, 170),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    })

    local function makeSpoofSlider(parent, label, minV, maxV, defaultV, order, onChange)
        local row = new("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1,
            LayoutOrder = order,
        })
        local top = new("TextLabel", {
            Parent = row,
            Size = UDim2.new(1, -70, 0, 16),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = Color3.fromRGB(200, 205, 220),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        local valLab = new("TextLabel", {
            Parent = row,
            Size = UDim2.new(0, 64, 0, 16),
            Position = UDim2.new(1, -64, 0, 0),
            BackgroundTransparency = 1,
            Text = tostring(defaultV),
            TextColor3 = Color3.fromRGB(140, 180, 255),
            Font = Enum.Font.Code,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        local bar = Instance.new("TextButton")
        bar.Size = UDim2.new(1, 0, 0, 16)
        bar.Position = UDim2.new(0, 0, 0, 20)
        bar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        bar.BorderSizePixel = 0
        bar.Text = ""
        bar.AutoButtonColor = false
        bar.Parent = row
        Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(math.clamp((defaultV - minV) / math.max(1, maxV - minV), 0, 1), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
        fill.BorderSizePixel = 0
        fill.Parent = bar
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
        local cur = defaultV
        local function setFromAlpha(a)
            a = math.clamp(a, 0, 1)
            local v = math.floor(minV + (maxV - minV) * a + 0.5)
            cur = v
            fill.Size = UDim2.new(a, 0, 1, 0)
            valLab.Text = tostring(v)
            if onChange then onChange(v) end
        end
        local dragging = false
        local function fromInput(x)
            local abs = bar.AbsolutePosition.X
            local w = bar.AbsoluteSize.X
            if w < 1 then return end
            setFromAlpha((x - abs) / w)
        end
        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                fromInput(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                fromInput(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        return function(v)
            local a = math.clamp((v - minV) / math.max(1, maxV - minV), 0, 1)
            setFromAlpha(a)
        end
    end

    local spoofLevel = CFG.SpoofLevel or 1
    local spoofStreak = CFG.SpoofStreak or 0
    local spoofRank = CFG.SpoofRank or 0

    makeSpoofSlider(spoofPanel, "Level", 1, 999, spoofLevel, 2, function(v)
        spoofLevel = v
        CFG.SpoofLevel = v
    end)
    makeSpoofSlider(spoofPanel, "Win Streak", 0, 500, spoofStreak, 3, function(v)
        spoofStreak = v
        CFG.SpoofStreak = v
    end)
    makeSpoofSlider(spoofPanel, "Rank (ELO / points)", 0, 150000, spoofRank, 4, function(v)
        spoofRank = v
        CFG.SpoofRank = v
    end)

    local function findLeaderstatFolders()
        local out = {}
        for _, name in ipairs({ "CustomLeaderstats", "leaderstats", "Leaderstats", "stats", "Stats" }) do
            local f = LocalPlayer:FindFirstChild(name)
            if f then out[#out + 1] = f end
        end
        return out
    end

    local function setStatValue(folder, names, value)
        for _, n in ipairs(names) do
            local v = folder:FindFirstChild(n)
            if v and (v:IsA("IntValue") or v:IsA("NumberValue") or v:IsA("StringValue")) then
                pcall(function()
                    if v:IsA("StringValue") then
                        v.Value = tostring(value)
                    else
                        v.Value = value
                    end
                end)
                return true
            end
        end
        return false
    end

    local spoofConn = nil
    local function applySpoofOnce()
        local folders = findLeaderstatFolders()
        if #folders == 0 then return false end
        local okAny = false
        for _, folder in ipairs(folders) do
            if setStatValue(folder, { "Level", "level", "Lvl" }, spoofLevel) then okAny = true end
            if setStatValue(folder, { "Win Streak", "WinStreak", "Streak", "winstreak" }, spoofStreak) then okAny = true end
            if setStatValue(folder, { "Current ELO", "ELO", "Elo", "Rank", "MMR", "Points", "RP" }, spoofRank) then okAny = true end
        end
        return okAny
    end

    local function startSpoofLoop()
        if spoofConn then return end
        spoofConn = RunService.Heartbeat:Connect(function()
            if not CFG.SpoofLeaderstats then return end
            applySpoofOnce()
        end)
    end
    local function stopSpoofLoop()
        if spoofConn then
            spoofConn:Disconnect()
            spoofConn = nil
        end
    end

    makeButton(spoofPanel, "Apply spoof now", function()
        local ok = applySpoofOnce()
        Notify(ok and string.format("spoof L%d  streak %d  rank %d", spoofLevel, spoofStreak, spoofRank)
            or "no CustomLeaderstats / leaderstats found",
            ok and Color3.fromRGB(90, 200, 140) or Color3.fromRGB(230, 120, 100))
    end)

    makeToggle(vis, "Leaderstats spoof", CFG.SpoofLeaderstats == true, function(v)
        CFG.SpoofLeaderstats = v
        spoofPanel.Visible = v
        if v then
            startSpoofLoop()
            applySpoofOnce()
            Notify("leaderstats spoof on (local)", Color3.fromRGB(90, 200, 140))
        else
            stopSpoofLoop()
            Notify("leaderstats spoof off", Color3.fromRGB(230, 180, 100))
        end
    end)


    makeSection(vis, "AVATAR (optional)")
    makeToggle(vis, "Force avatar from UserId", CFG.SkinForceAvatar, function(v) CFG.SkinForceAvatar = v end)
    local uidBox = new("TextBox", {
        Parent = vis,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Color3.fromRGB(22, 22, 30),
        BorderSizePixel = 0,
        Text = tostring(CFG.SkinUserId or 0),
        PlaceholderText = "Roblox UserId",
        TextColor3 = Color3.fromRGB(210, 220, 240),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ClearTextOnFocus = false,
        LayoutOrder = 90,
    })
    corner(uidBox, 6)
    makeButton(vis, "Apply avatar", function()
        CFG.SkinUserId = tonumber(uidBox.Text) or 0
        if CFG.SkinUserId == 0 then return end
        task.spawn(function()
            local ok, err = pcall(function()
                local desc = Players:GetHumanoidDescriptionFromUserIdAsync(CFG.SkinUserId)
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum:ApplyDescription(desc) end
            end)
            Notify(ok and "avatar ok" or tostring(err), ok and Color3.fromRGB(90, 200, 140) or Color3.fromRGB(230, 120, 100))
        end)
    end)

    end -- vis
end

local function applyToolTint(force)
    if not CFG.SkinToolTint and not force then return end
    local char = LocalPlayer.Character
    if not char then return end
    local col = Color3.fromRGB(CFG.SkinTintR or 90, CFG.SkinTintG or 140, CFG.SkinTintB or 255)
    local function tint(inst)
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("MeshPart") then
                pcall(function() d.Color = col end)
            end
        end
    end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") or t:IsA("Model") then tint(t) end
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    if not CFG.SkinForceAvatar and not CFG.SkinToolTint then return end
    task.wait(0.6)
    if CFG.SkinForceAvatar and (CFG.SkinUserId or 0) > 0 then
        pcall(function()
            local desc = Players:GetHumanoidDescriptionFromUserIdAsync(CFG.SkinUserId)
            local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 3)
            if hum then hum:ApplyDescription(desc) end
        end)
    end
end)

-- DEX explorer (simple instance browser)
local function buildDexUI()
    local dex = pages["Dex"]
    if not dex then return end
    for _, c in ipairs(dex:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
            c:Destroy()
        end
    end

    makeSection(dex, "DEX EXPLORER")
    new("TextLabel", {
        Parent = dex,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "Click row to enter. Copy path for scrap notes.",
        TextColor3 = Color3.fromRGB(140, 150, 170),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    })

    local pathBox = new("TextBox", {
        Parent = dex,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Color3.fromRGB(22, 22, 30),
        BorderSizePixel = 0,
        Text = "Workspace",
        TextColor3 = Color3.fromRGB(200, 210, 230),
        Font = Enum.Font.Code,
        TextSize = 12,
        ClearTextOnFocus = false,
        LayoutOrder = 2,
    })
    corner(pathBox, 6)

    local listHolder = new("Frame", {
        Parent = dex,
        Size = UDim2.new(1, 0, 0, 230),
        BackgroundColor3 = Color3.fromRGB(18, 18, 24),
        BorderSizePixel = 0,
        LayoutOrder = 3,
        ClipsDescendants = true,
    })
    corner(listHolder, 6)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "DexScroll"
    scroll.Size = UDim2.new(1, -4, 1, -4)
    scroll.Position = UDim2.new(0, 2, 0, 2)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = listHolder

    local listLayout = Instance.new("UIListLayout")
    listLayout.Parent = scroll
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)

    local current -- Instance currently shown

    local function pathOf(inst)
        if not inst then return "?" end
        if inst == game then return "game" end
        local ok, svcName = pcall(function()
            return inst.ClassName
        end)
        -- build path upward
        local parts = {}
        local cur = inst
        local guard = 0
        while cur and cur ~= game and guard < 64 do
            guard = guard + 1
            table.insert(parts, 1, cur.Name)
            local par = cur.Parent
            if not par then break end
            cur = par
        end
        if #parts == 0 then return inst.Name end
        return table.concat(parts, ".")
    end

    local function resolveRoot(name)
        name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" or name == "game" then return game end
        -- try service first
        local ok, svc = pcall(function() return game:GetService(name) end)
        if ok and svc then return svc end
        -- try Workspace child
        local w = workspace:FindFirstChild(name)
        if w then return w end
        -- try game child
        local g = game:FindFirstChild(name)
        if g then return g end
        -- dotted path
        local cur = game
        for part in string.gmatch(name, "[^%.]+") do
            if part == "game" then
                cur = game
            else
                local nxt = nil
                if cur == game then
                    local ok2, s = pcall(function() return game:GetService(part) end)
                    if ok2 and s then nxt = s end
                end
                if not nxt then nxt = cur:FindFirstChild(part) end
                if not nxt then return nil end
                cur = nxt
            end
        end
        return cur
    end

    local function clearRows()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
    end

    local function addRow(text, order, onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 22)
        btn.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(210, 215, 230)
        btn.Font = Enum.Font.Code
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.LayoutOrder = order
        btn.Parent = scroll
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = btn
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 6)
        pad.Parent = btn
        if onClick then
            btn.MouseButton1Click:Connect(onClick)
        end
        return btn
    end

    local function show(inst)
        if not inst then
            pathBox.Text = "invalid"
            clearRows()
            return
        end
        current = inst
        pathBox.Text = pathOf(inst)
        clearRows()
        local order = 0
        if inst ~= game then
            order = order + 1
            addRow("  ..  (parent)", order, function()
                local par = inst.Parent
                if par then show(par) else show(game) end
            end)
        end
        local kids = {}
        local ok, err = pcall(function()
            for _, ch in ipairs(inst:GetChildren()) do
                table.insert(kids, ch)
            end
        end)
        if not ok then
            order = order + 1
            addRow("  [GetChildren failed] " .. tostring(err), order, nil)
            return
        end
        table.sort(kids, function(a, b)
            return string.lower(a.Name) < string.lower(b.Name)
        end)
        for _, ch in ipairs(kids) do
            order = order + 1
            local label = string.format("  %s  [%s]", ch.Name, ch.ClassName)
            local captured = ch
            addRow(label, order, function()
                show(captured)
            end)
        end
        if order == 0 or (order == 1 and inst ~= game) then
            -- only parent row
        end
    end

    makeButton(dex, "Refresh", function()
        if current then show(current) else show(workspace) end
    end)
    makeButton(dex, "Workspace", function() show(workspace) end)
    makeButton(dex, "Players", function() show(game:GetService("Players")) end)
    makeButton(dex, "ReplicatedStorage", function()
        show(game:GetService("ReplicatedStorage"))
    end)
    makeButton(dex, "game services", function() show(game) end)
    makeButton(dex, "Copy path", function()
        local t = pathBox.Text
        pcall(function()
            if setclipboard then setclipboard(t) end
        end)
        Notify("copied: " .. t, Color3.fromRGB(90, 200, 140))
    end)
    makeButton(dex, "Go path box", function()
        local r = resolveRoot(pathBox.Text)
        show(r or workspace)
    end)

    -- start on Workspace (global workspace alias always works)
    task.defer(function()
        show(workspace)
    end)
end

task.defer(buildDexUI)



-- FOV
local fovCircle = new("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, CFG.AimFOV * 2, 0, CFG.AimFOV * 2),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 0,
})
new("UIStroke", {
    Parent = fovCircle,
    Color = Color3.fromRGB(90, 140, 255),
    Thickness = 1.5,
    Transparency = 0.35,
})
new("UICorner", { Parent = fovCircle, CornerRadius = UDim.new(1, 0) })

-- ESP
local ESPFolder = new("Folder", { Name = "FanwareESP", Parent = ScreenGui })
local espDrawings = {}

local function clearESP(plr)
    local d = espDrawings[plr]
    if not d then return end
    for _, obj in pairs(d) do
        if typeof(obj) == "Instance" then obj:Destroy()
        elseif type(obj) == "table" then
            for _, b in pairs(obj) do if typeof(b) == "Instance" then b:Destroy() end end
        end
    end
    espDrawings[plr] = nil
end

local function ensureESP(plr)
    if espDrawings[plr] then return espDrawings[plr] end
    local d = {}
    d.box = new("Frame", { Parent = ESPFolder, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 2 })
    stroke(d.box, Color3.fromRGB(90, 140, 255), 1)
    d.name = new("TextLabel", {
        Parent = ESPFolder, BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(230, 230, 240),
        Font = Enum.Font.GothamMedium, TextSize = 12, Visible = false, ZIndex = 3,
    })
    d.dist = new("TextLabel", {
        Parent = ESPFolder, BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(180, 190, 210),
        Font = Enum.Font.Gotham, TextSize = 11, Visible = false, ZIndex = 3,
    })
    d.healthBg = new("Frame", {
        Parent = ESPFolder, BackgroundColor3 = Color3.fromRGB(20, 20, 28), BorderSizePixel = 0, Visible = false, ZIndex = 2,
    })
    d.healthFill = new("Frame", {
        Parent = d.healthBg, BackgroundColor3 = Color3.fromRGB(80, 220, 100), BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ZIndex = 3,
    })
    d.tracer = new("Frame", {
        Parent = ESPFolder, BackgroundColor3 = Color3.fromRGB(90, 140, 255), BorderSizePixel = 0, Visible = false,
        AnchorPoint = Vector2.new(0.5, 0), ZIndex = 1,
    })
    d.bones = {}
    espDrawings[plr] = d
    return d
end

local function updateChams(plr, on)
    local char = plr.Character
    if not char then return end
    local hl = char:FindFirstChild("FanwareChams")
    if on then
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "FanwareChams"
            hl.FillColor = Color3.fromRGB(90, 140, 255)
            hl.OutlineColor = Color3.fromRGB(200, 220, 255)
            hl.FillTransparency = 0.55
            hl.OutlineTransparency = 0.2
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
        end
        hl.Enabled = true
    else
        if hl then hl:Destroy() end
    end
end

local SKELETON = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
    { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local function lineBetween(a, b, parent)
    local mid = (a + b) / 2
    local dist = (a - b).Magnitude
    local angle = math.atan2(b.Y - a.Y, b.X - a.X)
    return new("Frame", {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(120, 180, 255),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(dist, 1),
        Position = UDim2.fromOffset(mid.X, mid.Y),
        Rotation = math.deg(angle),
        ZIndex = 2,
    })
end

local aimHeld, tpHeld = false, false

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then main.Visible = not main.Visible end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then aimHeld = true end
    if input.KeyCode == Enum.KeyCode.V then tpHeld = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then aimHeld = false end
    if input.KeyCode == Enum.KeyCode.V then tpHeld = false end
end)

local mousemoverel = mousemoverel
local flyBV, flyBG

local function setFly(on)
    local char = LocalPlayer.Character
    local root = GetRoot(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    if not on or not root then return end
    if hum then hum.PlatformStand = true end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = root
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyBG.P = 3e3
    flyBG.Parent = root
end

RunService.RenderStepped:Connect(function()
    Camera = Workspace.CurrentCamera

    if CFG.AimShowFOV and CFG.Aimbot then
        local mouse = UserInputService:GetMouseLocation()
        fovCircle.Visible = true
        fovCircle.Size = UDim2.new(0, CFG.AimFOV * 2, 0, CFG.AimFOV * 2)
        fovCircle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
    else
        fovCircle.Visible = false
    end

    OnCameraModeTick()
    local camOK = AimAllowedByCamera()
    -- Teamcheck:
    -- FP enter → at +1s sample #1, at +2s sample #2 (locks WL) → stop until new FP
    -- 3rd camera held ~2.5s → blacklist ALL
    UpdateFirstPersonStable()
    local fpNow = IsFirstPerson()
    if CFG.ProxWhitelist then
        if fpNow then
            thirdPersonSince = 0
            if not lastWasFP then
                fpSessionStart = tick()
                teamSampleFlags = { false, false }
            end
            local elapsed = tick() - fpSessionStart
            -- check 1 at 2 seconds
            if elapsed >= 2 and not teamSampleFlags[1] then
                teamSampleFlags[1] = true
                RunTeamSample()
            end
            -- check 2 at 4.5 seconds (lock-in)
            if elapsed >= 4.5 and not teamSampleFlags[2] then
                teamSampleFlags[2] = true
                RunTeamSample()
            end
        else
            -- 3rd person: wait THIRD_BL_DELAY then BL everyone (WL cleared only then)
            if thirdPersonSince == 0 then
                thirdPersonSince = tick()
            end
            if (tick() - thirdPersonSince) >= THIRD_BL_DELAY then
                CFG.ManualWL = CFG.ManualWL or {}
                CFG.ManualBL = CFG.ManualBL or {}
                local changed = false
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then
                        if CFG.ManualWL[plr.UserId] or not CFG.ManualBL[plr.UserId] then
                            changed = true
                        end
                        CFG.ManualWL[plr.UserId] = nil
                        CFG.ManualBL[plr.UserId] = true
                    end
                end
                teamSampleFlags = { false, false }
                fpSessionStart = 0
                thirdPersonSince = tick() + 9999 -- fire once until back to FP
                if changed and refreshPlayerLists then pcall(refreshPlayerLists) end
            end
        end
    end
    lastWasFP = fpNow

    if CFG.Silent and not main.Visible and camOK then
        if math.random(1, 100) <= (CFG.SilentHitChance or 100) then
            local _, part = GetClosest(CFG.SilentPart, CFG.SilentFOV, CFG.AimMaxDist, false, CFG.SilentTeam)
            if part then
                -- soft silent: snap camera only (no mouse) when Silent is explicitly on
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, part.Position)
            end
        end
    elseif not CFG.Silent and not CFG.Aimbot and not CFG.DeathLock then
        -- ensure no residual combat status from prior locks
    end

    if CFG.Aimbot and not main.Visible and camOK then
        if CFG.AimAlways or aimHeld then
            if mousemoverel then
                local _, part = GetClosest(CFG.AimTarget, CFG.AimFOV, CFG.AimMaxDist, CFG.AimWall, CFG.AimTeam)
                if part then
                    local aimPos = part.Position
                    if CFG.AimPred > 0 then
                        local root = GetRoot(part.Parent)
                        if root and root.AssemblyLinearVelocity then
                            aimPos = aimPos + root.AssemblyLinearVelocity * CFG.AimPred
                        end
                    end
                    local screenPos, onScreen = Camera:WorldToViewportPoint(aimPos)
                    if onScreen and screenPos.Z > 0 then
                        local mouse = UserInputService:GetMouseLocation()
                        local delta = Vector2.new(screenPos.X, screenPos.Y) - mouse
                        local smooth = math.clamp(CFG.AimSmooth, 1, 20)
                        local stick = math.clamp(CFG.AimStick, 1, 10)
                        local factor = smooth / (stick * 0.85)
                        if factor < 0.35 then factor = 0.35 end
                        mousemoverel(delta.X / factor, delta.Y / factor)
                        combatStatus.Text = "status: locking"
                    else
                        combatStatus.Text = "status: offscreen"
                    end
                else
                    combatStatus.Text = "status: no target"
                end
            else
                combatStatus.Text = "status: no mousemoverel"
            end
        else
            combatStatus.Text = "status: waiting (RMB)"
        end
    elseif not CFG.Aimbot then
        combatStatus.Text = "status: aim off"
    elseif not camOK then
        combatStatus.Text = "status: 3rd person (aim blocked)"
    end

    if CFG.DeathLock and not main.Visible and camOK then
        local fov = CFG.DeathLockFOV or 700
        local allowDead = CFG.DeathLockOnDead ~= false
        local _, part = GetClosestDeathLock(
            CFG.DeathLockTarget,
            fov,
            2000,
            CFG.DeathLockWall,
            CFG.DeathLockTeam,
            allowDead
        )
        if part and mousemoverel then
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen and screenPos.Z > 0 then
                local mouse = UserInputService:GetMouseLocation()
                local dx = screenPos.X - mouse.X
                local dy = screenPos.Y - mouse.Y
                -- stickiness 1-10: higher = snappier, but never divide by near-zero (was overshooting L/R)
                local stick = math.clamp(CFG.DeathLockStick or 6, 1, 10)
                -- map stick 1→div 8 (slow), stick 10→div 1.15 (firm, not infinite)
                local div = 8 - (stick - 1) * (6.85 / 9)
                if div < 1.15 then div = 1.15 end
                -- deadzone so tiny noise doesn't twitch sideways
                if math.abs(dx) > 1.2 or math.abs(dy) > 1.2 then
                    mousemoverel(dx / div, dy / div)
                end
            end
        end
    end

    if CFG.Fly then
        if not flyBV then setFly(true) end
        local root = GetRoot(LocalPlayer.Character)
        if root and flyBV and flyBG then
            local cam = Camera.CFrame
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
            if dir.Magnitude > 0 then dir = dir.Unit end
            flyBV.Velocity = dir * (CFG.FlySpeed or 60)
            flyBG.CFrame = CFrame.new(root.Position, root.Position + cam.LookVector)
        end
    else
        if flyBV then
            setFly(false)
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end

    if CFG.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end

    if CFG.TPBehind and tpHeld then
        local targetRoot = GetClosest3D(1500, true)
        local myRoot = GetRoot(LocalPlayer.Character)
        if targetRoot and myRoot then
            myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, CFG.TPBehindDist or 4)
        end
    end

    -- Triggerbot: only while RMB (aimHeld), only if crosshair center hits a player
    if CFG.TriggerBot and aimHeld and not main.Visible and camOK then
        local viewport = Camera.ViewportSize
        local ray = Camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { LocalPlayer.Character }
        local result = Workspace:Raycast(ray.Origin, ray.Direction * 2500, params)
        if result then
            local model = result.Instance:FindFirstAncestorOfClass("Model")
            local plr = model and Players:GetPlayerFromCharacter(model)
            local ok = plr and plr ~= LocalPlayer
            if ok and CFG.TriggerTeam ~= false then
                ok = CanTarget(plr)
            end
            if ok and CFG.TriggerWall ~= false then
                local part = result.Instance
                ok = IsVisible(part) or true -- ray already hit them; wall between cam handled by ray
            end
            if ok and plr then
                pcall(function()
                    if mouse1click then mouse1click()
                    elseif mouse1press and mouse1release then
                        mouse1press()
                        task.delay(0.02, function() pcall(mouse1release) end)
                    end
                end)
            end
        end
    end

    -- Hitbox expander (client-side parts on rivals)
    if CFG.HitboxExpand then
        local size = math.clamp(CFG.HitboxSize or 2.5, 1, 8)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local allow = true
                if CFG.HitboxTeam ~= false then allow = CanTarget(plr) end
                local char = plr.Character
                if allow and char and IsAlive(char) then
                    for _, name in ipairs({"Head", "HumanoidRootPart", "UpperTorso", "Torso"}) do
                        local p = char:FindFirstChild(name)
                        if p and p:IsA("BasePart") then
                            if not p:GetAttribute("FWHitboxOrig") then
                                p:SetAttribute("FWHitboxOrig", true)
                                p:SetAttribute("FWHitboxSX", p.Size.X)
                                p:SetAttribute("FWHitboxSY", p.Size.Y)
                                p:SetAttribute("FWHitboxSZ", p.Size.Z)
                            end
                            local ox = p:GetAttribute("FWHitboxSX") or p.Size.X
                            local oy = p:GetAttribute("FWHitboxSY") or p.Size.Y
                            local oz = p:GetAttribute("FWHitboxSZ") or p.Size.Z
                            p.Size = Vector3.new(ox * size, oy * size, oz * size)
                            p.Massless = true
                            p.CanCollide = false
                        end
                    end
                end
            end
        end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            local char = plr.Character
            if char then
                for _, name in ipairs({"Head", "HumanoidRootPart", "UpperTorso", "Torso"}) do
                    local p = char:FindFirstChild(name)
                    if p and p:IsA("BasePart") and p:GetAttribute("FWHitboxOrig") then
                        local ox = p:GetAttribute("FWHitboxSX") or 1
                        local oy = p:GetAttribute("FWHitboxSY") or 1
                        local oz = p:GetAttribute("FWHitboxSZ") or 1
                        p.Size = Vector3.new(ox, oy, oz)
                        p:SetAttribute("FWHitboxOrig", nil)
                    end
                end
            end
        end
    end

    local myRoot = GetRoot(LocalPlayer.Character)
    local seen = {}
    if CFG.ESP then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                -- ESP always draws (including WL). combat features stay gated by CanTarget.
                local ok = true
                if CFG.ESPTeam then
                    -- team filter only; WL still visible
                    ok = IsEnemy(plr) or IsWhitelistedAlly(plr) or (CFG.ManualBL and CFG.ManualBL[plr.UserId])
                    if not ok then ok = not IsSameTeam(plr) end
                end
                local char = plr.Character
                local root = GetRoot(char)
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if ok and root and hum and hum.Health > 0 then
                    local dist3 = myRoot and (root.Position - myRoot.Position).Magnitude or 0
                    if dist3 <= (CFG.ESPMaxDist or 2000) then
                        seen[plr] = true
                        local d = ensureESP(plr)
                        local head = char:FindFirstChild("Head") or root
                        local top, topOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.4, 0))
                        local bot, botOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.5, 0))
                        if topOn or botOn then
                            local h = math.abs(bot.Y - top.Y)
                            local w = h * 0.55
                            local cx = (top.X + bot.X) / 2
                            if CFG.ESPBox then
                                d.box.Visible = true
                                d.box.Size = UDim2.fromOffset(w, h)
                                d.box.Position = UDim2.fromOffset(cx - w / 2, top.Y)
                            else d.box.Visible = false end
                            if CFG.ESPName then
                                d.name.Visible = true
                                local isWL = CFG.ManualWL and CFG.ManualWL[plr.UserId]
                                if isWL then
                                    d.name.Text = "TEAM"
                                    d.name.TextColor3 = Color3.fromRGB(80, 220, 120)
                                else
                                    d.name.Text = plr.Name
                                    d.name.TextColor3 = Color3.fromRGB(230, 230, 240)
                                end
                                d.name.Size = UDim2.fromOffset(120, 16)
                                d.name.Position = UDim2.fromOffset(cx - 60, top.Y - 18)
                            else d.name.Visible = false end
                            -- box / tracer / chams tint for WL
                            do
                                local isWL = CFG.ManualWL and CFG.ManualWL[plr.UserId]
                                local teamCol = Color3.fromRGB(80, 220, 120)
                                local enemyCol = Color3.fromRGB(90, 140, 255)
                                local col = isWL and teamCol or enemyCol
                                local s = d.box:FindFirstChildOfClass("UIStroke")
                                if s then s.Color = col end
                                d.tracer.BackgroundColor3 = col
                            end
                            if CFG.ESPDist then
                                d.dist.Visible = true
                                d.dist.Text = string.format("%dm", math.floor(dist3))
                                d.dist.Size = UDim2.fromOffset(60, 14)
                                d.dist.Position = UDim2.fromOffset(cx - 30, bot.Y + 2)
                            else d.dist.Visible = false end
                            if CFG.ESPHealth then
                                local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                                d.healthBg.Visible = true
                                d.healthBg.Size = UDim2.fromOffset(3, h)
                                d.healthBg.Position = UDim2.fromOffset(cx - w / 2 - 5, top.Y)
                                d.healthFill.Size = UDim2.new(1, 0, pct, 0)
                                d.healthFill.Position = UDim2.new(0, 0, 1 - pct, 0)
                                d.healthFill.BackgroundColor3 = Color3.fromRGB(255 * (1 - pct), 220 * pct, 60)
                            else d.healthBg.Visible = false end
                            if CFG.ESPTracer then
                                local from = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                local to = Vector2.new(cx, bot.Y)
                                local mid = (from + to) / 2
                                local len = (from - to).Magnitude
                                local ang = math.deg(math.atan2(to.Y - from.Y, to.X - from.X))
                                d.tracer.Visible = true
                                d.tracer.Size = UDim2.fromOffset(len, 1)
                                d.tracer.Position = UDim2.fromOffset(mid.X, mid.Y)
                                d.tracer.Rotation = ang
                                d.tracer.AnchorPoint = Vector2.new(0.5, 0.5)
                            else d.tracer.Visible = false end
                            for _, f in pairs(d.bones) do f:Destroy() end
                            d.bones = {}
                            if CFG.ESPSkeleton then
                                for _, pair in ipairs(SKELETON) do
                                    local a = char:FindFirstChild(pair[1])
                                    local b = char:FindFirstChild(pair[2])
                                    if a and b then
                                        local pa, oa = Camera:WorldToViewportPoint(a.Position)
                                        local pb, ob = Camera:WorldToViewportPoint(b.Position)
                                        if oa and ob then
                                            table.insert(d.bones, lineBetween(Vector2.new(pa.X, pa.Y), Vector2.new(pb.X, pb.Y), ESPFolder))
                                        end
                                    end
                                end
                            end
                        else
                            d.box.Visible = false
                            d.name.Visible = false
                            d.dist.Visible = false
                            d.healthBg.Visible = false
                            d.tracer.Visible = false
                        end
                        updateChams(plr, CFG.ESPChams)
                    end
                end
            end
        end
    end
    for plr, _ in pairs(espDrawings) do
        if not seen[plr] then
            clearESP(plr)
            updateChams(plr, false)
        end
    end
end)

Players.PlayerRemoving:Connect(function(plr) clearESP(plr) end)


-- death / cheater notifications
local watchedHum = {}
local function watchPlayer(plr)
    local function bind(char)
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 3)
        if not hum then return end
        if watchedHum[hum] then return end
        watchedHum[hum] = true
        hum.Died:Connect(function()
            if plr == LocalPlayer then return end
            local uid = plr.UserId
            local isWL = CFG.ManualWL and CFG.ManualWL[uid]
            -- team death = only WL players
            if isWL then
                if CFG.NotifyTeamDead ~= false then
                    Notify("Team down: " .. plr.Name, Color3.fromRGB(100, 200, 120))
                end
                return
            end
            -- rival death = non-WL, closest to you among currently dead event; range gate
            if CFG.NotifyRivalDead == false then return end
            local myRoot = GetRoot(LocalPlayer.Character)
            if not myRoot then return end
            local theirRoot = GetRoot(char)
            if not theirRoot then
                -- body may already be gone; still notify as rival if under max range later
                Notify("Rival down: " .. plr.Name, Color3.fromRGB(230, 100, 100))
                return
            end
            local deadDist = (myRoot.Position - theirRoot.Position).Magnitude
            if deadDist > 1200 then return end
            -- confirm no other non-WL is strictly closer than this corpse
            local isClosest = true
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= LocalPlayer and other ~= plr then
                    if not (CFG.ManualWL and CFG.ManualWL[other.UserId]) then
                        local r = GetRoot(other.Character)
                        if r and IsAlive(other.Character) then
                            local d = (myRoot.Position - r.Position).Magnitude
                            if d + 0.5 < deadDist then
                                isClosest = false
                                break
                            end
                        end
                    end
                end
            end
            if isClosest then
                Notify("Rival down: " .. plr.Name, Color3.fromRGB(230, 100, 100))
            end
        end)
        -- crude cheater heuristic: insane velocity spikes
        task.spawn(function()
            local last = tick()
            while hum.Parent and hum.Health > 0 do
                local root = GetRoot(char)
                if root and CFG.NotifyCheater ~= false then
                    local v = root.AssemblyLinearVelocity.Magnitude
                    if v > 220 then
                        Notify("Possible cheater: " .. plr.Name .. " (speed)", Color3.fromRGB(255, 180, 60))
                        task.wait(8)
                    end
                end
                task.wait(0.4)
            end
            watchedHum[hum] = nil
        end)
    end
    if plr.Character then bind(plr.Character) end
    plr.CharacterAdded:Connect(bind)
end
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then watchPlayer(plr) end
end
Players.PlayerAdded:Connect(function(plr)
    if plr ~= LocalPlayer then watchPlayer(plr) end
end)

print("[FW Aim] Rivals — RightShift menu | RMB aim | V hold TP behind")
