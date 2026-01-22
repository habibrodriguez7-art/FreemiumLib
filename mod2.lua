
local LIBRARY_URL = "https://raw.githubusercontent.com/habibrodriguez7-art/FreemiumLib/refs/heads/main/lib14.lua"
local Lynx = nil
local librarySuccess, libraryError = pcall(function()
    Lynx = loadstring(game:HttpGet(LIBRARY_URL))()
end)

if not librarySuccess or not Lynx then
    warn("[Lynx] ❌ Gagal memuat Library dari: " .. LIBRARY_URL)
    warn("[Lynx] Error: " .. tostring(libraryError))
else
    -- Library loaded
end

local CombinedModules = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace") or workspace
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local localPlayer = Players.LocalPlayer
local LocalPlayer = localPlayer
local player = localPlayer
local Character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid", 5)

localPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid", 5)
end)

local NetEvents = {
    RF_ChargeFishingRod = nil,
    RF_RequestMinigame = nil,
    RF_CancelFishingInputs = nil,
    RF_UpdateAutoFishingState = nil,
    
    RE_FishingCompleted = nil,
    RE_MinigameChanged = nil,
    RE_FishCaught = nil,
    RE_FishingStopped = nil,
    
    netFolder = nil,
    
    IsInitialized = false
}

local function InitializeNetEvents()
    if NetEvents.IsInitialized then return true end
    
    local success = pcall(function()
        NetEvents.netFolder = ReplicatedStorage
            :WaitForChild("Packages", 5)
            :WaitForChild("_Index", 5)
            :WaitForChild("sleitnick_net@0.2.0", 5)
            :WaitForChild("net", 5)

        NetEvents.RF_ChargeFishingRod = NetEvents.netFolder:WaitForChild("RF/ChargeFishingRod", 5)
        NetEvents.RF_RequestMinigame = NetEvents.netFolder:WaitForChild("RF/RequestFishingMinigameStarted", 5)
        NetEvents.RF_CancelFishingInputs = NetEvents.netFolder:WaitForChild("RF/CancelFishingInputs", 5)
        NetEvents.RF_UpdateAutoFishingState = NetEvents.netFolder:WaitForChild("RF/UpdateAutoFishingState", 5)
        NetEvents.RE_FishingCompleted = NetEvents.netFolder:WaitForChild("RE/FishingCompleted", 5)
        NetEvents.RE_MinigameChanged = NetEvents.netFolder:WaitForChild("RE/FishingMinigameChanged", 5)
        NetEvents.RE_FishCaught = NetEvents.netFolder:WaitForChild("RE/FishCaught", 5)
        NetEvents.RE_FishingStopped = NetEvents.netFolder:WaitForChild("RE/FishingStopped", 5)
    end)
    
    if success and NetEvents.netFolder then
        NetEvents.IsInitialized = true
    else
        warn("⚠️ [NetEvents] Gagal menginisialisasi network events!")
    end
    
    return NetEvents.IsInitialized
end

InitializeNetEvents()

_G.NetEvents = NetEvents
_G.SharedCharacter = Character
_G.SharedHumanoid = Humanoid

local function safeGetConfig(key, default)
    if _G.GetConfigValue and type(_G.GetConfigValue) == "function" then
        local success, value = pcall(function()
            return _G.GetConfigValue(key, default)
        end)
        if success and value ~= nil then
            return value
        end
    end
    return default
end

local function safeFire(func)
    task.spawn(function()
        pcall(func)
    end)
end

local function disableFishingAnim()
    pcall(function()
        local hum = _G.SharedHumanoid or Humanoid
        if not hum then return end
        
        for _, track in pairs(hum:GetPlayingAnimationTracks()) do
            local name = track.Name:lower()
            if name:find("fish") or name:find("rod") or name:find("cast") or name:find("reel") then
                track:Stop(0)
            end
        end
    end)
    
    task.spawn(function()
        local char = _G.SharedCharacter or Character
        if not char then return end
        
        local rod = char:FindFirstChild("Rod") or char:FindFirstChildWhichIsA("Tool")
        if rod and rod:FindFirstChild("Handle") then
            local handle = rod.Handle
            local weld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChildOfClass("Motor6D")
            if weld then
                weld.C0 = CFrame.new(0, -1, -1.2) * CFrame.Angles(math.rad(-10), 0, 0)
            end
        end
    end)
end

CombinedModules.instant = (function()

    if _G.FishingScriptFast then
        pcall(function() _G.FishingScriptFast.Stop() end)
        task.wait(0.1)
    end

    local function loadConfigSettings()
        local maxWait = safeGetConfig("InstantFishing.FishingDelay", 1.30)
        local cancelDelay = safeGetConfig("InstantFishing.CancelDelay", 0.19)
        
        return maxWait, cancelDelay
    end

    local initialMaxWait, initialCancelDelay = loadConfigSettings()

    local fishing = {
        Running = false,
        WaitingHook = false,
        CurrentCycle = 0,
        TotalFish = 0,
        Connections = {},
        Settings = {
            FishingDelay = 0.01,
            CancelDelay = initialCancelDelay,
            HookDetectionDelay = 0.05,
            RetryDelay = 0.1,
            MaxWaitTime = initialMaxWait,
        }
    }

    _G.FishingScriptFast = fishing

    local function refreshSettings()
        local maxWait = safeGetConfig("InstantFishing.FishingDelay", fishing.Settings.MaxWaitTime)
        local cancelDelay = safeGetConfig("InstantFishing.CancelDelay", fishing.Settings.CancelDelay)
        
        fishing.Settings.MaxWaitTime = maxWait
        fishing.Settings.CancelDelay = cancelDelay
    end

    function fishing.Cast()
        if not fishing.Running or fishing.WaitingHook then return end

        disableFishingAnim()
        fishing.CurrentCycle += 1

        local castSuccess = pcall(function()
            NetEvents.RF_ChargeFishingRod:InvokeServer({[10] = tick()})
            task.wait(0.07)
            NetEvents.RF_RequestMinigame:InvokeServer(9, 0, tick())
            fishing.WaitingHook = true

            task.delay(fishing.Settings.MaxWaitTime * 0.7, function()
                if fishing.WaitingHook and fishing.Running then
                    pcall(function()
                        NetEvents.RE_FishingCompleted:FireServer()
                    end)
                end
            end)

            task.delay(fishing.Settings.MaxWaitTime, function()
                if fishing.WaitingHook and fishing.Running then
                    fishing.WaitingHook = false
                    pcall(function()
                        NetEvents.RE_FishingCompleted:FireServer()
                    end)

                    task.wait(fishing.Settings.RetryDelay)
                    pcall(function()
                        NetEvents.RF_CancelFishingInputs:InvokeServer()
                    end)

                    task.wait(fishing.Settings.FishingDelay)
                    if fishing.Running then
                        fishing.Cast()
                    end
                end
            end)
        end)

        if not castSuccess then
            task.wait(fishing.Settings.RetryDelay)
            if fishing.Running then
                fishing.Cast()
            end
        end
    end

    function fishing.Start()
        if fishing.Running then return end

        refreshSettings()
        
        fishing.Running = true
        fishing.CurrentCycle = 0
        fishing.TotalFish = 0

        disableFishingAnim()

        fishing.Connections.Minigame = NetEvents.RE_MinigameChanged.OnClientEvent:Connect(function(state)
            if fishing.WaitingHook and typeof(state) == "string" then
                local s = string.lower(state)
                if string.find(s, "hook") or string.find(s, "bite") or string.find(s, "catch") then
                    fishing.WaitingHook = false
                    task.wait(fishing.Settings.HookDetectionDelay)

                    pcall(function()
                        NetEvents.RE_FishingCompleted:FireServer()
                    end)

                    task.wait(fishing.Settings.CancelDelay)
                    pcall(function()
                        NetEvents.RF_CancelFishingInputs:InvokeServer()
                    end)

                    task.wait(fishing.Settings.FishingDelay)
                    if fishing.Running then
                        fishing.Cast()
                    end
                end
            end
        end)

        fishing.Connections.Caught = NetEvents.RE_FishCaught.OnClientEvent:Connect(function(_, data)
            if fishing.Running then
                fishing.WaitingHook = false
                fishing.TotalFish += 1

                pcall(function()
                    task.wait(fishing.Settings.CancelDelay)
                    NetEvents.RF_CancelFishingInputs:InvokeServer()
                end)

                task.wait(fishing.Settings.FishingDelay)
                if fishing.Running then
                    fishing.Cast()
                end
            end
        end)

        fishing.Connections.AnimDisabler = task.spawn(function()
            while fishing.Running do
                disableFishingAnim()
                task.wait(0.15)
            end
        end)


        task.spawn(function()
            if fishing.Running then
                fishing.Cast()
            end
        end)
    end

    function fishing.Stop()
        if not fishing.Running then return end
        fishing.Running = false
        fishing.WaitingHook = false

        for _, conn in pairs(fishing.Connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            elseif typeof(conn) == "thread" then
                task.cancel(conn)
            end
        end
        fishing.Connections = {}
        
        task.spawn(function()
            pcall(function()
                NetEvents.RF_UpdateAutoFishingState:InvokeServer(true)
            end)
            
            pcall(function()
                NetEvents.RF_CancelFishingInputs:InvokeServer()
            end)
        end)
    end

    function fishing.UpdateSettings(maxWaitTime, cancelDelay)
        if maxWaitTime then
            fishing.Settings.MaxWaitTime = maxWaitTime
        end
        if cancelDelay then
            fishing.Settings.CancelDelay = cancelDelay
        end
    end

    return fishing
end)()

CombinedModules.blatantv1 = (function()

    local UltraBlatant = {}
    UltraBlatant.Active = false
    UltraBlatant.Connections = {} -- Store connections for proper cleanup

    UltraBlatant.Settings = {
        CompleteDelay = 0.001,
        CancelDelay = 0.001
    }

    local function safeFire(func)
        task.spawn(function()
            pcall(func)
        end)
    end

    local spamLoopThread = nil

    local function ultraSpamLoop()
        while UltraBlatant.Active do
            local currentTime = tick()
            
            safeFire(function()
                NetEvents.RF_ChargeFishingRod:InvokeServer({[1] = currentTime})
            end)

            task.wait(0.004)

            safeFire(function()
                NetEvents.RF_RequestMinigame:InvokeServer(1, 0, currentTime)
            end)
            
            task.wait(UltraBlatant.Settings.CompleteDelay)
            
            safeFire(function()
                NetEvents.RE_FishingCompleted:FireServer()
            end)
            
            task.wait(UltraBlatant.Settings.CancelDelay)
            safeFire(function()
                NetEvents.RF_CancelFishingInputs:InvokeServer()
            end)
            safeFire(function()
                NetEvents.RE_FishingCompleted:FireServer()
            end)
            task.wait(0.02)
        end
    end

    function UltraBlatant.UpdateSettings(completeDelay, cancelDelay)
        if completeDelay ~= nil then
            UltraBlatant.Settings.CompleteDelay = completeDelay
        end
        
        if cancelDelay ~= nil then
            UltraBlatant.Settings.CancelDelay = cancelDelay
        end
    end

    function UltraBlatant.Start()
        if UltraBlatant.Active then 
            return
        end
        
        UltraBlatant.Active = true
        
        -- Connect event listener ONLY when feature is active
        UltraBlatant.Connections.Minigame = NetEvents.RE_MinigameChanged.OnClientEvent:Connect(function(state)
            if not UltraBlatant.Active then return end
            
            task.spawn(function()
                task.wait(UltraBlatant.Settings.CompleteDelay)
                
                safeFire(function()
                    NetEvents.RE_FishingCompleted:FireServer()
                end)
                
                task.wait(UltraBlatant.Settings.CancelDelay)
                safeFire(function()
                    NetEvents.RF_CancelFishingInputs:InvokeServer()
                end)
                safeFire(function()
                    NetEvents.RE_FishingCompleted:FireServer()
                end)
                task.wait(0.02)
            end)
        end)
        
        spamLoopThread = task.spawn(ultraSpamLoop)
    end

    function UltraBlatant.Stop()
        if not UltraBlatant.Active then 
            return
        end
        
        UltraBlatant.Active = false
        
        -- Disconnect all connections to prevent memory leak and ping jumping
        for _, conn in pairs(UltraBlatant.Connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
        UltraBlatant.Connections = {}
        
        -- Cancel the spam loop thread
        if spamLoopThread then
            task.cancel(spamLoopThread)
            spamLoopThread = nil
        end
        
        task.wait(0.2)
        
        safeFire(function()
            NetEvents.RF_CancelFishingInputs:InvokeServer()
        end)
        
    end

    return UltraBlatant
end)()

CombinedModules.blatantBETA = (function()
    local UltraBlatant = {}
    UltraBlatant.Active = false

    UltraBlatant.Settings = {
        CompleteDelay = 0.001,
        CancelDelay = 0.001
    }

    local spamLoopThread = nil

    local function ultraSpamLoop()
        while UltraBlatant.Active do
            local currentTime = tick()
            
            safeFire(function()
                NetEvents.RF_ChargeFishingRod:InvokeServer({[1] = currentTime})
            end)

            task.wait(0.001)

            safeFire(function()
                NetEvents.RF_RequestMinigame:InvokeServer(1, 0, currentTime)
            end)
            
            task.wait(UltraBlatant.Settings.CompleteDelay)
            
            safeFire(function()
                NetEvents.RE_FishingCompleted:FireServer()
            end)

            task.wait(UltraBlatant.Settings.CancelDelay)
            safeFire(function()
                NetEvents.RF_CancelFishingInputs:InvokeServer()
            end)

            task.wait(0.080)

        end
    end

    function UltraBlatant.UpdateSettings(completeDelay, cancelDelay)
        if completeDelay ~= nil then
            UltraBlatant.Settings.CompleteDelay = completeDelay
        end
        
        if cancelDelay ~= nil then
            UltraBlatant.Settings.CancelDelay = cancelDelay
        end
    end

    function UltraBlatant.Start()
        if UltraBlatant.Active then 
            return
        end
        
        UltraBlatant.Active = true
        
        spamLoopThread = task.spawn(ultraSpamLoop)
    end

    function UltraBlatant.Stop()
        if not UltraBlatant.Active then 
            return
        end
        
        UltraBlatant.Active = false
        
        -- Cancel the spam loop thread to stop immediately
        if spamLoopThread then
            task.cancel(spamLoopThread)
            spamLoopThread = nil
        end
        
        safeFire(function()
            NetEvents.RF_UpdateAutoFishingState:InvokeServer(true)
        end)

        task.wait(0.2)

        safeFire(function()
            NetEvents.RF_CancelFishingInputs:InvokeServer()
        end)
    end

    return UltraBlatant
end)()

CombinedModules.AntiAFK = (function()
    local AntiAFK = {
        Enabled = false,
        Connection = nil,
        IdledConnectionsDisabled = false
    }

    -- Fungsi untuk menonaktifkan semua koneksi Idled yang sudah ada
    local function DisableIdledConnections()
        pcall(function()
            local player = game:GetService("Players").LocalPlayer
            
            for i, v in pairs(getconnections(player.Idled)) do
                if v.Disable then
                    v:Disable()
                end
            end
            
            AntiAFK.IdledConnectionsDisabled = true
            print("[Anti-AFK] Disabled existing Idled connections")
        end)
    end

    -- Fungsi untuk mengaktifkan kembali koneksi Idled
    local function EnableIdledConnections()
        pcall(function()
            local player = game:GetService("Players").LocalPlayer
            
            for i, v in pairs(getconnections(player.Idled)) do
                if v.Enable then
                    v:Enable()
                end
            end
            
            AntiAFK.IdledConnectionsDisabled = false
            print("[Anti-AFK] Re-enabled existing Idled connections")
        end)
    end

    function AntiAFK.Start()
        if AntiAFK.Enabled then return end
        AntiAFK.Enabled = true

        -- Metode 1: Disable koneksi Idled yang sudah ada (dari script pertama)
        DisableIdledConnections()

        -- Metode 2: Buat koneksi baru untuk menangani event Idled (dari module Anda)
        local VirtualUser = game:GetService("VirtualUser")
        local localPlayer = game:GetService("Players").LocalPlayer

        AntiAFK.Connection = localPlayer.Idled:Connect(function()
            if AntiAFK.Enabled then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
                print("[Anti-AFK] Prevented idle kick")
            end
        end)

        print("[Anti-AFK] Started successfully")
    end

    function AntiAFK.Stop()
        if not AntiAFK.Enabled then return end
        AntiAFK.Enabled = false

        -- Disconnect koneksi custom
        if AntiAFK.Connection then
            AntiAFK.Connection:Disconnect()
            AntiAFK.Connection = nil
        end

        -- Re-enable koneksi Idled yang di-disable sebelumnya
        if AntiAFK.IdledConnectionsDisabled then
            EnableIdledConnections()
        end

        print("[Anti-AFK] Stopped")
    end

    -- Auto-start (opsional, hapus jika tidak diperlukan)
    -- AntiAFK.Start()

    return AntiAFK
end)()

CombinedModules.FPSBooster = (function()
    local FPSBooster = {}
    FPSBooster.Enabled = false

    local RunService = game:GetService("RunService")
    local Terrain = workspace:FindFirstChildOfClass("Terrain")

    local originalStates = {
        reflectance = {},
        transparency = {},
        material = {},
        surfaces = {},
        lighting = {},
        effects = {},
        waterProperties = {},
        decalTextures = {}
    }

    local newObjectConnection = nil

    local function optimizeObject(obj)
        if not FPSBooster.Enabled then return end
        
        pcall(function()
            if obj:IsA("BasePart") then
                if not originalStates.reflectance[obj] then
                    originalStates.reflectance[obj] = obj.Reflectance
                    originalStates.material[obj] = obj.Material
                    originalStates.surfaces[obj] = {
                        BackSurface = obj.BackSurface,
                        BottomSurface = obj.BottomSurface,
                        FrontSurface = obj.FrontSurface,
                        LeftSurface = obj.LeftSurface,
                        RightSurface = obj.RightSurface,
                        TopSurface = obj.TopSurface
                    }
                end
                
                obj.Reflectance = 0
                obj.CastShadow = false
                obj.Material = Enum.Material.Plastic
                obj.BackSurface = Enum.SurfaceType.SmoothNoOutlines
                obj.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
                obj.FrontSurface = Enum.SurfaceType.SmoothNoOutlines
                obj.LeftSurface = Enum.SurfaceType.SmoothNoOutlines
                obj.RightSurface = Enum.SurfaceType.SmoothNoOutlines
                obj.TopSurface = Enum.SurfaceType.SmoothNoOutlines
            end
            
            if obj:IsA("Decal") then
                if not originalStates.transparency[obj] then
                    originalStates.transparency[obj] = obj.Transparency
                    originalStates.decalTextures[obj] = obj.Texture
                end
                obj.Transparency = 1
                obj.Texture = ""
            end
            
            if obj:IsA("Texture") then
                if not originalStates.transparency[obj] then
                    originalStates.transparency[obj] = obj.Transparency
                end
                obj.Transparency = 1
            end
            
            if obj:IsA("SurfaceAppearance") then
                obj:Destroy()
            end
            
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                obj.Enabled = false
            end
            
            if obj:IsA("Beam") then
                obj.Enabled = false
            end
            
            if obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("ForceField") then
                RunService.Heartbeat:Wait()
                obj:Destroy()
            end
        end)
    end

    local function restoreObject(obj)
        pcall(function()
            if obj:IsA("BasePart") then
                if originalStates.reflectance[obj] then
                    obj.Reflectance = originalStates.reflectance[obj]
                    obj.CastShadow = true
                end
                if originalStates.material[obj] then
                    obj.Material = originalStates.material[obj]
                end
                if originalStates.surfaces[obj] then
                    local surfaces = originalStates.surfaces[obj]
                    obj.BackSurface = surfaces.BackSurface
                    obj.BottomSurface = surfaces.BottomSurface
                    obj.FrontSurface = surfaces.FrontSurface
                    obj.LeftSurface = surfaces.LeftSurface
                    obj.RightSurface = surfaces.RightSurface
                    obj.TopSurface = surfaces.TopSurface
                end
            end
            
            if obj:IsA("Decal") then
                if originalStates.transparency[obj] then
                    obj.Transparency = originalStates.transparency[obj]
                end
                if originalStates.decalTextures[obj] then
                    obj.Texture = originalStates.decalTextures[obj]
                end
            end
            
            if obj:IsA("Texture") then
                if originalStates.transparency[obj] then
                    obj.Transparency = originalStates.transparency[obj]
                end
            end
            
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                obj.Enabled = true
            end
            
            if obj:IsA("Beam") then
                obj.Enabled = true
            end
        end)
    end

    function FPSBooster.Enable()
        if FPSBooster.Enabled then
            return false, "Already enabled"
        end
        
        FPSBooster.Enabled = true

        -- Optimize all existing objects
        for _, obj in ipairs(game:GetDescendants()) do
            optimizeObject(obj)
        end

        -- Optimize Terrain water
        if Terrain then
            pcall(function()
                originalStates.waterProperties = {
                    WaterReflectance = Terrain.WaterReflectance,
                    WaterWaveSize = Terrain.WaterWaveSize,
                    WaterWaveSpeed = Terrain.WaterWaveSpeed,
                    WaterTransparency = Terrain.WaterTransparency
                }
                
                Terrain.WaterWaveSize = 0
                Terrain.WaterWaveSpeed = 0
                Terrain.WaterReflectance = 0
                Terrain.WaterTransparency = 1
            end)
        end

        -- Store and modify lighting settings
        originalStates.lighting = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart
        }
        
        Lighting.GlobalShadows = false
        Lighting.FogStart = 9e9
        Lighting.FogEnd = 9e9

        -- Disable post effects
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                originalStates.effects[effect] = effect.Enabled
                effect.Enabled = false
            end
        end

        -- Set quality to lowest
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

        -- Monitor new objects
        newObjectConnection = workspace.DescendantAdded:Connect(function(obj)
            if FPSBooster.Enabled then
                task.spawn(function()
                    if obj:IsA("ForceField") or obj:IsA("Sparkles") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Beam") then
                        RunService.Heartbeat:Wait()
                        obj:Destroy()
                    else
                        task.wait(0.1)
                        optimizeObject(obj)
                    end
                end)
            end
        end)
        
        return true, "FPS Booster enabled"
    end

    function FPSBooster.Disable()
        if not FPSBooster.Enabled then
            return false, "Already disabled"
        end
        
        FPSBooster.Enabled = false

        -- Restore all objects
        for _, obj in ipairs(game:GetDescendants()) do
            restoreObject(obj)
        end
 
        -- Restore terrain water properties
        if Terrain and originalStates.waterProperties then
            pcall(function()
                Terrain.WaterReflectance = originalStates.waterProperties.WaterReflectance
                Terrain.WaterWaveSize = originalStates.waterProperties.WaterWaveSize
                Terrain.WaterWaveSpeed = originalStates.waterProperties.WaterWaveSpeed
                Terrain.WaterTransparency = originalStates.waterProperties.WaterTransparency
            end)
        end

        -- Restore lighting settings
        if originalStates.lighting.GlobalShadows ~= nil then
            Lighting.GlobalShadows = originalStates.lighting.GlobalShadows
            Lighting.FogEnd = originalStates.lighting.FogEnd
            Lighting.FogStart = originalStates.lighting.FogStart
        end
        
        -- Restore post effects
        for effect, state in pairs(originalStates.effects) do
            if effect and effect.Parent then
                effect.Enabled = state
            end
        end
        
        -- Reset quality to automatic
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        
        -- Disconnect new object listener
        if newObjectConnection then
            newObjectConnection:Disconnect()
            newObjectConnection = nil
        end
        
        -- Clear stored states
        originalStates = {
            reflectance = {},
            transparency = {},
            material = {},
            surfaces = {},
            lighting = {},
            effects = {},
            waterProperties = {},
            decalTextures = {}
        }
        
        return true, "FPS Booster disabled"
    end

    function FPSBooster.IsEnabled()
        return FPSBooster.Enabled
    end

    return FPSBooster
end)()

CombinedModules.instant2 = (function()
    if _G.FishingScript then
        pcall(function() _G.FishingScript.Stop() end)
        task.wait(0.1)
    end

    local function loadSavedSettings()
        local maxWait = safeGetConfig("InstantFishing.FishingDelay", 1.5)
        local cancelDelay = safeGetConfig("InstantFishing.CancelDelay", 0.19)
        
        return {
            MaxWaitTime = maxWait,
            CancelDelay = cancelDelay
        }
    end

    local savedSettings = loadSavedSettings()

    local fishing = {
        Running = false,
        WaitingHook = false,
        CurrentCycle = 0,
        TotalFish = 0,
        PerfectCasts = 0,
        AmazingCasts = 0,
        FailedCasts = 0,
        Connections = {},
        Settings = {
            FishingDelay = 0.07,
            CancelDelay = savedSettings.CancelDelay,
            HookDetectionDelay = 0.03,
            RetryDelay = 0.04,
            MaxWaitTime = savedSettings.MaxWaitTime,
            FailTimeout = 2.5,
            PerfectChargeTime = 0.34,
            PerfectReleaseDelay = 0.005,
            PerfectPower = 0.95,
            UseMultiDetection = true,
            UseVisualDetection = true,
            UseSoundDetection = false,
        }
    }

    _G.FishingScript = fishing

    local function refreshSettings()
        local maxWait = safeGetConfig("InstantFishing.FishingDelay", fishing.Settings.MaxWaitTime)
        local cancelDelay = safeGetConfig("InstantFishing.CancelDelay", fishing.Settings.CancelDelay)
        
        fishing.Settings.MaxWaitTime = maxWait
        fishing.Settings.CancelDelay = cancelDelay
    end

    local function disableFishingAnimLocal()
        pcall(function()
            local hum = _G.SharedHumanoid or Humanoid
            if not hum then return end
            
            for _, track in pairs(hum:GetPlayingAnimationTracks()) do
                local name = track.Name:lower()
                if name:find("fish") or name:find("rod") or name:find("cast") or name:find("reel") then
                    track:Stop(0)
                    track.TimePosition = 0
                end
            end
        end)

        task.spawn(function()
            local char = _G.SharedCharacter or Character
            if not char then return end
            
            local rod = char:FindFirstChild("Rod") or char:FindFirstChildWhichIsA("Tool")
            if rod and rod:FindFirstChild("Handle") then
                local handle = rod.Handle
                local weld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChildOfClass("Motor6D")
                if weld then
                    weld.C0 = CFrame.new(0, -1, -1.2) * CFrame.Angles(math.rad(-10), 0, 0)
                end
            end
        end)
    end

    local function handleFailedCast()
        fishing.WaitingHook = false
        fishing.FailedCasts += 1
        
        pcall(function()
            NetEvents.RF_CancelFishingInputs:InvokeServer()
        end)
        
        task.wait(fishing.Settings.RetryDelay)
        
        if fishing.Running then
            fishing.PerfectCast()
        end
    end

    function fishing.PerfectCast()
        if not fishing.Running or fishing.WaitingHook then 
            return 
        end

        disableFishingAnim()
        fishing.CurrentCycle += 1

        local castSuccess = pcall(function()
            local startTime = tick()
            local chargeData = {[1] = startTime}
            
            local chargeResult = NetEvents.RF_ChargeFishingRod:InvokeServer(chargeData)
            if not chargeResult then 
                error("Charge fishing rod failed") 
            end

            local waitTime = fishing.Settings.PerfectChargeTime
            local endTime = tick() + waitTime
            while tick() < endTime and fishing.Running do
                task.wait(0.01)
            end

            task.wait(fishing.Settings.PerfectReleaseDelay)

            local releaseTime = tick()
            local perfectPower = 0.95

            local minigameResult = NetEvents.RF_RequestMinigame:InvokeServer(
                perfectPower,
                0,
                releaseTime
            )
            
            if not minigameResult then 
                handleFailedCast()
                return
            end

            fishing.WaitingHook = true
            local hookDetected = false
            local castStartTime = tick()
            local eventDetection

            eventDetection = NetEvents.RE_MinigameChanged.OnClientEvent:Connect(function(state)
                if fishing.WaitingHook and typeof(state) == "string" then
                    local s = state:lower()
                    if s:find("hook") or s:find("bite") or s:find("catch") or s == "!" then
                        hookDetected = true
                        eventDetection:Disconnect()
                        
                        fishing.WaitingHook = false

                        task.wait(fishing.Settings.HookDetectionDelay)
                        pcall(function()
                            NetEvents.RE_FishingCompleted:FireServer()
                        end)

                        task.wait(fishing.Settings.CancelDelay)
                        pcall(function()
                            NetEvents.RF_CancelFishingInputs:InvokeServer()
                        end)

                        task.wait(fishing.Settings.FishingDelay)
                        if fishing.Running then
                            fishing.PerfectCast()
                        end
                    end
                end
            end)

            task.delay(fishing.Settings.MaxWaitTime, function()
                if fishing.WaitingHook and fishing.Running then
                    if not hookDetected then
                        fishing.WaitingHook = false
                        eventDetection:Disconnect()

                        pcall(function()
                            NetEvents.RE_FishingCompleted:FireServer()
                        end)

                        task.wait(fishing.Settings.RetryDelay)
                        pcall(function()
                            NetEvents.RF_CancelFishingInputs:InvokeServer()
                        end)

                        task.wait(fishing.Settings.FishingDelay)
                        if fishing.Running then
                            fishing.PerfectCast()
                        end
                    end
                end
            end)
            
            task.delay(fishing.Settings.FailTimeout, function()
                if fishing.WaitingHook and fishing.Running then
                    local elapsedTime = tick() - castStartTime
                    
                    if elapsedTime >= fishing.Settings.FailTimeout then
                        if eventDetection then
                            eventDetection:Disconnect()
                        end
                        
                        handleFailedCast()
                    end
                end
            end)
        end)

        if not castSuccess then
            task.wait(fishing.Settings.RetryDelay)
            if fishing.Running then
                fishing.PerfectCast()
            end
        end
    end

    function fishing.Start()
        if fishing.Running then return end
        
        refreshSettings()
        
        fishing.Running = true
        fishing.CurrentCycle = 0
        fishing.TotalFish = 0
        fishing.PerfectCasts = 0
        fishing.AmazingCasts = 0
        fishing.FailedCasts = 0

        disableFishingAnim()

        fishing.Connections.FishingStopped = NetEvents.RE_FishingStopped.OnClientEvent:Connect(function()
            if fishing.Running and fishing.WaitingHook then
                handleFailedCast()
            end
        end)

        fishing.Connections.Caught = NetEvents.RE_FishCaught.OnClientEvent:Connect(function(name, data)
            if fishing.Running then
                fishing.WaitingHook = false
                fishing.TotalFish += 1

                local castResult = data and data.CastResult or "Unknown"
                if castResult == "Perfect" then
                    fishing.PerfectCasts += 1
                elseif castResult == "Amazing" then
                    fishing.AmazingCasts += 1
                end

                task.wait(fishing.Settings.CancelDelay)
                pcall(function()
                    NetEvents.RF_CancelFishingInputs:InvokeServer()
                end)

                task.wait(fishing.Settings.FishingDelay)
                if fishing.Running then
                    fishing.PerfectCast()
                end
            end
        end)

        fishing.Connections.AnimDisabler = task.spawn(function()
            while fishing.Running do
                disableFishingAnim()
                task.wait(0.1)
            end
        end)

        fishing.Connections.StatsReporter = task.spawn(function()
            while fishing.Running do
                task.wait(30)
            end
        end)

        task.wait(0.3)
        fishing.PerfectCast()
    end

    function fishing.Stop()
        if not fishing.Running then return end
        fishing.Running = false
        fishing.WaitingHook = false

        for _, conn in pairs(fishing.Connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            elseif typeof(conn) == "thread" then
                task.cancel(conn)
            end
        end

        fishing.Connections = {}
        
        pcall(function()
            NetEvents.RF_UpdateAutoFishingState:InvokeServer(true)
        end)
        
        task.wait(0.2)
        
        pcall(function()
            NetEvents.RF_CancelFishingInputs:InvokeServer()
        end)
    end

    function fishing.UpdateSettings(maxWaitTime, cancelDelay)
        if maxWaitTime then
            fishing.Settings.MaxWaitTime = maxWaitTime
        end
        if cancelDelay then
            fishing.Settings.CancelDelay = cancelDelay
        end
    end

    return fishing
end)()

CombinedModules.UltraBlatant = (function()
    local UltraBlatant = {}
    UltraBlatant.Active = false
    UltraBlatant.Connections = {} -- Store connections for proper cleanup

    UltraBlatant.Settings = {
        CompleteDelay = 0.73,
        CancelDelay = 0.3,
        ReCastDelay = 0.001
    }

    local FishingState = {
        lastCompleteTime = 0,
        completeCooldown = 0.4
    }

    local fishingLoopThread = nil
    local lastEventTime = 0

    local function protectedComplete()
        local now = tick()
        
        if now - FishingState.lastCompleteTime < FishingState.completeCooldown then
            return false
        end
        
        FishingState.lastCompleteTime = now
        safeFire(function()
            NetEvents.RE_FishingCompleted:FireServer()
        end)
        
        return true
    end

    local function performCast()
        local now = tick()
        
        safeFire(function()
            NetEvents.RF_ChargeFishingRod:InvokeServer({[1] = now})
        end)
        safeFire(function()
            NetEvents.RF_RequestMinigame:InvokeServer(1, 0, now)
        end)
    end

    local function fishingLoop()
        while UltraBlatant.Active do
            performCast()
            
            task.wait(UltraBlatant.Settings.CompleteDelay)
            
            if UltraBlatant.Active then
                protectedComplete()
            end
            
            task.wait(UltraBlatant.Settings.CancelDelay)
            
            if UltraBlatant.Active then
                safeFire(function()
                    NetEvents.RF_CancelFishingInputs:InvokeServer()
                end)
            end
            
            task.wait(UltraBlatant.Settings.ReCastDelay)
        end
    end

    function UltraBlatant.UpdateSettings(completeDelay, cancelDelay, reCastDelay)
        if completeDelay ~= nil then
            UltraBlatant.Settings.CompleteDelay = completeDelay
        end
        
        if cancelDelay ~= nil then
            UltraBlatant.Settings.CancelDelay = cancelDelay
        end
        
        if reCastDelay ~= nil then
            UltraBlatant.Settings.ReCastDelay = reCastDelay
        end
    end

    function UltraBlatant.Start()
        if UltraBlatant.Active then 
            return
        end
        
        UltraBlatant.Active = true
        FishingState.lastCompleteTime = 0
        lastEventTime = 0
        
        -- Connect event listener ONLY when feature is active
        UltraBlatant.Connections.Minigame = NetEvents.RE_MinigameChanged.OnClientEvent:Connect(function(state)
            if not UltraBlatant.Active then return end
            
            local now = tick()
            
            if now - lastEventTime < 0.2 then
                return
            end
            lastEventTime = now
            
            if now - FishingState.lastCompleteTime < 0.3 then
                return
            end
            
            task.spawn(function()
                task.wait(UltraBlatant.Settings.CompleteDelay)
                
                if protectedComplete() then
                    task.wait(UltraBlatant.Settings.CancelDelay)
                    safeFire(function()
                        NetEvents.RF_CancelFishingInputs:InvokeServer()
                    end)
                end
            end)
        end)
        
        safeFire(function()
            NetEvents.RF_UpdateAutoFishingState:InvokeServer(true)
        end)
        
        task.wait(0.2)
        fishingLoopThread = task.spawn(fishingLoop)
    end

    function UltraBlatant.Stop()
        if not UltraBlatant.Active then 
            return
        end
        
        UltraBlatant.Active = false
        
        -- Disconnect all connections to prevent memory leak and ping jumping
        for _, conn in pairs(UltraBlatant.Connections) do
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
        UltraBlatant.Connections = {}
        
        -- Cancel the fishing loop thread
        if fishingLoopThread then
            task.cancel(fishingLoopThread)
            fishingLoopThread = nil
        end
        
        safeFire(function()
            NetEvents.RF_UpdateAutoFishingState:InvokeServer(true)
        end)
        
        task.wait(0.2)
        
        safeFire(function()
            NetEvents.RF_CancelFishingInputs:InvokeServer()
        end)
    end

    return UltraBlatant
end)()

CombinedModules.FreecamModule = (function()

local FreecamModule = {}

local UIS = UserInputService

local Player = localPlayer
local Camera = workspace.CurrentCamera
local PlayerGui = Player:WaitForChild("PlayerGui")

local freecam = false
local camPos = Vector3.new()
local camRot = Vector3.new()
local speed = 50
local sensitivity = 0.3
local hiddenGuis = {}

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

local mobileJoystickInput = Vector3.new(0, 0, 0)
local joystickConnections = {}
local dynamicThumbstick = nil
local thumbstickCenter = Vector2.new(0, 0)
local thumbstickRadius = 60

local cameraTouch = nil
local cameraTouchStartPos = nil
local joystickTouch = nil
local renderConnection = nil
local inputChangedConnection = nil
local inputEndedConnection = nil
local inputBeganConnection = nil

local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

Player.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = Character:WaitForChild("Humanoid")
end)


local function LockCharacter(state)
    if not Humanoid then return end
    
    if state then
        Humanoid.WalkSpeed = 0
        Humanoid.JumpPower = 0
        Humanoid.AutoRotate = false
        if Character:FindFirstChild("HumanoidRootPart") then
            Character.HumanoidRootPart.Anchored = true
        end
    else
        Humanoid.WalkSpeed = 16
        Humanoid.JumpPower = 50
        Humanoid.AutoRotate = true
        if Character:FindFirstChild("HumanoidRootPart") then
            Character.HumanoidRootPart.Anchored = false
        end
    end
end

local function HideAllGuis()
    hiddenGuis = {}
    
    for _, gui in pairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            if mainGuiName and gui.Name == mainGuiName then
                continue
            end
            
            local guiName = gui.Name:lower()
            if guiName:find("main") or guiName:find("hub") or guiName:find("menu") or guiName:find("ui") then
                continue
            end
            
            table.insert(hiddenGuis, gui)
            gui.Enabled = false
        end
    end
end

local function ShowAllGuis()
    for _, gui in pairs(hiddenGuis) do
        if gui and gui:IsA("ScreenGui") then
            gui.Enabled = true
        end
    end
    
    hiddenGuis = {}
end

local function GetMovement()
    local move = Vector3.zero
    
    if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + Vector3.new(0, 0, 1) end
    if UIS:IsKeyDown(Enum.KeyCode.S) then move = move + Vector3.new(0, 0, -1) end
    if UIS:IsKeyDown(Enum.KeyCode.A) then move = move + Vector3.new(-1, 0, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + Vector3.new(1, 0, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then 
        move = move + Vector3.new(0, 1, 0) 
    end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.Q) then 
        move = move + Vector3.new(0, -1, 0) 
    end
    
    if isMobile then
        move = move + mobileJoystickInput
    end
    
    return move
end


local function DetectDynamicThumbstick()
    if not isMobile then return end
    
    local function searchForThumbstick(parent, depth)
        depth = depth or 0
        if depth > 10 then return end
        
        for _, child in pairs(parent:GetChildren()) do
            local name = child.Name:lower()
            if name:find("thumbstick") or name:find("joystick") then
                if child:IsA("Frame") then
                    return child
                end
            end
            local result = searchForThumbstick(child, depth + 1)
            if result then return result end
        end
        return nil
    end
    
    pcall(function()
        dynamicThumbstick = searchForThumbstick(PlayerGui)
        
        if dynamicThumbstick then
            local pos = dynamicThumbstick.AbsolutePosition
            local size = dynamicThumbstick.AbsoluteSize
            thumbstickCenter = pos + (size / 2)
            thumbstickRadius = math.min(size.X, size.Y) / 2
        end
    end)
end

local function IsPositionInThumbstick(pos)
    if not dynamicThumbstick then return false end
    
    local thumbPos = dynamicThumbstick.AbsolutePosition
    local thumbSize = dynamicThumbstick.AbsoluteSize
    
    local isWithinX = pos.X >= thumbPos.X - 50 and pos.X <= (thumbPos.X + thumbSize.X + 50)
    local isWithinY = pos.Y >= thumbPos.Y - 50 and pos.Y <= (thumbPos.Y + thumbSize.Y + 50)
    
    return isWithinX and isWithinY
end

local function GetJoystickInput(touchPos)
    if not dynamicThumbstick then return Vector3.new(0, 0, 0) end
    
    local touchPos2D = Vector2.new(touchPos.X, touchPos.Y)
    local delta = touchPos2D - thumbstickCenter
    local magnitude = delta.Magnitude
    
    if magnitude < 5 then
        return Vector3.new(0, 0, 0)
    end
    
    local maxDist = thumbstickRadius
    local normalized = delta / maxDist
    
    normalized = Vector2.new(
        math.max(-1, math.min(1, normalized.X)),
        math.max(-1, math.min(1, normalized.Y))
    )
    
    return Vector3.new(normalized.X, 0, normalized.Y)
end


function FreecamModule.Start()
    if freecam then return end
    
    freecam = true
    
    local currentCF = Camera.CFrame
    camPos = currentCF.Position
    local x, y, z = currentCF:ToEulerAnglesYXZ()
    camRot = Vector3.new(x, y, z)
    
    LockCharacter(true)
    HideAllGuis()
    Camera.CameraType = Enum.CameraType.Scriptable
    
    task.wait()
    
    if not isMobile then
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
        UIS.MouseIconEnabled = false
    else
        DetectDynamicThumbstick()
    end
    
    if isMobile then
        inputBeganConnection = UIS.InputBegan:Connect(function(input, gameProcessed)
            if not freecam then return end
            
            if input.UserInputType == Enum.UserInputType.Touch then
                local pos = input.Position
                
                local isInThumbstick = false
                pcall(function()
                    isInThumbstick = IsPositionInThumbstick(pos)
                end)
                
                if isInThumbstick then
                    joystickTouch = input
                else
                    cameraTouch = input
                    cameraTouchStartPos = input.Position
                end
            end
        end)
        
        inputChangedConnection = UIS.InputChanged:Connect(function(input, gameProcessed)
            if not freecam then return end
            
            if input.UserInputType == Enum.UserInputType.Touch then
                if input == joystickTouch then
                    pcall(function()
                        mobileJoystickInput = GetJoystickInput(input.Position)
                    end)
                end
                
                if input == cameraTouch and cameraTouch then
                    local delta = input.Position - cameraTouchStartPos
                    
                    if delta.Magnitude > 0 then
                        camRot = camRot + Vector3.new(
                            -delta.Y * sensitivity * 0.003,
                            -delta.X * sensitivity * 0.003,
                            0
                        )
                        
                        cameraTouchStartPos = input.Position
                    end
                end
            end
        end)
        
        inputEndedConnection = UIS.InputEnded:Connect(function(input, gameProcessed)
            if not freecam then return end
            
            if input.UserInputType == Enum.UserInputType.Touch then
                if input == joystickTouch then
                    joystickTouch = nil
                    mobileJoystickInput = Vector3.new(0, 0, 0)
                end
                
                if input == cameraTouch then
                    cameraTouch = nil
                    cameraTouchStartPos = nil
                end
            end
        end)
    end
    
    renderConnection = RunService.RenderStepped:Connect(function(dt)
        if not freecam then return end
        
        if not isMobile then
            local mouseDelta = UIS:GetMouseDelta()
            
            if mouseDelta.Magnitude > 0 then
                camRot = camRot + Vector3.new(
                    -mouseDelta.Y * sensitivity * 0.01,
                    -mouseDelta.X * sensitivity * 0.01,
                    0
                )
            end
        end
        
        local rotationCF = CFrame.new(camPos) * CFrame.fromEulerAnglesYXZ(camRot.X, camRot.Y, camRot.Z)
        
        local moveInput = GetMovement()
        if moveInput.Magnitude > 0 then
            moveInput = moveInput.Unit
            
            local moveCF = CFrame.new(camPos) * CFrame.fromEulerAnglesYXZ(camRot.X, camRot.Y, camRot.Z)
            local velocity = (moveCF.LookVector * moveInput.Z) +
                             (moveCF.RightVector * moveInput.X) +
                             (moveCF.UpVector * moveInput.Y)
            
            camPos = camPos + velocity * speed * dt
        end
        
        Camera.CFrame = CFrame.new(camPos) * CFrame.fromEulerAnglesYXZ(camRot.X, camRot.Y, camRot.Z)
    end)
    
    return true
end

function FreecamModule.Stop()
    if not freecam then return end
    
    freecam = false
    
    if UserInputService.KeyboardEnabled and F3_NOTIFICATION_SHOWN then
        F3_NOTIFICATION_SHOWN = false
    end
    
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    
    if inputChangedConnection then
        inputChangedConnection:Disconnect()
        inputChangedConnection = nil
    end
    
    if inputEndedConnection then
        inputEndedConnection:Disconnect()
        inputEndedConnection = nil
    end
    
    if inputBeganConnection then
        inputBeganConnection:Disconnect()
        inputBeganConnection = nil
    end
    
    for _, conn in pairs(joystickConnections) do
        if conn then
            conn:Disconnect()
        end
    end
    joystickConnections = {}
    
    LockCharacter(false)
    ShowAllGuis()
    Camera.CameraType = Enum.CameraType.Custom
    Camera.CameraSubject = Humanoid
    
    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true
    
    cameraTouch = nil
    cameraTouchStartPos = nil
    joystickTouch = nil
    mobileJoystickInput = Vector3.new(0, 0, 0)
    
    return true
end

function FreecamModule.Toggle()
    if freecam then
        return FreecamModule.Stop()
    else
        return FreecamModule.Start()
    end
end

function FreecamModule.IsActive()
    return freecam
end

function FreecamModule.SetSpeed(newSpeed)
    speed = math.max(1, newSpeed)
end

function FreecamModule.SetSensitivity(newSensitivity)
    sensitivity = math.max(0.01, math.min(5, newSensitivity))
end

function FreecamModule.GetSpeed()
    return speed
end

function FreecamModule.GetSensitivity()
    return sensitivity
end

local mainGuiName = nil

function FreecamModule.SetMainGuiName(guiName)
    mainGuiName = guiName
end

function FreecamModule.GetMainGuiName()
    return mainGuiName
end

local f3KeybindActive = false

function FreecamModule.EnableF3Keybind(enable)
    f3KeybindActive = enable
    
    if not enable and freecam then
        FreecamModule.Stop()
    end
    
    if not isMobile then
        local status = f3KeybindActive and "ENABLED (Press F3 to activate)" or "DISABLED"
    end
end

function FreecamModule.IsF3KeybindActive()
    return f3KeybindActive
end

if not isMobile then
    UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.F3 and f3KeybindActive then
            FreecamModule.Toggle()
            
            if freecam then
            else
            end
        end
    end)
end


return FreecamModule
end)()

CombinedModules.UnlimitedZoom = (function()
local UnlimitedZoomModule = {}

local originalMinZoom = localPlayer.CameraMinZoomDistance
local originalMaxZoom = localPlayer.CameraMaxZoomDistance

local unlimitedZoomActive = false

function UnlimitedZoomModule.Enable()
    if unlimitedZoomActive then return false end
    
    unlimitedZoomActive = true
    
    localPlayer.CameraMinZoomDistance = 0.5
    localPlayer.CameraMaxZoomDistance = 9999
    
    return true
end

function UnlimitedZoomModule.Disable()
    if not unlimitedZoomActive then return false end
    
    unlimitedZoomActive = false
    
    localPlayer.CameraMinZoomDistance = originalMinZoom or 0.5
    localPlayer.CameraMaxZoomDistance = originalMaxZoom or 128 -- Default Roblox limit
    
    return true
end

function UnlimitedZoomModule.IsActive()
    return unlimitedZoomActive
end


return UnlimitedZoomModule
end)()

CombinedModules.DisableRendering = (function()
local DisableRendering = {}

DisableRendering.Settings = {
    AutoPersist = true -- Keep active after respawn
}

local State = {
    RenderingDisabled = false,
    RenderConnection = nil
}

function DisableRendering.Start()
    if State.RenderingDisabled then
        return false, "Already disabled"
    end
    
    local success, err = pcall(function()
        -- Disable 3D rendering
        State.RenderConnection = RunService.RenderStepped:Connect(function()
            pcall(function()
                RunService:Set3dRenderingEnabled(false)
            end)
        end)
        
        State.RenderingDisabled = true
    end)
    
    if not success then
        warn("[DisableRendering] Failed to start:", err)
        return false, "Failed to start"
    end
    
    return true, "Rendering disabled"
end

function DisableRendering.Stop()
    if not State.RenderingDisabled then
        return false, "Already enabled"
    end
    
    local success, err = pcall(function()
        -- Disconnect render loop
        if State.RenderConnection then
            State.RenderConnection:Disconnect()
            State.RenderConnection = nil
        end
        
        -- Re-enable rendering
        RunService:Set3dRenderingEnabled(true)
        
        State.RenderingDisabled = false
    end)
    
    if not success then
        warn("[DisableRendering] Failed to stop:", err)
        return false, "Failed to stop"
    end
    
    return true, "Rendering enabled"
end

function DisableRendering.Toggle()
    if State.RenderingDisabled then
        return DisableRendering.Stop()
    else
        return DisableRendering.Start()
    end
end

function DisableRendering.IsDisabled()
    return State.RenderingDisabled
end

if DisableRendering.Settings.AutoPersist then
    LocalPlayer.CharacterAdded:Connect(function()
        if State.RenderingDisabled then
            task.wait(0.5)
            pcall(function()
                RunService:Set3dRenderingEnabled(false)
            end)
        end
    end)
end

function DisableRendering.Cleanup()
    if State.RenderingDisabled then
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
    end
    
    if State.RenderConnection then
        State.RenderConnection:Disconnect()
    end
end

return DisableRendering
end)()

CombinedModules.HideStats = (function()
local HideStatsModule = {}

local HideStatsEnabled = false
local FakeName = "Bagi Sikrit bang"
local FakeLevel = "1"
local ScriptName = "-LynX-"

local OriginalTexts = {}
local ActiveGradientThreads = {}

local ShimmerColors = {
    Color3.fromRGB(255, 140, 0),   -- Dark Orange
    Color3.fromRGB(255, 180, 50),  -- Orange
    Color3.fromRGB(255, 220, 150), -- Light Orange
    Color3.fromRGB(255, 255, 255), -- Putih (kilau)
    Color3.fromRGB(255, 220, 150), -- Light Orange
    Color3.fromRGB(255, 180, 50),  -- Orange
    Color3.fromRGB(255, 140, 0),   -- Dark Orange
}

local function createMovingGradient(label)
    if not label or not label:IsA("TextLabel") then return end
    
    local oldGradient = label:FindFirstChild("ShimmerGradient")
    if oldGradient then oldGradient:Destroy() end
    
    local gradient = Instance.new("UIGradient")
    gradient.Name = "ShimmerGradient"
    gradient.Parent = label
    
    local colorKeypoints = {}
    
    local basePattern = {
        {0.00, Color3.fromRGB(255, 140, 0)},
        {0.10, Color3.fromRGB(255, 160, 30)},
        {0.20, Color3.fromRGB(255, 200, 100)},
        {0.30, Color3.fromRGB(255, 255, 255)},
        {0.40, Color3.fromRGB(255, 200, 100)},
        {0.50, Color3.fromRGB(255, 160, 30)},
        {0.60, Color3.fromRGB(255, 140, 0)},
        {0.70, Color3.fromRGB(255, 160, 30)},
        {0.80, Color3.fromRGB(255, 200, 100)},
        {0.90, Color3.fromRGB(255, 255, 255)},
        {1.00, Color3.fromRGB(255, 140, 0)},
    }
    
    for _, data in ipairs(basePattern) do
        table.insert(colorKeypoints, ColorSequenceKeypoint.new(data[1], data[2]))
    end
    
    gradient.Color = ColorSequence.new(colorKeypoints)
    
    local threadId = tostring(label)
    ActiveGradientThreads[threadId] = true
    
    spawn(function()
        local offset = 0
        while label and label.Parent and ActiveGradientThreads[threadId] do
            offset = offset + 0.015
            if offset >= 1 then
                offset = 0
            end
            
            gradient.Offset = Vector2.new(offset, 0)
            wait(0.02)
        end
    end)
    
    return gradient
end

local function createScriptNameLabel(nameLabel, billboard)
    if not nameLabel or not billboard then return end
    
    local existingFrame = billboard:FindFirstChild("LynxFrame")
    if existingFrame then 
        return existingFrame
    end
    
    local nameFrame = nameLabel.Parent
    if not nameFrame or not nameFrame:IsA("Frame") then return end
    
    local originalNamePos = nameFrame.Position
    nameFrame.Position = UDim2.new(
        originalNamePos.X.Scale,
        originalNamePos.X.Offset,
        originalNamePos.Y.Scale + 0.25,
        originalNamePos.Y.Offset
    )
    
    local lynxFrame = Instance.new("Frame")
    lynxFrame.Name = "LynxFrame"
    lynxFrame.Size = nameFrame.Size
    lynxFrame.Position = originalNamePos
    lynxFrame.BackgroundTransparency = 1
    lynxFrame.Parent = billboard
    
    local scriptLabel = nameLabel:Clone()
    scriptLabel.Name = "LynxLabel"
    scriptLabel.Text = ScriptName
    scriptLabel.TextScaled = true
    scriptLabel.Font = Enum.Font.GothamBold
    scriptLabel.TextStrokeTransparency = 0.5
    scriptLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    scriptLabel.Parent = lynxFrame
    
    createMovingGradient(scriptLabel)
    
    return lynxFrame
end

local function removeAllScriptNames()
    local character = LocalPlayer.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local overhead = hrp:FindFirstChild("Overhead")
    if not overhead then return end
    
    local lynxFrame = overhead:FindFirstChild("LynxFrame")
    if lynxFrame then
        for threadId, _ in pairs(ActiveGradientThreads) do
            ActiveGradientThreads[threadId] = nil
        end
        
        local nameLabel = overhead:FindFirstChild("Header", true)
        if nameLabel then
            local nameFrame = nameLabel.Parent
            if nameFrame and nameFrame:IsA("Frame") then
                local currentPos = nameFrame.Position
                nameFrame.Position = UDim2.new(
                    currentPos.X.Scale,
                    currentPos.X.Offset,
                    currentPos.Y.Scale - 0.25,
                    currentPos.Y.Offset
                )
            end
        end
        
        lynxFrame:Destroy()
    end
end

local function updateStats()
    if not HideStatsEnabled then 
        removeAllScriptNames()
        return 
    end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local overhead = hrp:FindFirstChild("Overhead")
    if not overhead or not overhead:IsA("BillboardGui") then return end
    
    for _, obj in pairs(overhead:GetDescendants()) do
        if obj:IsA("TextLabel") then
            local fullPath = obj:GetFullName()
            
            if not OriginalTexts[fullPath] then
                OriginalTexts[fullPath] = obj.Text
            end
            
            local originalText = OriginalTexts[fullPath]
            
            if originalText and originalText ~= "" then
                if obj.Name == "Header" then
                    if not overhead:FindFirstChild("LynxFrame") then
                        createScriptNameLabel(obj, overhead)
                    end
                    obj.Text = FakeName
                elseif string.find(string.lower(originalText), "lvl") then
                    obj.Text = string.gsub(originalText, "%d+", FakeLevel)
                end
            end
        end
    end
end

local updateLoop
local function startUpdateLoop()
    if updateLoop then return end
    updateLoop = true
    spawn(function()
        while updateLoop and wait(0.2) do
            if HideStatsEnabled then
                updateStats()
            end
        end
    end)
end

function HideStatsModule.Enable()
    HideStatsEnabled = true
    startUpdateLoop()
    updateStats()
end

function HideStatsModule.Disable()
    HideStatsEnabled = false
    
    for path, originalText in pairs(OriginalTexts) do
        local obj = game
        for part in string.gmatch(path, "[^.]+") do
            obj = obj:FindFirstChild(part)
            if not obj then break end
        end
        if obj and obj:IsA("TextLabel") then
            obj.Text = originalText
        end
    end
    
    removeAllScriptNames()
end

function HideStatsModule.SetFakeName(name)
    FakeName = name or "Guest"
    if HideStatsEnabled then
        updateStats()
    end
end

function HideStatsModule.SetFakeLevel(level)
    FakeLevel = tostring(level or "1")
    if HideStatsEnabled then
        updateStats()
    end
end

function HideStatsModule.IsEnabled()
    return HideStatsEnabled
end

function HideStatsModule.GetSettings()
    return {
        enabled = HideStatsEnabled,
        fakeName = FakeName,
        fakeLevel = FakeLevel
    }
end

LocalPlayer.CharacterAdded:Connect(function(character)
    OriginalTexts = {}
    ActiveGradientThreads = {}
    wait(1)
    if HideStatsEnabled then
        updateStats()
    end
end)

if LocalPlayer.Character then
    LocalPlayer.Character.DescendantAdded:Connect(function(descendant)
        if HideStatsEnabled and descendant:IsA("BillboardGui") then
            wait(0.1)
            updateStats()
        end
    end)
end

if LocalPlayer.Character then
    wait(1)
    if HideStatsEnabled then
        updateStats()
    end
end

return HideStatsModule
end)()

CombinedModules.MovementModule = (function()
local MovementModule = {}

local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

MovementModule.Settings = {
    SprintSpeed = 50,
    DefaultSpeed = 16,
    SprintEnabled = false,
    InfiniteJumpEnabled = false
}

local connections = {}
local jumpConnection = nil
local sprintConnection = nil

local function cleanup()
    for _, conn in pairs(connections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    connections = {}
    
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
    
    if sprintConnection then
        sprintConnection:Disconnect()
        sprintConnection = nil
    end
end

local function maintainSprintSpeed()
    if sprintConnection then
        sprintConnection:Disconnect()
    end
    
    sprintConnection = RunService.Heartbeat:Connect(function()
        if MovementModule.Settings.SprintEnabled and humanoid and humanoid.WalkSpeed ~= MovementModule.Settings.SprintSpeed then
            humanoid.WalkSpeed = MovementModule.Settings.SprintSpeed
        end
    end)
end

function MovementModule.SetSprintSpeed(speed)
    MovementModule.Settings.SprintSpeed = math.clamp(speed, 16, 200)
    
    if MovementModule.Settings.SprintEnabled and humanoid then
        humanoid.WalkSpeed = MovementModule.Settings.SprintSpeed
    end
end

function MovementModule.EnableSprint()
    if MovementModule.Settings.SprintEnabled then return false end
    
    MovementModule.Settings.SprintEnabled = true
    
    if humanoid then
        humanoid.WalkSpeed = MovementModule.Settings.SprintSpeed
    end
    
    maintainSprintSpeed()
    
    return true
end

function MovementModule.DisableSprint()
    if not MovementModule.Settings.SprintEnabled then return false end
    
    MovementModule.Settings.SprintEnabled = false
    
    if sprintConnection then
        sprintConnection:Disconnect()
        sprintConnection = nil
    end
    
    if humanoid then
        humanoid.WalkSpeed = MovementModule.Settings.DefaultSpeed
    end
    
    return true
end

function MovementModule.IsSprintEnabled()
    return MovementModule.Settings.SprintEnabled
end

function MovementModule.GetSprintSpeed()
    return MovementModule.Settings.SprintSpeed
end

local function enableInfiniteJump()
    if jumpConnection then
        jumpConnection:Disconnect()
    end
    
    jumpConnection = UserInputService.JumpRequest:Connect(function()
        if MovementModule.Settings.InfiniteJumpEnabled and humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

function MovementModule.EnableInfiniteJump()
    if MovementModule.Settings.InfiniteJumpEnabled then return false end
    
    MovementModule.Settings.InfiniteJumpEnabled = true
    enableInfiniteJump()
    
    return true
end

function MovementModule.DisableInfiniteJump()
    if not MovementModule.Settings.InfiniteJumpEnabled then return false end
    
    MovementModule.Settings.InfiniteJumpEnabled = false
    
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
    
    return true
end

function MovementModule.IsInfiniteJumpEnabled()
    return MovementModule.Settings.InfiniteJumpEnabled
end

table.insert(connections, player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    
    if MovementModule.Settings.SprintEnabled then
        task.wait(0.1)
        humanoid.WalkSpeed = MovementModule.Settings.SprintSpeed
        maintainSprintSpeed() 
    end
    
    if MovementModule.Settings.InfiniteJumpEnabled then
        enableInfiniteJump()
    end
end))

function MovementModule.Start()
    MovementModule.Settings.SprintEnabled = false
    MovementModule.Settings.InfiniteJumpEnabled = false
    enableInfiniteJump()
    return true
end

function MovementModule.Stop()
    MovementModule.DisableSprint()
    MovementModule.DisableInfiniteJump()
    cleanup()
    return true
end

MovementModule.Start()

return MovementModule
end)()

CombinedModules.PingPanel = (function()
local PingMonitor = {}
PingMonitor.__index = PingMonitor

local pingUpdateConnection
local gui = {}
local isVisible = false

local function createMonitorGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LynxPanelMonitor"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    screenGui.DisplayOrder = 999999
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = CoreGui
    
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 180, 0, 70)
    container.Position = UDim2.new(0.5, -90, 0, 50)
    container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Visible = false
    container.Parent = screenGui
    
    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 10)
    containerCorner.Parent = container
    
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 35)
    header.BackgroundTransparency = 1
    header.Parent = container
    
    local logoIcon = Instance.new("ImageLabel")
    logoIcon.Name = "LogoIcon"
    logoIcon.Size = UDim2.new(0, 24, 0, 24)
    logoIcon.Position = UDim2.new(0, 8, 0, 5)
    logoIcon.BackgroundTransparency = 1
    logoIcon.Image = "rbxassetid://118176705805619"
    logoIcon.ImageTransparency = 0
    logoIcon.ScaleType = Enum.ScaleType.Fit
    logoIcon.Parent = header
    
    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0, 6)
    logoCorner.Parent = logoIcon
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -40, 1, 0)
    titleLabel.Position = UDim2.new(0, 36, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "LYNX PANEL"
    titleLabel.TextColor3 = Color3.fromRGB(255, 140, 50)
    titleLabel.TextTransparency = 0
    titleLabel.TextSize = 13
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = header
    
    local separator = Instance.new("Frame")
    separator.Name = "Separator"
    separator.Size = UDim2.new(1, -16, 0, 1)
    separator.Position = UDim2.new(0, 8, 0, 35)
    separator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    separator.BackgroundTransparency = 0.7
    separator.BorderSizePixel = 0
    separator.Parent = container
    
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 1, -42)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = container
    
    local pingLabel = Instance.new("TextLabel")
    pingLabel.Name = "PingLabel"
    pingLabel.Size = UDim2.new(1, 0, 1, 0)
    pingLabel.Position = UDim2.new(0, 0, 0, 0)
    pingLabel.BackgroundTransparency = 1
    pingLabel.Text = "Ping: 0 ms"
    pingLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    pingLabel.TextTransparency = 0
    pingLabel.TextSize = 15
    pingLabel.Font = Enum.Font.SourceSansBold
    pingLabel.TextXAlignment = Enum.TextXAlignment.Center
    pingLabel.Parent = content
    
    local dragging = false
    local dragInput, dragStart, startPos
    
    container.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = container.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    container.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            container.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    return {
        ScreenGui = screenGui,
        Container = container,
        PingLabel = pingLabel,
        LogoIcon = logoIcon
    }
end

local function getPing()
    local ping = 0
    pcall(function()
        local networkStats = Stats:FindFirstChild("Network")
        if networkStats then
            local serverStatsItem = networkStats:FindFirstChild("ServerStatsItem")
            if serverStatsItem then
                local pingStr = serverStatsItem["Data Ping"]:GetValueString()
                ping = tonumber(pingStr:match("%d+")) or 0
            end
        end
        
        if ping == 0 then
            ping = math.floor(player:GetNetworkPing() * 1000)
        end
    end)
    return ping
end

local function updatePingColor(pingLabel, value)
    local ping = tonumber(value)
    local targetColor
    
    if ping <= 50 then
        targetColor = Color3.fromRGB(100, 255, 150)
    elseif ping <= 100 then
        targetColor = Color3.fromRGB(255, 220, 100)
    elseif ping <= 150 then
        targetColor = Color3.fromRGB(255, 170, 100)
    else
        targetColor = Color3.fromRGB(255, 100, 100)
    end
    
    TweenService:Create(
        pingLabel,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {TextColor3 = targetColor}
    ):Play()
end

local function initializeGUI()
    local existing = CoreGui:FindFirstChild("LynxPanelMonitor")
    if existing then
        existing:Destroy()
        task.wait(0.1)
    end
    
    gui = createMonitorGUI()
end

function PingMonitor:Show()
    if not gui or not gui.ScreenGui then
        initializeGUI()
    end
    
    if gui and gui.Container then
        gui.Container.Visible = true
        isVisible = true
        
        gui.Container.BackgroundTransparency = 1
        TweenService:Create(
            gui.Container,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.3}
        ):Play()
        
        local lastPingUpdate = 0
        pingUpdateConnection = RunService.Heartbeat:Connect(function()
            if not gui or not gui.ScreenGui or not gui.ScreenGui.Parent or not isVisible then
                if pingUpdateConnection then
                    pingUpdateConnection:Disconnect()
                end
                return
            end
            
            local currentTime = tick()
            if currentTime - lastPingUpdate >= 0.5 then
                local ping = getPing()
                gui.PingLabel.Text = "Ping: " .. ping .. " ms"
                updatePingColor(gui.PingLabel, ping)
                lastPingUpdate = currentTime
            end
        end)
        
        print("âœ… Lynx Monitor aktif!")
    end
end

function PingMonitor:Hide()
    if gui and gui.Container then
        TweenService:Create(
            gui.Container,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}
        ):Play()
        
        task.wait(0.3)
        gui.Container.Visible = false
        isVisible = false
        
        if pingUpdateConnection then
            pingUpdateConnection:Disconnect()
            pingUpdateConnection = nil
        end
        
        print("âœ… Lynx Monitor disembunyikan!")
    end
end

function PingMonitor:Destroy()
    if pingUpdateConnection then
        pingUpdateConnection:Disconnect()
    end
    if gui and gui.ScreenGui then
        gui.ScreenGui:Destroy()
    end
    gui = {}
end

return PingMonitor
end)()

CombinedModules.Webhook = (function()
local WebhookModule = {}

local function getHTTPRequest()
    local requestFunctions = {
        -- Metode standar
        request,
        http_request,
        -- Syn/Synapse
        (syn and syn.request),
        -- Fluxus
        (fluxus and fluxus.request),
        -- Script-Ware
        (http and http.request),
        -- Solara (khusus)
        (solara and solara.request),
        -- Fallback lainnya
        (game and game.HttpGet and function(opts)
            if opts.Method == "GET" then
                return {Body = game:HttpGet(opts.Url)}
            end
        end)
    }
    
    for _, func in ipairs(requestFunctions) do
        if func and type(func) == "function" then
            return func
        end
    end
    
    return nil
end

local httpRequest = getHTTPRequest()

-- ========== FISH WEBHOOK CONFIG ==========
WebhookModule.FishConfig = {
    WebhookURL = "",
    DiscordUserID = "",
    DebugMode = false,
    EnabledRarities = {},
    UseSimpleMode = false
}

-- ========== DISCONNECT WEBHOOK CONFIG ==========
WebhookModule.DisconnectConfig = {
    WebhookURL = "",
    DiscordUserID = "",
    HideIdentity = "",
    Enabled = false
}

local Items, Variants
local function loadGameModules()
    local success, err = pcall(function()
        Items = require(ReplicatedStorage:WaitForChild("Items"))
        Variants = require(ReplicatedStorage:WaitForChild("Variants"))
    end)
    
    return success
end

local TIER_NAMES = {
    [1] = "Common",
    [2] = "Uncommon", 
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Mythic",
    [7] = "SECRET"
}

local TIER_COLORS = {
    [1] = 9807270,
    [2] = 3066993,
    [3] = 3447003,
    [4] = 10181046,
    [5] = 15844367,
    [6] = 16711680,
    [7] = 1752220
}

local isFishRunning = false
local fishEventConnection = nil
local isDisconnectEnabled = false
local disconnectSetup = false

-- ========== FISH WEBHOOK FUNCTIONS ==========

local function getPlayerDisplayName()
    return LocalPlayer.DisplayName or LocalPlayer.Name
end

local function getDiscordImageUrl(assetId)
    if not assetId then return nil end
    
    local thumbnailUrl = string.format(
        "https://thumbnails.roblox.com/v1/assets?assetIds=%s&returnPolicy=PlaceHolder&size=420x420&format=Png&isCircular=false",
        tostring(assetId)
    )
    
    local rbxcdnUrl = string.format(
        "https://tr.rbxcdn.com/180DAY-%s/420/420/Image/Png",
        tostring(assetId)
    )
    
    if httpRequest then
        local success, result = pcall(function()
            local response = httpRequest({
                Url = thumbnailUrl,
                Method = "GET"
            })
            
            if response and response.Body then
                local data = HttpService:JSONDecode(response.Body)
                if data and data.data and data.data[1] and data.data[1].imageUrl then
                    return data.data[1].imageUrl
                end
            end
        end)
        
        if success and result then
            return result
        end
    end
    
    return rbxcdnUrl
end

local function getFishImageUrl(fish)
    local assetId = nil
    
    if fish.Data.Icon then
        assetId = tostring(fish.Data.Icon):match("%d+")
    elseif fish.Data.ImageId then
        assetId = tostring(fish.Data.ImageId)
    elseif fish.Data.Image then
        assetId = tostring(fish.Data.Image):match("%d+")
    end
    
    if assetId then
        local discordUrl = getDiscordImageUrl(assetId)
        if discordUrl then
            return discordUrl
        end
    end
    
    return "https://i.imgur.com/8yZqFqM.png"
end

local function getFish(itemId)
    if not Items then return nil end
    
    for _, f in pairs(Items) do
        if f.Data and f.Data.Id == itemId then
            return f
        end
    end
end

local function getVariant(id)
    if not id or not Variants then return nil end
    
    local idStr = tostring(id)
    
    for _, v in pairs(Variants) do
        if v.Data then
            if tostring(v.Data.Id) == idStr or tostring(v.Data.Name) == idStr then
                return v
            end
        end
    end
    
    return nil
end

local function sendFishWebhook(fish, meta, extra)
    if not WebhookModule.FishConfig.WebhookURL or WebhookModule.FishConfig.WebhookURL == "" then
        return
    end
    
    if not httpRequest then
        return
    end
    
    local tier = TIER_NAMES[fish.Data.Tier] or "Unknown"
    local color = TIER_COLORS[fish.Data.Tier] or 3447003
    
    if WebhookModule.FishConfig.EnabledRarities then
        -- Check if there are any enabled rarities
        local hasFilter = false
        local isEnabled = false
        
        -- Support both array format {"Rare", "Epic"} and dictionary format {Rare = true, Epic = true}
        for key, value in pairs(WebhookModule.FishConfig.EnabledRarities) do
            -- Check if it's dictionary format (key is string, value is boolean)
            if type(key) == "string" then
                hasFilter = true
                if key == tier and value == true then
                    isEnabled = true
                    break
                end
            -- Check if it's array format (key is number, value is string)
            elseif type(key) == "number" and type(value) == "string" then
                hasFilter = true
                if value == tier then
                    isEnabled = true
                    break
                end
            end
        end
        
        -- Only filter if there's actually a filter set
        if hasFilter and not isEnabled then
            return
        end
    end
    
    local mutationText = "None"
    local finalPrice = fish.SellPrice or 0
    local variantId = nil
    
    if extra then
        variantId = extra.Variant or extra.Mutation or extra.VariantId or extra.MutationId
    end
    
    if not variantId and meta then
        variantId = meta.Variant or meta.Mutation or meta.VariantId or meta.MutationId
    end
    
    local isShiny = (meta and meta.Shiny) or (extra and extra.Shiny)
    if isShiny then
        mutationText = "Shiny"
        finalPrice = finalPrice * 2
    end
    
    if variantId then
        local v = getVariant(variantId)
        if v then
            mutationText = v.Data.Name .. " (" .. v.SellMultiplier .. "x)"
            finalPrice = finalPrice * v.SellMultiplier
        else
            mutationText = variantId
        end
    end
    
    local imageUrl = getFishImageUrl(fish)
    local playerDisplayName = getPlayerDisplayName()
    local mention = WebhookModule.FishConfig.DiscordUserID ~= "" and "<@" .. WebhookModule.FishConfig.DiscordUserID .. "> " or ""
    
    local congratsMsg = string.format(
        "%s **%s** You have obtained a new **%s** fish!",
        mention,
        playerDisplayName,
        tier
    )
    
    local fields = {
        {
            name = "Fish Name :",
            value = "> " .. fish.Data.Name,
            inline = false
        },
        {
            name = "Fish Tier :",
            value = "> " .. tier,
            inline = false
        },
        {
            name = "Weight :",
            value = string.format("> %.2f Kg", meta.Weight or 0),
            inline = false
        },
        {
            name = "Mutation :",
            value = "> " .. mutationText,
            inline = false
        },
        {
            name = "Sell Price :",
            value = "> $" .. math.floor(finalPrice),
            inline = false
        }
    }
    
    local payload = {
        embeds = {{
            author = {
                name = "Lynxx Webhook | Fish Caught"
            },
            description = congratsMsg,
            color = color,
            fields = fields,
            image = {
                url = imageUrl
            },
            footer = {
                text = "Lynxx Webhook • " .. os.date("%m/%d/%Y %H:%M"),
                icon_url = "https://i.imgur.com/shnNZuT.png"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    
    pcall(function()
        httpRequest({
            Url = WebhookModule.FishConfig.WebhookURL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

-- ========== DISCONNECT WEBHOOK FUNCTIONS ==========

local function sendDisconnectWebhook(reason)
    if not isDisconnectEnabled then
        return
    end
    
    local webhookURL = WebhookModule.DisconnectConfig.WebhookURL
    if not webhookURL or webhookURL == "" or not webhookURL:match("discord") then
        return
    end
    
    if not httpRequest then
        return
    end
    
    local playerName = "Unknown"
    if WebhookModule.DisconnectConfig.HideIdentity and WebhookModule.DisconnectConfig.HideIdentity ~= "" then
        playerName = WebhookModule.DisconnectConfig.HideIdentity
    elseif LocalPlayer and LocalPlayer.Name then
        playerName = LocalPlayer.Name
    end
    
    local mention = WebhookModule.DisconnectConfig.DiscordUserID ~= "" 
        and "<@" .. WebhookModule.DisconnectConfig.DiscordUserID:gsub("%D", "") .. ">" 
        or "Anonymous"
    
    local dateInfo = os.date("*t")
    local hour12 = dateInfo.hour > 12 and dateInfo.hour - 12 or dateInfo.hour
    local ampm = dateInfo.hour >= 12 and "PM" or "AM"
    local formattedTime = string.format(
        "%02d/%02d/%04d %02d.%02d %s",
        dateInfo.day,
        dateInfo.month,
        dateInfo.year,
        hour12,
        dateInfo.min,
        ampm
    )
    
    local disconnectReason = reason and reason ~= "" and reason or "Disconnected from server"
    
    local payload = {
        content = "Lekk Akun lu Disconnect noh! " .. mention .. " your account got disconnected from server!",
        embeds = {{
            title = "DETAIL ACCOUNT",
            color = 16744448,
            fields = {
                {
                    name = "〢Username :",
                    value = "> " .. playerName
                },
                {
                    name = "〢Time got disconnected :",
                    value = "> " .. formattedTime
                },
                {
                    name = "〢Reason :",
                    value = "> " .. disconnectReason
                }
            },
            thumbnail = {
                url = "https://media.tenor.com/PzM6FF__0tYAAAAi/fjsyun-%E7%86%8F%E7%86%8F.gif"
            }
        }},
        username = "Lynxx Notification!",
        avatar_url = "https://i.imgur.com/shnNZuT.png"
    }
    
    task.spawn(function()
        pcall(function()
            httpRequest({
                Url = webhookURL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)
end

local function setupDisconnectDetection()
    if disconnectSetup then return end
    disconnectSetup = true
    
    local hasDisconnected = false
    
    local function handleDisconnect(reason)
        if not hasDisconnected and isDisconnectEnabled then
            hasDisconnected = true
            
            local disconnectReason = reason or "Disconnected from server"
            sendDisconnectWebhook(disconnectReason)
            
            task.wait(2)
            
            -- Auto rejoin
            local TeleportService = game:GetService("TeleportService")
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end
    
    -- Method 1: GuiService ErrorMessageChanged
    game:GetService("GuiService").ErrorMessageChanged:Connect(function(message)
        if message and message ~= "" then
            handleDisconnect(message)
        end
    end)
    
    -- Method 2: CoreGui RobloxPromptGui
    local success, CoreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    
    if success and CoreGui then
        pcall(function()
            local RobloxPromptGui = CoreGui:FindFirstChild("RobloxPromptGui")
            if RobloxPromptGui then
                local promptOverlay = RobloxPromptGui:FindFirstChild("promptOverlay")
                if promptOverlay then
                    promptOverlay.ChildAdded:Connect(function(child)
                        if child.Name == "ErrorPrompt" then
                            task.wait(1)
                            local textLabel = child:FindFirstChildWhichIsA("TextLabel", true)
                            local reason = textLabel and textLabel.Text or "Disconnected"
                            handleDisconnect(reason)
                        end
                    end)
                end
            end
        end)
    end
end

-- ========== PUBLIC API ==========

-- Fish Webhook Methods
function WebhookModule:SetFishWebhookURL(url)
    self.FishConfig.WebhookURL = url
end

function WebhookModule:SetFishDiscordUserID(id)
    self.FishConfig.DiscordUserID = id
end

function WebhookModule:SetFishDebugMode(enabled)
    self.FishConfig.DebugMode = enabled
end

function WebhookModule:SetFishEnabledRarities(rarities)
    self.FishConfig.EnabledRarities = rarities
end

function WebhookModule:SetFishSimpleMode(enabled)
    self.FishConfig.UseSimpleMode = enabled
end

-- Disconnect Webhook Methods
function WebhookModule:SetDisconnectWebhookURL(url)
    self.DisconnectConfig.WebhookURL = url
end

function WebhookModule:SetDisconnectDiscordUserID(id)
    self.DisconnectConfig.DiscordUserID = id
end

function WebhookModule:SetDisconnectHideIdentity(name)
    self.DisconnectConfig.HideIdentity = name
end

function WebhookModule:EnableDisconnectWebhook(enabled)
    self.DisconnectConfig.Enabled = enabled
    isDisconnectEnabled = enabled
    
    if enabled then
        setupDisconnectDetection()
    end
end

-- Start/Stop Methods
function WebhookModule:StartFishWebhook()
    if isFishRunning then
        return false
    end
    
    if not self.FishConfig.WebhookURL or self.FishConfig.WebhookURL == "" then
        return false
    end
    
    if not httpRequest then
        return false
    end
    
    -- Load game modules
    if not loadGameModules() then
        return false
    end
    
    local success, Event = pcall(function()
        return ReplicatedStorage.Packages
            ._Index["sleitnick_net@0.2.0"]
            .net["RE/ObtainedNewFishNotification"]
    end)
    
    if not success or not Event then
        return false
    end
    
    fishEventConnection = Event.OnClientEvent:Connect(function(itemId, metadata, extraData)
        local fish = getFish(itemId)
        if fish then
            task.spawn(function()
                sendFishWebhook(fish, metadata, extraData)
            end)
        end
    end)
    
    isFishRunning = true
    return true
end

function WebhookModule:StopFishWebhook()
    if not isFishRunning then
        return false
    end
    
    if fishEventConnection then
        fishEventConnection:Disconnect()
        fishEventConnection = nil
    end
    
    isFishRunning = false
    return true
end

-- Test Methods
function WebhookModule:TestDisconnectWebhook()
    if not httpRequest then
        return false, "HTTP request not supported"
    end
    
    if not self.DisconnectConfig.WebhookURL or self.DisconnectConfig.WebhookURL == "" then
        return false, "Webhook URL not set"
    end
    
    -- Send test webhook
    sendDisconnectWebhook("Test Successfully :3")
    
    -- Wait and auto rejoin
    task.wait(2)
    local TeleportService = game:GetService("TeleportService")
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
    
    return true
end

-- Status Methods
function WebhookModule:IsFishRunning()
    return isFishRunning
end

function WebhookModule:IsDisconnectEnabled()
    return isDisconnectEnabled
end

function WebhookModule:GetTierNames()
    return TIER_NAMES
end

function WebhookModule:GetFishConfig()
    return self.FishConfig
end

function WebhookModule:GetDisconnectConfig()
    return self.DisconnectConfig
end

function WebhookModule:IsSupported()
    return httpRequest ~= nil
end

return WebhookModule
end)()

CombinedModules.TeleportModule = (function()

local TeleportModule = {}

TeleportModule.Locations = {
    ["Ancient Jungle"] = Vector3.new(1467.8480224609375, 7.447117328643799, -327.5971984863281),
    ["Ancient Ruin"] = Vector3.new(6045.40234375, -588.600830078125, 4608.9375),
    ["Coral Reefs"] = Vector3.new(-2921.858154296875, 3.249999761581421, 2083.2978515625),
    ["Crater Island"] = Vector3.new(1078.454345703125, 5.0720038414001465, 5099.396484375),
    ["Esoteric Depths"] = Vector3.new(3224.075927734375, -1302.85498046875, 1404.9346923828125),
    ["Fisherman Island"] = Vector3.new(92.80695343017578, 9.531265258789062, 2762.082275390625),
    ["Kohana"] = Vector3.new(-643.3051147460938, 16.03544807434082, 622.3605346679688),
    ["Kohana Volcano"] = Vector3.new(-572.0244750976562, 39.4923210144043, 112.49259185791016),
    ["Lost Isle"] = Vector3.new(-3701.1513671875, 5.425841808319092, -1058.9107666015625),
    ["Sysiphus Statue"] = Vector3.new(-3656.56201171875, -134.5314178466797, -964.3167724609375),
    ["Sacred Temple"] = Vector3.new(1476.30810546875, -21.8499755859375, -630.8220825195312),
    ["Treasure Room"] = Vector3.new(-3601.568359375, -266.57373046875, -1578.998779296875),
    ["Tropical Grove"] = Vector3.new(-2104.467041015625, 6.268016815185547, 3718.2548828125),
    ["Underground Cellar"] = Vector3.new(2162.577392578125, -91.1981430053711, -725.591552734375),
    ["(New)Pirate Cove"] = Vector3.new(3334.47, 10.2, 3502.92),
    ["(New)Leviathan Den"] = Vector3.new(3471.413574218750000, -287.843200683593750, 3468.871582031250000),
    ["(New)Pirate Treasure Room"] = Vector3.new(3337.642089843750000, -302.747497558593750, 3089.556884765625000),
    ["Weather Machine"] = Vector3.new(-1513.9249267578125, 6.499999523162842, 1892.10693359375)
}

function TeleportModule.TeleportTo(name)
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")

    local target = TeleportModule.Locations[name]
    if not target then
        warn("âš ï¸ Lokasi '" .. tostring(name) .. "' tidak ditemukan!")
        return
    end

    root.CFrame = CFrame.new(target)
    print("âœ… Teleported to:", name)
end

return TeleportModule
end)()

CombinedModules.TeleportToPlayer = (function()
local TeleportToPlayer = {}

function TeleportToPlayer.TeleportTo(playerName)
    local target = Players:FindFirstChild(playerName)
    local myChar = localPlayer.Character
    if not target or not target.Character then return end

    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")

    if targetHRP and myHRP then
        myHRP.CFrame = targetHRP.CFrame + Vector3.new(0, 3, 0)
        print("[Teleport] ðŸš€ Teleported to player: " .. playerName)
    else
        warn("[Teleport] âŒ Gagal teleport, HRP tidak ditemukan.")
    end
end

return TeleportToPlayer
end)()

CombinedModules.SavedLocation = (function()
local SaveLocation = {}
local FileName = "LynxSavedLocation.json"

-- Fungsi untuk menyimpan CFrame ke file
local function SavePosition(cframe)
    local components = {cframe:GetComponents()}
    pcall(function()
        writefile(FileName, HttpService:JSONEncode(components))
    end)
end

-- Fungsi untuk memuat CFrame dari file
local function LoadPosition()
    if isfile(FileName) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(FileName))
        end)
        if success and typeof(result) == "table" then
            return CFrame.new(unpack(result))
        end
    end
    return nil
end

-- Auto teleport saat karakter ditambahkan (seperti contoh Anda)
local function TeleportLastPos(character)
    task.spawn(function()
        local HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
        local savedCFrame = LoadPosition()
        if savedCFrame then
            task.wait(2)
            HumanoidRootPart.CFrame = savedCFrame
            -- Notify jika perlu
            pcall(function()
                game.StarterGui:SetCore("SendNotification", {
                    Title = "Teleported";
                    Text = "Teleported to your last position...";
                    Duration = 3;
                })
            end)
        end
    end)
end

-- Connect auto teleport
localPlayer.CharacterAdded:Connect(TeleportLastPos)

-- Auto teleport jika karakter sudah ada
if localPlayer.Character then
    TeleportLastPos(localPlayer.Character)
end

-- Function untuk save position
function SaveLocation.Save()
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    SavePosition(hrp.CFrame)
    
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "Saved Location";
            Text = "Position saved successfully!";
            Duration = 3;
        })
    end)
end

-- Function untuk teleport manual (opsional, karena sudah auto)
function SaveLocation.Teleport()
    local savedCFrame = LoadPosition()
    if not savedCFrame then
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "Error";
                Text = "No saved position found!";
                Duration = 3;
            })
        end)
        return false
    end
    
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    hrp.CFrame = savedCFrame

    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "Teleported";
            Text = "Teleport berhasil!";
            Duration = 3;
        })
    end)
    return true
end

-- Function untuk reset position
function SaveLocation.Reset()
    if isfile(FileName) then
        delfile(FileName)
    end
    
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "Location Reset";
            Text = "Last position has been reset.";
            Duration = 3;
        })
    end)
end

return SaveLocation
end)()

CombinedModules.AutoEvent = (function()
    local module = {}

    local EventSearchPatterns = {
        ["Shark Hunt"] = {"Shark Hunt"},
        ["Megalodon Hunt"] = {"Megalodon Hunt"}, 
        ["Worm Hunt"] = {"BlackHole", "Model"},
        ["Ghost Shark Hunt"] = {"Ghost Shark Hunt", "Ghost"},
        ["Treasure Hunt"] = {"Treasure"},
        ["Black Hole"] = {"Black Hole"}
    }

    module.FallbackCoords = {
        ["Shark Hunt"] = {
            Vector3.new(1.64999, -1.3500, 2095.72),
            Vector3.new(1369.94, -1.3500, 930.125),
            Vector3.new(-1585.5, -1.3500, 1242.87),
            Vector3.new(-1896.8, -1.3500, 2634.37),
        },
        ["Worm Hunt"] = {
            Vector3.new(2190.85, -1.3999, 97.5749),
            Vector3.new(-2450.6, -1.3999, 139.731),
            Vector3.new(-267.47, -1.3999, 5188.53),
        },
        ["Megalodon Hunt"] = {
            Vector3.new(-1076.3, -1.3999, 1676.19),
            Vector3.new(-1191.8, -1.3999, 3597.30),
            Vector3.new(412.700, -1.3999, 4134.39),
        },
        ["Ghost Shark Hunt"] = {
            Vector3.new(489.558, -1.3500, 25.4060),
            Vector3.new(-1358.2, -1.3500, 4100.55),
            Vector3.new(627.859, -1.3500, 3798.08),
        },
    }

    module.TeleportCheckInterval = 8
    module.HeightOffset = 15
    module.SafeZoneRadius = 150
    module.RequireEventActive = true
    module.WaitForEventTimeout = 300
    module.ScanCooldown = 5

    local running = false
    local currentEventName = nil
    local cachedEventPosition = nil
    local cachedEventObject = nil
    local eventIsActive = false
    local lastScanTime = 0
    local loopThread = nil

    local function getHRP()
        local c = game.Players.LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function applyOffset(v)
        return Vector3.new(v.X, v.Y + module.HeightOffset, v.Z)
    end

    local function safeCharacter()
        return game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
    end

    local function isNearTarget(targetPos)
        local hrp = getHRP()
        if not hrp then return false end
        
        local distance = (hrp.Position - targetPos).Magnitude
        return distance <= module.SafeZoneRadius
    end

    local function doTeleport(pos)
        if isNearTarget(pos) then
            return true
        end
        
        local ok = pcall(function()
            local c = safeCharacter()
            if not c then return end

            local hrp = c:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            if c.PrimaryPart then
                c:PivotTo(CFrame.new(pos))
            else
                hrp.CFrame = CFrame.new(pos)
            end
            
            hrp.Anchored = false
            hrp.Velocity = Vector3.zero
        end)
        return ok
    end

    local function IsEventAlive(obj)
        if not obj then return false end
        
        local success = pcall(function()
            return obj.Parent ~= nil and obj:IsDescendantOf(workspace)
        end)
        
        return success
    end

    local function SearchInAllProps(eventName)
        local patterns = EventSearchPatterns[eventName]
        if not patterns then
            return false, nil, nil
        end
        
        local allProps = {}
        for _, child in ipairs(workspace:GetChildren()) do
            if child.Name == "Props" and child:IsA("Model") then
                table.insert(allProps, child)
            end
        end
        
        for _, props in ipairs(allProps) do
            for _, pattern in ipairs(patterns) do
                for _, child in ipairs(props:GetChildren()) do
                    if child.Name == pattern and IsEventAlive(child) then
                        local position = nil
                        
                        if child:IsA("Model") then
                            if child.PrimaryPart then
                                position = child.PrimaryPart.Position
                            else
                                local cf, size = child:GetBoundingBox()
                                local adjustedY = cf.Position.Y - (size.Y / 4)
                                position = Vector3.new(cf.Position.X, adjustedY, cf.Position.Z)
                            end
                        elseif child:IsA("BasePart") then
                            position = child.Position
                        end
                        
                        if position then
                            return true, position, child
                        end
                    end
                end
            end
        end
        
        return false, nil, nil
    end

    local function scanEvent(eventName)
        local now = tick()
        
        if now - lastScanTime < module.ScanCooldown then
            if cachedEventPosition and cachedEventObject and IsEventAlive(cachedEventObject) then
                return cachedEventPosition
            end
        end
        
        lastScanTime = now
        
        local found, position, obj = SearchInAllProps(eventName)
        
        if found and position then
            cachedEventPosition = applyOffset(position)
            cachedEventObject = obj
            eventIsActive = true
            return cachedEventPosition
        end
        
        local coords = module.FallbackCoords[eventName]
        if coords and #coords > 0 then
            for _, coord in ipairs(coords) do
                local region = Region3.new(
                    coord - Vector3.new(30, 30, 30),
                    coord + Vector3.new(30, 30, 30)
                ):ExpandToGrid(4)

                local ok, parts = pcall(function()
                    return workspace:FindPartsInRegion3(region, nil, 50)
                end)

                if ok and parts and #parts > 0 then
                    for _, p in ipairs(parts) do
                        if typeof(p) == "Instance" and p:IsA("BasePart") and IsEventAlive(p) then
                            local ps = p.Position
                            if (ps - coord).Magnitude <= 25 then
                                cachedEventPosition = applyOffset(ps)
                                cachedEventObject = p
                                eventIsActive = true
                                return cachedEventPosition
                            end
                        end
                    end
                end
            end
        end
        
        eventIsActive = false
        return nil
    end

    local function waitActive(eventName)
        local start = tick()
        while tick() - start < module.WaitForEventTimeout do
            local p = scanEvent(eventName)
            if p then 
                return p 
            end
            task.wait(5)
        end
        return nil
    end

    function module.TeleportNow(name)
        if cachedEventPosition and eventIsActive then
            return doTeleport(cachedEventPosition)
        end
        return false
    end

    function module.Start(name)
        if running then 
            return false 
        end
        
        if not EventSearchPatterns[name] and not module.FallbackCoords[name] then
            return false
        end

        running = true
        currentEventName = name
        cachedEventPosition = nil
        cachedEventObject = nil
        eventIsActive = false
        lastScanTime = 0

        loopThread = task.spawn(function()
            if module.RequireEventActive then
                local pos = waitActive(name)
                if not pos then
                    module.Stop()
                    return
                end
                doTeleport(pos)
            end

            local failCount = 0
            while running do
                if cachedEventObject and not IsEventAlive(cachedEventObject) then
                    cachedEventPosition = nil
                    cachedEventObject = nil
                    eventIsActive = false
                end

                local newPos = scanEvent(name)
                
                if newPos then
                    doTeleport(newPos)
                    failCount = 0
                else
                    failCount = failCount + 1
                    
                    if failCount >= 3 then
                        module.Stop()
                        break
                    end
                end
                
                task.wait(module.TeleportCheckInterval)
            end
        end)
        
        return true
    end

    function module.Stop()
        running = false
        cachedEventPosition = nil
        cachedEventObject = nil
        currentEventName = nil
        eventIsActive = false
        
        if loopThread then
            if loopThread ~= coroutine.running() then
                task.cancel(loopThread)
            end
            loopThread = nil
        end
        
        return true
    end

    function module.GetEventNames()
        local list = {}
        for name, _ in pairs(EventSearchPatterns) do
            table.insert(list, name)
        end
        table.sort(list)
        return list
    end

    function module.HasEventPattern(eventName)
        return EventSearchPatterns[eventName] ~= nil
    end

    function module.IsEventActive(eventName)
        if currentEventName == eventName and eventIsActive then
            return true
        end
        return false
    end

    function module.GetCachedPosition()
        return cachedEventPosition
    end

    function module.ForceScan(eventName)
        lastScanTime = 0
        return scanEvent(eventName or currentEventName)
    end

    return module
end)()

CombinedModules.AutoBuyWeather = (function()
    local AutoBuyWeather = {}
    
    local NetPackage = nil
    local RFPurchaseWeatherEvent = nil
    
    pcall(function()
        NetPackage = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"]
        RFPurchaseWeatherEvent = NetPackage.net["RF/PurchaseWeatherEvent"]
    end)
    
    local isRunning = false
    local selected = {}
    local loopThread = nil
    
    AutoBuyWeather.AllWeathers = {
        "Cloudy",
        "Storm",
        "Wind",
        "Snow",
        "Radiant",
        "Shark Hunt"
    }
    
    function AutoBuyWeather.SetSelected(list)
        selected = list or {}
    end
    
    function AutoBuyWeather.Start()
        if isRunning then return false end
        if not RFPurchaseWeatherEvent then return false end
        if #selected == 0 then return false end
        
        isRunning = true
        
        loopThread = task.spawn(function()
            while isRunning do
                for _, weather in ipairs(selected) do
                    if not isRunning then break end
                    
                    local success = pcall(function()
                        RFPurchaseWeatherEvent:InvokeServer(weather)
                    end)
                    
                    task.wait(0.1)
                end
                
                task.wait(10)
            end
        end)
        
        return true
    end
    
    function AutoBuyWeather.Stop()
        if not isRunning then return false end
        
        isRunning = false
        
        if loopThread then
            task.cancel(loopThread)
            loopThread = nil
        end
        
        return true
    end
    
    function AutoBuyWeather.GetStatus()
        return {
            Running = isRunning,
            Selected = selected
        }
    end
    
    function AutoBuyWeather.IsAvailable()
        return RFPurchaseWeatherEvent ~= nil
    end
    
    return AutoBuyWeather
end)()

CombinedModules.AutoSell = (function()
local AutoSell = {}

local function findSellRemotes()
	local sellRemotes = {}
	local keywords = { "sell", "vendor", "trade", "shop", "merchant", "salvage", "exchange", "deposit", "convert" }

	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
			local name = string.lower(obj.Name)
			for _, key in ipairs(keywords) do
				if string.find(name, key) then
					table.insert(sellRemotes, obj)
					if string.find(name, "sellall") then
						return obj
					end
				end
			end
		end
	end
	return sellRemotes[1]
end

function AutoSell.SellOnce()
    
	local remote = findSellRemotes()
	if not remote then
		warn("âŒ Sell remote not found!")
		return
	end

	pcall(function()
		if remote:IsA("RemoteEvent") then
			remote:FireServer("all")
		elseif remote:IsA("RemoteFunction") then
			remote:InvokeServer("all")
		else
			warn("âš ï¸ Invalid remote type for selling")
		end
	end)
end

_G.AutoSell = AutoSell
return AutoSell
end)()

CombinedModules.AutoSellSystem = (function()
local function findSellRemote()
	local packages = ReplicatedStorage:FindFirstChild("Packages")
	if not packages then return nil end
	
	local index = packages:FindFirstChild("_Index")
	if not index then return nil end
	
	local sleitnick = index:FindFirstChild("sleitnick_net@0.2.0")
	if not sleitnick then return nil end
	
	local net = sleitnick:FindFirstChild("net")
	if not net then return nil end
	
	local sellRemote = net:FindFirstChild("RF/SellAllItems")
	if sellRemote then return sellRemote end
	
	local rf = net:FindFirstChild("RF")
	if rf then
		sellRemote = rf:FindFirstChild("SellAllItems")
		if sellRemote then return sellRemote end
	end
	
	for _, child in ipairs(net:GetDescendants()) do
		if child.Name == "SellAllItems" or child.Name == "RF/SellAllItems" then
			return child
		end
	end
	
	return nil
end

local SellRemote = findSellRemote()

local function parseNumber(text)
	if not text or text == "" then return 0 end
	local cleaned = tostring(text):gsub("%D", "")
	if cleaned == "" then return 0 end
	return tonumber(cleaned) or 0
end

local function getBagCount()
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return 0, 0 end

	local inv = gui:FindFirstChild("Inventory")
	if not inv then return 0, 0 end

	local label = inv:FindFirstChild("Main")
		and inv.Main:FindFirstChild("Top")
		and inv.Main.Top:FindFirstChild("Options")
		and inv.Main.Top.Options:FindFirstChild("Fish")
		and inv.Main.Top.Options.Fish:FindFirstChild("Label")
		and inv.Main.Top.Options.Fish.Label:FindFirstChild("BagSize")

	if not label or not label:IsA("TextLabel") then return 0, 0 end

	local curText, maxText = label.Text:match("(.+)%/(.+)")
	if not curText or not maxText then return 0, 0 end

	return parseNumber(curText), parseNumber(maxText)
end

local AutoSellSystem = {
	Remote = SellRemote,
	
	_totalSells = 0,
	_lastSellTime = 0,
	
	Timer = {
		Enabled = false,
		Interval = 5,
		Thread = nil,
		_sellCount = 0
	},
	
	Count = {
		Enabled = false,
		Target = 235,
		CheckDelay = 1.5,
		_lastSell = 0,
		_thread = nil
	}
}

local function executeSell()
	if not SellRemote then return false end
	
	local success, result = pcall(function()
		return SellRemote:InvokeServer()
	end)
	
	if success then
		AutoSellSystem._totalSells = AutoSellSystem._totalSells + 1
		AutoSellSystem._lastSellTime = tick()
		return true
	end
	
	return false
end

function AutoSellSystem.SellOnce()
	if not SellRemote then return false end
	if tick() - AutoSellSystem._lastSellTime < 0.5 then return false end
	return executeSell()
end

function AutoSellSystem.Timer.Start(interval)
	if AutoSellSystem.Timer.Enabled then return false end
	if not SellRemote then return false end
	
	if interval and tonumber(interval) and tonumber(interval) >= 1 then
		AutoSellSystem.Timer.Interval = tonumber(interval)
	end
	
	AutoSellSystem.Timer.Enabled = true
	AutoSellSystem.Timer._sellCount = 0
	
	AutoSellSystem.Timer.Thread = task.spawn(function()
		while AutoSellSystem.Timer.Enabled do
			task.wait(AutoSellSystem.Timer.Interval)
			
			if not AutoSellSystem.Timer.Enabled then break end
			
			if executeSell() then
				AutoSellSystem.Timer._sellCount = AutoSellSystem.Timer._sellCount + 1
			end
		end
	end)
	
	return true
end

function AutoSellSystem.Timer.Stop()
	if not AutoSellSystem.Timer.Enabled then return false end
	AutoSellSystem.Timer.Enabled = false
	return true
end

function AutoSellSystem.Timer.SetInterval(seconds)
	if tonumber(seconds) and seconds >= 1 then
		AutoSellSystem.Timer.Interval = tonumber(seconds)
		return true
	end
	return false
end

function AutoSellSystem.Timer.GetStatus()
	return {
		enabled = AutoSellSystem.Timer.Enabled,
		interval = AutoSellSystem.Timer.Interval,
		sellCount = AutoSellSystem.Timer._sellCount
	}
end

function AutoSellSystem.Count.Start(target)
	if AutoSellSystem.Count.Enabled then return false end
	if not SellRemote then return false end
	
	if target and tonumber(target) and tonumber(target) > 0 then
		AutoSellSystem.Count.Target = tonumber(target)
	end
	
	AutoSellSystem.Count.Enabled = true
	
	AutoSellSystem.Count._thread = task.spawn(function()
		while AutoSellSystem.Count.Enabled do
			task.wait(AutoSellSystem.Count.CheckDelay)
			
			if not AutoSellSystem.Count.Enabled then break end
			
			local current, max = getBagCount()
			
			if AutoSellSystem.Count.Target > 0 and current >= AutoSellSystem.Count.Target then
				if tick() - AutoSellSystem.Count._lastSell < 3 then
					continue
				end
				
				AutoSellSystem.Count._lastSell = tick()
				executeSell()
				task.wait(2)
			end
		end
	end)
	
	return true
end

function AutoSellSystem.Count.Stop()
	if not AutoSellSystem.Count.Enabled then return false end
	AutoSellSystem.Count.Enabled = false
	return true
end

function AutoSellSystem.Count.SetTarget(count)
	if tonumber(count) and tonumber(count) > 0 then
		AutoSellSystem.Count.Target = tonumber(count)
		return true
	end
	return false
end

function AutoSellSystem.Count.GetStatus()
	local cur, max = getBagCount()
	return {
		enabled = AutoSellSystem.Count.Enabled,
		target = AutoSellSystem.Count.Target,
		current = cur,
		max = max
	}
end

function AutoSellSystem.GetStats()
	return {
		totalSells = AutoSellSystem._totalSells,
		lastSellTime = AutoSellSystem._lastSellTime,
		remoteFound = SellRemote ~= nil,
		timerStatus = AutoSellSystem.Timer.GetStatus(),
		countStatus = AutoSellSystem.Count.GetStatus()
	}
end

function AutoSellSystem.ResetStats()
	AutoSellSystem._totalSells = 0
	AutoSellSystem._lastSellTime = 0
	AutoSellSystem.Timer._sellCount = 0
end

_G.AutoSellSystem = AutoSellSystem
return AutoSellSystem
end)()

CombinedModules.AutoSellTimer = (function()
local AutoSellTimer = {
	Enabled = false,
	Interval = 5,
	Thread = nil
}

local function Notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 4
        })
    end)
end

function AutoSellTimer.Start(interval)
	if AutoSellTimer.Enabled then
		warn("âš ï¸ AutoSellTimer sudah aktif!")
		return
	end

	if interval and tonumber(interval) and tonumber(interval) >= 1 then
		AutoSellTimer.Interval = tonumber(interval)
	end

	local AutoSell = _G.AutoSell
	if not AutoSell then
		warn("âŒ Modul AutoSell belum dimuat!")
		return
	end

	AutoSellTimer.Enabled = true
	Notify("Auto Sell Running", "Auto Sell Berjalan!", 4)

	AutoSellTimer.Thread = task.spawn(function()
		while AutoSellTimer.Enabled do
			task.wait(AutoSellTimer.Interval)
			if AutoSellTimer.Enabled and AutoSell and AutoSell.SellOnce then
				pcall(AutoSell.SellOnce)
			end
		end
	end)
end

function AutoSellTimer.Stop()
	if not AutoSellTimer.Enabled then
		warn("âš ï¸ AutoSellTimer belum aktif.")
		return
	end

	AutoSellTimer.Enabled = false
	Notify("Auto Sell Stopped", "Auto Sell Berhenti!", 4)
end

function AutoSellTimer.SetInterval(seconds)
	if tonumber(seconds) and seconds >= 1 then
		AutoSellTimer.Interval = tonumber(seconds)
	else
		warn("âŒ Interval tidak valid, harus >= 1 detik.")
	end
end

function AutoSellTimer.GetStatus()
end

return AutoSellTimer
end)()

CombinedModules.AutoTotem3X = (function()
    local AutoTotem3X = {}
    
    local RS = ReplicatedStorage
    local LP = localPlayer
    
    local Net = RS.Packages["_Index"]["sleitnick_net@0.2.0"].net
    local RE_EquipToolFromHotbar = Net["RE/EquipToolFromHotbar"]
    
    local HOTBAR_SLOT = 2
    local CLICK_COUNT = 5
    local CLICK_DELAY = 0.2
    local TRIANGLE_RADIUS = 58
    local CENTER_OFFSET = Vector3.new(0, 0, -7.25)
    
    local isRunning = false
    local currentTask = nil
    
    local function tp(pos)
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = CFrame.new(pos)
            task.wait(0.5)
            return true
        end
        return false
    end
    
    local function equipTotem()
        local success = pcall(function()
            RE_EquipToolFromHotbar:FireServer(HOTBAR_SLOT)
        end)
        task.wait(1.5)
        return success
    end
    
    local function autoClick()
        for i = 1, CLICK_COUNT do
            if not isRunning then break end
            
            pcall(function()
                VirtualUser:Button1Down(Vector2.new(0, 0))
                task.wait(0.05)
                VirtualUser:Button1Up(Vector2.new(0, 0))
            end)
            task.wait(CLICK_DELAY)
            
            local char = LP.Character
            if char then
                for _, tool in pairs(char:GetChildren()) do
                    if tool:IsA("Tool") then
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
            end
            task.wait(CLICK_DELAY)
        end
    end
    
    function AutoTotem3X.Start()
        
        if isRunning then
            return false, "Auto Totem sudah berjalan"
        end
        
        if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then
            return false, "Character tidak ditemukan"
        end
        
        isRunning = true
        
        currentTask = task.spawn(function()
            local success, err = pcall(function()
                local char = LP.Character or LP.CharacterAdded:Wait()
                local root = char:WaitForChild("HumanoidRootPart")
                
                local centerPos = root.Position
                local adjustedCenter = centerPos + CENTER_OFFSET
                
                local angles = {90, 210, 330}
                local totemPositions = {}
                
                for i, angleDeg in ipairs(angles) do
                    local angleRad = math.rad(angleDeg)
                    local offsetX = TRIANGLE_RADIUS * math.cos(angleRad)
                    local offsetZ = TRIANGLE_RADIUS * math.sin(angleRad)
                    table.insert(totemPositions, adjustedCenter + Vector3.new(offsetX, 0, offsetZ))
                end
                
                for i, pos in ipairs(totemPositions) do
                    if not isRunning then 
                        break 
                    end
                    
                    tp(pos)
                    equipTotem()
                    autoClick()
                    task.wait(2)
                end
                
                if isRunning then
                    tp(centerPos)
                    task.wait(1)
                end
            end)
            
            if not success then
                warn("[AutoTotem3X] Error: " .. tostring(err))
            end
            
            isRunning = false
            currentTask = nil
        end)
        
        return true, "Auto Totem 3X dimulai"
    end
    
    function AutoTotem3X.Stop()
        
        if not isRunning then
            return false, "Auto Totem tidak sedang berjalan"
        end
        
        isRunning = false
        
        if currentTask then
            task.cancel(currentTask)
            currentTask = nil
        end
        
        return true, "Auto Totem 3X dihentikan"
    end
    
    function AutoTotem3X.IsRunning()
        return isRunning
    end
    
    return AutoTotem3X
end)()

-- Module BlatantFixedV1
CombinedModules.BlatantFixedV1 = (function()
local BlatantV2 = {}
BlatantV2.Active = false
BlatantV2.Connections = {} -- Store connections for proper cleanup

BlatantV2.Settings = {
    ChargeDelay = 0.001,
    CompleteDelay = 0.001,
    CancelDelay = 0.001
}

local spamLoopThread = nil

local function safeFire(func)
    task.spawn(function()
        pcall(func)
    end)
end

local function ultraSpamLoop()
    while BlatantV2.Active do
        local startTime = tick()
        
        safeFire(function()
            NetEvents.RF_ChargeFishingRod:InvokeServer({[1] = startTime})
        end)
        
        task.wait(BlatantV2.Settings.ChargeDelay)
        
        local releaseTime = tick()
        safeFire(function()
            NetEvents.RF_RequestMinigame:InvokeServer(1, 0, releaseTime)
        end)
        
        task.wait(BlatantV2.Settings.CompleteDelay)
        
        safeFire(function()
            NetEvents.RE_FishingCompleted:FireServer()
        end)
        
        task.wait(BlatantV2.Settings.CancelDelay)
        safeFire(function()
            NetEvents.RF_CancelFishingInputs:InvokeServer()
        end)
    end
end

function BlatantV2.UpdateSettings(completeDelay, cancelDelay)
    if completeDelay ~= nil then
        BlatantV2.Settings.CompleteDelay = completeDelay
    end
    
    if cancelDelay ~= nil then
        BlatantV2.Settings.CancelDelay = cancelDelay
    end
end

function BlatantV2.Start()
    if BlatantV2.Active then 
        return
    end
    
    BlatantV2.Active = true
    
    -- Connect event listener ONLY when feature is active
    BlatantV2.Connections.Minigame = NetEvents.RE_MinigameChanged.OnClientEvent:Connect(function(state)
        if not BlatantV2.Active then return end
        
        task.spawn(function()
            task.wait(BlatantV2.Settings.CompleteDelay)
            
            safeFire(function()
                NetEvents.RE_FishingCompleted:FireServer()
            end)
            
            task.wait(BlatantV2.Settings.CancelDelay)
            safeFire(function()
                NetEvents.RF_CancelFishingInputs:InvokeServer()
            end)
        end)
    end)
    
    spamLoopThread = task.spawn(ultraSpamLoop)
end

function BlatantV2.Stop()
    if not BlatantV2.Active then 
        return
    end
    
    BlatantV2.Active = false
    
    -- Disconnect all connections to prevent memory leak and ping jumping
    for _, conn in pairs(BlatantV2.Connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    BlatantV2.Connections = {}
    
    -- Cancel the spam loop thread
    if spamLoopThread then
        task.cancel(spamLoopThread)
        spamLoopThread = nil
    end
    
    task.wait(0.2)
    
    safeFire(function()
        NetEvents.RF_CancelFishingInputs:InvokeServer()
    end)
    safeFire(function()
        NetEvents.RE_FishingCompleted:FireServer()
    end)
end

return BlatantV2
end)()

-- Module BlatantV2
CombinedModules.BlatantV2 = (function()
local UltraBlatant = {}
UltraBlatant.Active = false
UltraBlatant.Connections = {} -- Store connections for proper cleanup

UltraBlatant.Settings = {
    CompleteDelay = 0.73,
    CancelDelay = 0.3,
    ReCastDelay = 0.001
}

-- State tracking
local FishingState = {
    lastCompleteTime = 0,
    completeCooldown = 0.4
}

local fishingLoopThread = nil
local lastEventTime = 0

local function protectedComplete()
    local now = tick()
    
    if now - FishingState.lastCompleteTime < FishingState.completeCooldown then
        return false
    end
    
    FishingState.lastCompleteTime = now
    safeFire(function()
        NetEvents.RE_FishingCompleted:FireServer()
    end)
    
    return true
end

local function performCast()
    local now = tick()
    
    safeFire(function()
        NetEvents.RF_ChargeFishingRod:InvokeServer({[1] = now})
    end)
    safeFire(function()
        NetEvents.RF_RequestMinigame:InvokeServer(1, 0, now)
    end)
end

local function fishingLoop()
    while UltraBlatant.Active do
        performCast()
        
        task.wait(UltraBlatant.Settings.CompleteDelay)
        
        if UltraBlatant.Active then
            protectedComplete()
        end
        
        task.wait(UltraBlatant.Settings.CancelDelay)
        
        if UltraBlatant.Active then
            safeFire(function()
                NetEvents.RF_CancelFishingInputs:InvokeServer()
            end)
        end
        
        task.wait(UltraBlatant.Settings.ReCastDelay)
    end
end

function UltraBlatant.UpdateSettings(completeDelay, cancelDelay, reCastDelay)
    if completeDelay ~= nil then
        UltraBlatant.Settings.CompleteDelay = completeDelay
    end
    
    if cancelDelay ~= nil then
        UltraBlatant.Settings.CancelDelay = cancelDelay
    end
    
    if reCastDelay ~= nil then
        UltraBlatant.Settings.ReCastDelay = reCastDelay
    end
end

function UltraBlatant.Start()
    if UltraBlatant.Active then 
        return
    end
    
    UltraBlatant.Active = true
    FishingState.lastCompleteTime = 0
    lastEventTime = 0
    
    -- Connect event listener ONLY when feature is active
    UltraBlatant.Connections.Minigame = NetEvents.RE_MinigameChanged.OnClientEvent:Connect(function(state)
        if not UltraBlatant.Active then return end
        
        local now = tick()
        
        if now - lastEventTime < 0.2 then
            return
        end
        lastEventTime = now
        
        if now - FishingState.lastCompleteTime < 0.3 then
            return
        end
        
        task.spawn(function()
            task.wait(UltraBlatant.Settings.CompleteDelay)
            
            if protectedComplete() then
                task.wait(UltraBlatant.Settings.CancelDelay)
                safeFire(function()
                    NetEvents.RF_CancelFishingInputs:InvokeServer()
                end)
            end
        end)
    end)
    
    task.wait(0.2)
    fishingLoopThread = task.spawn(fishingLoop)
end

function UltraBlatant.Stop()
    if not UltraBlatant.Active then 
        return
    end
    
    UltraBlatant.Active = false
    
    -- Disconnect all connections to prevent memory leak and ping jumping
    for _, conn in pairs(UltraBlatant.Connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    UltraBlatant.Connections = {}
    
    -- Cancel the fishing loop thread
    if fishingLoopThread then
        task.cancel(fishingLoopThread)
        fishingLoopThread = nil
    end
    
    safeFire(function()
        NetEvents.RF_CancelFishingInputs:InvokeServer()
    end)
    safeFire(function()
        NetEvents.RE_FishingCompleted:FireServer()
    end)
end

return UltraBlatant
end)()

CombinedModules.DisableCutscenes = (function()
    local DisableCutscenes = {}
    
    local CutsceneController = nil
    local OldPlayCutscene = nil
    local isDisabled = false
    
    local function initializeCutsceneHook()
        pcall(function()
            CutsceneController = require(game:GetService("ReplicatedStorage"):WaitForChild("Controllers"):WaitForChild("CutsceneController"))
            if CutsceneController and CutsceneController.Play then
                OldPlayCutscene = CutsceneController.Play
                
                CutsceneController.Play = function(self, ...)
                    if isDisabled then
                        return 
                    end
                    return OldPlayCutscene(self, ...)
                end
            end
        end)
    end
    
    initializeCutsceneHook()
    
    function DisableCutscenes.Start()
        if isDisabled then return end
        isDisabled = true
        
        if not CutsceneController then
            initializeCutsceneHook()
        end
    end
    
    function DisableCutscenes.Stop()
        if not isDisabled then return end
        isDisabled = false
    end
    
    function DisableCutscenes.IsHooked()
        return CutsceneController ~= nil and OldPlayCutscene ~= nil
    end
    
    return DisableCutscenes
end)()

-- Module DisableExtras
CombinedModules.DisableExtras = (function()
local module = {}

local VFXFolder = ReplicatedStorage:WaitForChild("VFX")
local DisableNotificationConnection = nil
local isVFXDisabled = false

-- Deteksi support untuk override module
local supportsModuleOverride = false
local VFXControllerModule = nil
local originalVFXHandle = nil
local originalRenderAtPoint = nil
local originalRenderInstance = nil

-- Cek apakah executor support override module functions
local success = pcall(function()
    VFXControllerModule = require(ReplicatedStorage:WaitForChild("Controllers").VFXController)
    originalVFXHandle = VFXControllerModule.Handle
    originalRenderAtPoint = VFXControllerModule.RenderAtPoint
    originalRenderInstance = VFXControllerModule.RenderInstance
    supportsModuleOverride = true
end)

if not success then
    warn("[DisableExtras] Module override not supported, using fallback method (delete)")
end

-- ========== NOTIFICATION FUNCTIONS ==========
function module.StartSmallNotification()
    if DisableNotificationConnection then return end
    
    local PlayerGui = game:GetService("Players").LocalPlayer.PlayerGui
    local SmallNotification = PlayerGui:FindFirstChild("Small Notification")
    
    if not SmallNotification then
        SmallNotification = PlayerGui:WaitForChild("Small Notification", 5)
        if not SmallNotification then
            return false
        end
    end
    
    -- Gunakan RenderStepped untuk disable GUI setiap frame
    DisableNotificationConnection = RunService.RenderStepped:Connect(function()
        SmallNotification.Enabled = false
    end)
end

function module.StopSmallNotification()
    -- Putuskan koneksi RenderStepped
    if DisableNotificationConnection then
        DisableNotificationConnection:Disconnect()
        DisableNotificationConnection = nil
    end
    
    -- Kembalikan GUI ke status normal
    local PlayerGui = game:GetService("Players").LocalPlayer.PlayerGui
    local SmallNotification = PlayerGui:FindFirstChild("Small Notification")
    if SmallNotification then
        SmallNotification.Enabled = true
    end
end

-- ========== SKIN EFFECT FUNCTIONS ==========

-- Fungsi fallback: hapus efek secara langsung
local SkinEffectConnection = nil
local function disableDiveEffects()
    for _, child in pairs(VFXFolder:GetChildren()) do
        if child.Name:match("Dive$") then
            child:Destroy()
        end
    end
    
    local cosmeticFolder = workspace:FindFirstChild("CosmeticFolder")
    if cosmeticFolder then
        pcall(function() cosmeticFolder:ClearAllChildren() end)
    end
end

function module.StartSkinEffect()
    if isVFXDisabled then return end
    isVFXDisabled = true
    
    if supportsModuleOverride then
        -- METHOD 1: Override functions (untuk executor yang support)
        VFXControllerModule.Handle = function(...) end
        VFXControllerModule.RenderAtPoint = function(...) end
        VFXControllerModule.RenderInstance = function(...) end
        
        -- Hapus efek yang sudah ada
        local cosmeticFolder = workspace:FindFirstChild("CosmeticFolder")
        if cosmeticFolder then
            pcall(function() cosmeticFolder:ClearAllChildren() end)
        end
    else
        -- METHOD 2: Fallback - hapus efek setiap frame (untuk executor seperti Xeno)
        disableDiveEffects()
        
        -- Loop Heartbeat untuk hapus efek terus-menerus
        SkinEffectConnection = RunService.Heartbeat:Connect(function()
            if isVFXDisabled then
                disableDiveEffects()
            end
        end)
        
        -- Pantau child baru di VFX
        VFXFolder.ChildAdded:Connect(function(child)
            if isVFXDisabled and child.Name:match("Dive$") then
                child:Destroy()
            end
        end)
        
        -- Pantau CosmeticFolder juga
        local cosmeticFolder = workspace:FindFirstChild("CosmeticFolder")
        if cosmeticFolder then
            cosmeticFolder.ChildAdded:Connect(function(child)
                if isVFXDisabled then
                    child:Destroy()
                end
            end)
        end
    end
end

function module.StopSkinEffect()
    if not isVFXDisabled then return end
    isVFXDisabled = false
    
    if supportsModuleOverride then
        -- METHOD 1: Kembalikan fungsi asli
        VFXControllerModule.Handle = originalVFXHandle
        VFXControllerModule.RenderAtPoint = originalRenderAtPoint
        VFXControllerModule.RenderInstance = originalRenderInstance
    else
        -- METHOD 2: Disconnect loop
        if SkinEffectConnection then
            SkinEffectConnection:Disconnect()
            SkinEffectConnection = nil
        end
    end
end

return module
end)()

-- Module NoFishingAnimation
CombinedModules.NoFishingAnimation = (function()
local NoFishingAnimation = {}
NoFishingAnimation.Enabled = false
NoFishingAnimation.Connection = nil
NoFishingAnimation.SavedPose = {}
NoFishingAnimation.ReelingTrack = nil
NoFishingAnimation.AnimationBlocker = nil

-- Fungsi untuk find ReelingIdle animation
local function getOrCreateReelingAnimation()
    local success, result = pcall(function()
        local character = localPlayer.Character
        if not character then return nil end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return nil end
        
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return nil end
        
        -- Cari animasi ReelingIdle yang sudah ada
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            local name = track.Name
            if name:find("Reel") and name:find("Idle") then
                return track
            end
        end
        
        -- Cari di semua loaded animations
        for _, track in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
            if track.Animation then
                if track.Name:find("Reel") then
                    return track
                end
            end
        end
        
        -- Jika tidak ada, coba cari di character tools
        for _, tool in pairs(character:GetChildren()) do
            if tool:IsA("Tool") then
                for _, anim in pairs(tool:GetDescendants()) do
                    if anim:IsA("Animation") then
                        local name = anim.Name
                        if name:find("Reel") and name:find("Idle") then
                            local track = animator:LoadAnimation(anim)
                            return track
                        end
                    end
                end
            end
        end
        
        return nil
    end)
    
    if success then
        return result
    end
    return nil
end

-- Fungsi untuk capture pose dari Motor6D
local function capturePose()
    NoFishingAnimation.SavedPose = {}
    local count = 0
    
    pcall(function()
        local character = localPlayer.Character
        if not character then return end
        
        -- Simpan SEMUA Motor6D
        for _, descendant in pairs(character:GetDescendants()) do
            if descendant:IsA("Motor6D") then
                NoFishingAnimation.SavedPose[descendant.Name] = {
                    Part = descendant,
                    C0 = descendant.C0,
                    C1 = descendant.C1,
                    Transform = descendant.Transform
                }
                count = count + 1
            end
        end
    end)
    
    return count > 0
end

-- Fungsi untuk STOP SEMUA animasi secara permanent
local function killAllAnimations()
    pcall(function()
        local character = localPlayer.Character
        if not character then return end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return nil end
        
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return nil end
        
        -- STOP semua playing animations
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            track:Stop(0)
            track:Destroy()
        end
        
        -- STOP semua humanoid animations
        for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
            track:Stop(0)
            track:Destroy()
        end
    end)
end

-- Fungsi untuk BLOCK animasi baru agar tidak play
local function blockNewAnimations()
    if NoFishingAnimation.AnimationBlocker then
        NoFishingAnimation.AnimationBlocker:Disconnect()
    end
    
    pcall(function()
        local character = localPlayer.Character
        if not character then return end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return nil end
        
        -- Hook semua animasi baru yang mau play
        NoFishingAnimation.AnimationBlocker = animator.AnimationPlayed:Connect(function(animTrack)
            if NoFishingAnimation.Enabled then
                animTrack:Stop(0)
                animTrack:Destroy()
            end
        end)
    end)
end

-- Fungsi untuk freeze pose
local function freezePose()
    if NoFishingAnimation.Connection then
        NoFishingAnimation.Connection:Disconnect()
    end
    
    NoFishingAnimation.Connection = RunService.RenderStepped:Connect(function()
        if not NoFishingAnimation.Enabled then return end
        
        pcall(function()
            local character = localPlayer.Character
            if not character then return end
            
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end
            
            -- FORCE STOP semua animasi setiap frame
            for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
            
            -- APPLY SAVED POSE setiap frame
            for jointName, poseData in pairs(NoFishingAnimation.SavedPose) do
                local motor = character:FindFirstChild(jointName, true)
                if motor and motor:IsA("Motor6D") then
                    motor.C0 = poseData.C0
                    motor.C1 = poseData.C1
                end
            end
        end)
    end)
end

-- Fungsi Stop
local function stopFreeze()
    if NoFishingAnimation.Connection then
        NoFishingAnimation.Connection:Disconnect()
        NoFishingAnimation.Connection = nil
    end
    
    if NoFishingAnimation.AnimationBlocker then
        NoFishingAnimation.AnimationBlocker:Disconnect()
        NoFishingAnimation.AnimationBlocker = nil
    end
    
    if NoFishingAnimation.ReelingTrack then
        NoFishingAnimation.ReelingTrack:Stop()
        NoFishingAnimation.ReelingTrack = nil
    end
    
    NoFishingAnimation.SavedPose = {}
end

function NoFishingAnimation.Start()
    if NoFishingAnimation.Enabled then
        return false, "Already enabled"
    end
    
    local character = localPlayer.Character
    if not character then 
        return false, "Character not found"
    end
    
    -- 1. Cari atau buat ReelingIdle animation
    local reelingTrack = getOrCreateReelingAnimation()
    
    if reelingTrack then
        -- 2. Play animasi (pause setelah beberapa frame)
        reelingTrack:Play()
        reelingTrack:AdjustSpeed(0) -- Pause animasi di frame pertama
        
        NoFishingAnimation.ReelingTrack = reelingTrack
        
        -- 3. Tunggu animasi apply ke Motor6D
        task.wait(0.2)
        
        -- 4. Capture pose
        local success = capturePose()
        
        if success then
            -- 5. KILL semua animasi
            killAllAnimations()
            
            -- 6. Block animasi baru
            blockNewAnimations()
            
            -- 7. Enable freeze
            NoFishingAnimation.Enabled = true
            freezePose()
            
            return true, "Pose frozen successfully"
        else
            reelingTrack:Stop()
            return false, "Failed to capture pose"
        end
    else
        return false, "Reeling animation not found"
    end
end

-- Fungsi Start dengan delay (RECOMMENDED)
function NoFishingAnimation.StartWithDelay(delay, callback)
    if NoFishingAnimation.Enabled then
        return false, "Already enabled"
    end
    
    delay = delay or 2
    
    -- Jalankan di coroutine agar tidak blocking
    task.spawn(function()
        task.wait(delay)
        
        local success = capturePose()
        
        if success then
            -- KILL semua animasi
            killAllAnimations()
            
            -- Block animasi baru
            blockNewAnimations()
            
            -- Enable freeze
            NoFishingAnimation.Enabled = true
            freezePose()
            
            -- Callback jika ada
            if callback then
                callback(true, "Pose frozen successfully")
            end
        else
            -- Callback error
            if callback then
                callback(false, "Failed to capture pose")
            end
        end
    end)
    
    return true, "Starting with delay..."
end

-- Fungsi Stop
function NoFishingAnimation.Stop()
    if not NoFishingAnimation.Enabled then
        return false, "Already disabled"
    end
    
    NoFishingAnimation.Enabled = false
    stopFreeze()
    
    return true, "Pose unfrozen"
end

-- Fungsi untuk cek status
function NoFishingAnimation.IsEnabled()
    return NoFishingAnimation.Enabled
end

-- Handle respawn
localPlayer.CharacterAdded:Connect(function(character)
    if NoFishingAnimation.Enabled then
        NoFishingAnimation.Enabled = false
        stopFreeze()
    end
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
    if player == localPlayer then
        if NoFishingAnimation.Enabled then
            NoFishingAnimation.Stop()
        end
    end
end)

return NoFishingAnimation
end)()

-- Module WalkOnWater
CombinedModules.WalkOnWater = (function()
-- 🔗 Menggunakan shared services (Players, RunService, Workspace, LocalPlayer sudah didefinisikan di atas)

local WalkOnWater = {
	Enabled = false,
	Platform = nil,
	AlignPos = nil,
	Connection = nil
}

local PLATFORM_SIZE = 14
local OFFSET = 3
local LAST_WATER_Y = nil

local function GetCharacterReferences()
	local char = LocalPlayer.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end

	return char, humanoid, hrp
end

local function ForceSurfaceLift()
	local _, humanoid, hrp = GetCharacterReferences()
	if not humanoid or not hrp then return end

	if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
		return
	end

	for _ = 1, 60 do
		hrp.Velocity = Vector3.new(0, 80, 0)
		task.wait(0.03)

		if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
			break
		end
	end

	hrp.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
end

local function GetWaterHeight()
	local _, _, hrp = GetCharacterReferences()
	if not hrp then return LAST_WATER_Y end

	local origin = hrp.Position + Vector3.new(0, 5, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { LocalPlayer.Character }
	params.IgnoreWater = false

	local result = Workspace:Raycast(
		origin,
		Vector3.new(0, -600, 0),
		params
	)

	if result then
		LAST_WATER_Y = result.Position.Y
		return LAST_WATER_Y
	end

	return LAST_WATER_Y
end

local function CreatePlatform()
	if WalkOnWater.Platform then
		WalkOnWater.Platform:Destroy()
	end

	local p = Instance.new("Part")
	p.Size = Vector3.new(PLATFORM_SIZE, 1, PLATFORM_SIZE)
	p.Anchored = true
	p.CanCollide = true
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	p.Name = "WaterLockPlatform"
	p.Parent = Workspace

	WalkOnWater.Platform = p
end

local function SetupAlign()
	local _, _, hrp = GetCharacterReferences()
	if not hrp then return false end

	if WalkOnWater.AlignPos then
		WalkOnWater.AlignPos:Destroy()
	end

	local att = hrp:FindFirstChild("RootAttachment")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "RootAttachment"
		att.Parent = hrp
	end

	local ap = Instance.new("AlignPosition")
	ap.Attachment0 = att
	ap.MaxForce = math.huge
	ap.MaxVelocity = math.huge
	ap.Responsiveness = 200
	ap.RigidityEnabled = true
	ap.Parent = hrp

	WalkOnWater.AlignPos = ap
	return true
end

local function Cleanup()
	if WalkOnWater.Connection then
		WalkOnWater.Connection:Disconnect()
		WalkOnWater.Connection = nil
	end

	if WalkOnWater.AlignPos then
		WalkOnWater.AlignPos:Destroy()
		WalkOnWater.AlignPos = nil
	end

	if WalkOnWater.Platform then
		WalkOnWater.Platform:Destroy()
		WalkOnWater.Platform = nil
	end
end

function WalkOnWater.Start()
	if WalkOnWater.Enabled then return end

	local char, humanoid, hrp = GetCharacterReferences()
	if not char or not humanoid or not hrp then return end

	ForceSurfaceLift()

	WalkOnWater.Enabled = true
	LAST_WATER_Y = nil

	CreatePlatform()
	if not SetupAlign() then
		WalkOnWater.Enabled = false
		Cleanup()
		return
	end

	WalkOnWater.Connection = RunService.Heartbeat:Connect(function()
		if not WalkOnWater.Enabled then return end

		local _, _, currentHRP = GetCharacterReferences()
		if not currentHRP then return end

		local waterY = GetWaterHeight()
		if not waterY then return end

		if WalkOnWater.Platform then
			WalkOnWater.Platform.CFrame = CFrame.new(
				currentHRP.Position.X,
				waterY - 0.5,
				currentHRP.Position.Z
			)
		end

		if WalkOnWater.AlignPos then
			WalkOnWater.AlignPos.Position = Vector3.new(
				currentHRP.Position.X,
				waterY + OFFSET,
				currentHRP.Position.Z
			)
		end
	end)
end

function WalkOnWater.Stop()
	WalkOnWater.Enabled = false
	Cleanup()
end

LocalPlayer.CharacterAdded:Connect(function()
	if WalkOnWater.Enabled then
		task.wait(0.5)
		Cleanup()
		WalkOnWater.Enabled = false
		WalkOnWater.Start()
	end
end)
return WalkOnWater
end)()

CombinedModules.AutoFavorite = (function()
-- 🔗 Menggunakan shared services (ReplicatedStorage, Players sudah didefinisikan di atas)
local AutoFavoriteModule = {}

-- Services & References (menggunakan shared)
local v0 = {
    RS = ReplicatedStorage,
    Players = Players
}

-- LocalPlayer sudah didefinisikan di shared definitions sebagai localPlayer

-- Module references
local v5, v6, v7
local referencesInitialized = false

local function InitializeReferences()
    if referencesInitialized then return true end
    
    local success = pcall(function()
        v5 = {
            Net = v0.RS.Packages._Index["sleitnick_net@0.2.0"].net,
            ItemUtility = require(v0.RS.Shared.ItemUtility),
            PlayerStatsUtility = require(v0.RS.Shared.PlayerStatsUtility)
        }
        
        v6 = {
            Events = {
                REFav = v5.Net["RE/FavoriteItem"]
            }
        }
        
        v7 = {
            Data = require(v0.RS.Packages.Replion).Client:WaitReplion("Data"),
            Items = v0.RS:WaitForChild("Items"),
            Variants = v0.RS:WaitForChild("Variants")
        }
        
        referencesInitialized = true
    end)
    
    return success
end

-- State management
local v8 = {
    selectedName = {},
    selectedRarity = {},
    selectedVariant = {},
    autoFavEnabled = false
}

local v22 = {} -- Favorite cache

-- Helper function: convert array to set
local function toSet(arr)
    local set = {}
    for _, v in ipairs(arr) do
        set[v] = true
    end
    return set
end

-- Build fish list from Items folder
local v11 = {}
local function BuildFishList()
    v11 = {}
    
    if not referencesInitialized then
        InitializeReferences()
    end
    
    if not v7 or not v7.Items then return v11 end
    
    pcall(function()
        for _, itemFolder in ipairs(v7.Items:GetChildren()) do
            if itemFolder:IsA("Folder") then
                for _, fishModule in ipairs(itemFolder:GetChildren()) do
                    if fishModule:IsA("ModuleScript") then
                        local success, fishData = pcall(require, fishModule)
                        if success and fishData and fishData.Data then
                            local displayName = fishData.Data.DisplayName or fishData.Data.Name
                            if displayName and not table.find(v11, displayName) then
                                table.insert(v11, displayName)
                            end
                        end
                    end
                end
            elseif itemFolder:IsA("ModuleScript") then
                local success, fishData = pcall(require, itemFolder)
                if success and fishData and fishData.Data then
                    local displayName = fishData.Data.DisplayName or fishData.Data.Name
                    if displayName and not table.find(v11, displayName) then
                        table.insert(v11, displayName)
                    end
                end
            end
        end
        table.sort(v11)
    end)
    
    return v11
end

-- Build variant list from Variants folder
local variantList = {}
local function BuildVariantList()
    variantList = {}
    
    if not referencesInitialized then
        InitializeReferences()
    end
    
    if not v7 or not v7.Variants then return variantList end
    
    pcall(function()
        for _, variantModule in ipairs(v7.Variants:GetChildren()) do
            if variantModule:IsA("ModuleScript") then
                local variantName = variantModule.Name
                if variantName and variantName ~= "1x1x1x1" and not table.find(variantList, variantName) then
                    table.insert(variantList, variantName)
                end
            end
        end
        table.sort(variantList)
    end)
    
    return variantList
end

-- Scan inventory and favorite items (HYBRID MODE)
local function scanInventory()
    if not v8.autoFavEnabled then return end
    if not referencesInitialized then return end
    
    pcall(function()
        local inventory = v7.Data:GetExpect({"Inventory", "Items"})
        
        for _, item in ipairs(inventory) do
            local isFavorited = rawget(v22, item.UUID)
            if isFavorited == nil then
                isFavorited = item.Favorited
            end
            
            if not isFavorited then
                local shouldFavorite = false
                
                -- Get fish data
                local fishData = v5.ItemUtility:GetItemData(item.Id)
                if not fishData then continue end
                
                local fishName = fishData.Data.DisplayName or fishData.Data.Name
                local fishTier = fishData.Data.Tier
                local variantId = item.Metadata and item.Metadata.VariantId or "None"
                
                -- PRIORITY 1: Check by Name + Variant (Specific combination)
                if next(v8.selectedName) and next(v8.selectedVariant) and fishName then
                    if v8.selectedName[fishName] then
                        if variantId ~= "None" and v8.selectedVariant[variantId] then
                            shouldFavorite = true
                        end
                    end
                end
                
                -- PRIORITY 2: Check by Variant only (All fish with this variant)
                if not shouldFavorite and next(v8.selectedVariant) and not next(v8.selectedName) then
                    if variantId ~= "None" and v8.selectedVariant[variantId] then
                        shouldFavorite = true
                    end
                end
                
                -- PRIORITY 3: Check by Name only (Any variant of this fish)
                if not shouldFavorite and next(v8.selectedName) and not next(v8.selectedVariant) and fishName then
                    if v8.selectedName[fishName] then
                        shouldFavorite = true
                    end
                end
                
                -- PRIORITY 4: Check by Rarity (if nothing else selected)
                if not shouldFavorite and next(v8.selectedRarity) and not next(v8.selectedName) and not next(v8.selectedVariant) and fishTier then
                    local tierNames = {
                        [1] = "Common",
                        [2] = "Uncommon",
                        [3] = "Rare",
                        [4] = "Epic",
                        [5] = "Legendary",
                        [6] = "Mythic",
                        [7] = "Secret"
                    }
                    
                    local tierName = tierNames[fishTier]
                    if tierName and v8.selectedRarity[tierName] then
                        shouldFavorite = true
                    end
                end
                
                -- Favorite the item
                if shouldFavorite then
                    task.spawn(function()
                        task.wait(0.1)
                        v6.Events.REFav:FireServer(item.UUID)
                        rawset(v22, item.UUID, true)
                    end)
                end
            end
        end
    end)
end

-- ============= PUBLIC FUNCTIONS =============

function AutoFavoriteModule.GetAllFishNames()
    if #v11 == 0 then
        BuildFishList()
    end
    return #v11 > 0 and v11 or {"No Fish Found"}
end

function AutoFavoriteModule.GetAllVariants()
    if #variantList == 0 then
        BuildVariantList()
    end
    return #variantList > 0 and variantList or {"No Variants Found"}
end

function AutoFavoriteModule.GetAllTiers()
    return {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"}
end

function AutoFavoriteModule.SetSelectedNames(names)
    v8.selectedName = toSet(names)
    -- AUTO SCAN ketika filter berubah
    if v8.autoFavEnabled then
        scanInventory()
    end
end

function AutoFavoriteModule.SetSelectedRarity(rarities)
    v8.selectedRarity = toSet(rarities)
    -- AUTO SCAN ketika filter berubah
    if v8.autoFavEnabled then
        scanInventory()
    end
end

function AutoFavoriteModule.SetSelectedVariants(variants)
    v8.selectedVariant = toSet(variants)
    -- AUTO SCAN ketika filter berubah
    if v8.autoFavEnabled then
        scanInventory()
    end
end

function AutoFavoriteModule.GetCurrentMode()
    local hasNames = next(v8.selectedName) ~= nil
    local hasVariants = next(v8.selectedVariant) ~= nil
    local hasRarity = next(v8.selectedRarity) ~= nil
    
    if hasNames and hasVariants then
        return "Name + Variant (Specific)"
    elseif hasVariants and not hasNames then
        return "Variant Only (All Fish)"
    elseif hasNames and not hasVariants then
        return "Name Only (Any Variant)"
    elseif hasRarity then
        return "Rarity Only"
    else
        return "No Filter Selected"
    end
end

function AutoFavoriteModule.Start()
    if not referencesInitialized then
        local success = InitializeReferences()
        if not success then
            return false, "Failed to initialize"
        end
    end
    
    v8.autoFavEnabled = true
    
    -- Scan current inventory
    scanInventory()
    
    -- Monitor inventory changes
    if v7 and v7.Data then
        v7.Data:OnChange({"Inventory", "Items"}, scanInventory)
    end
    
    return true, "Started"
end

function AutoFavoriteModule.Stop()
    v8.autoFavEnabled = false
    return true, "Stopped"
end

function AutoFavoriteModule.UnfavoriteAll()
    if not referencesInitialized then return end
    
    pcall(function()
        local inventory = v7.Data:GetExpect({"Inventory", "Items"})
        for _, item in ipairs(inventory) do
            local isFavorited = rawget(v22, item.UUID)
            if isFavorited == nil then
                isFavorited = item.Favorited
            end
            
            if isFavorited then
                v6.Events.REFav:FireServer(item.UUID)
                rawset(v22, item.UUID, false)
            end
        end
    end)
end

function AutoFavoriteModule.RefreshLists()
    v11 = {}
    variantList = {}
    BuildFishList()
    BuildVariantList()
    return {
        FishCount = #v11,
        VariantCount = #variantList
    }
end

function AutoFavoriteModule.IsEnabled()
    return v8.autoFavEnabled
end

function AutoFavoriteModule.GetStatus()
    return {
        Enabled = v8.autoFavEnabled,
        Mode = AutoFavoriteModule.GetCurrentMode(),
        FishCount = #v11,
        VariantCount = #variantList,
        SelectedNames = v8.selectedName,
        SelectedRarity = v8.selectedRarity,
        SelectedVariants = v8.selectedVariant
    }
end

-- Auto-initialize
task.spawn(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    task.wait(1)
    
    local success = InitializeReferences()
    if success then
        BuildFishList()
        BuildVariantList()
    else
        task.wait(2)
        InitializeReferences()
        BuildFishList()
        BuildVariantList()
    end
end)

return AutoFavoriteModule
end)()

-- Module LockPosition
CombinedModules.LockPosition = (function()
-- LockPosition.lua
-- 🔗 Menggunakan shared services (RunService, localPlayer sudah didefinisikan di atas)

local LockPosition = {}
LockPosition.Enabled = false
LockPosition.LockedPos = nil
LockPosition.Connection = nil

-- Aktifkan Lock Position
function LockPosition.Start()
    if LockPosition.Enabled then return end
    LockPosition.Enabled = true

    -- Menggunakan shared localPlayer
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")

    LockPosition.LockedPos = hrp.CFrame

    -- Loop untuk menjaga posisi
    LockPosition.Connection = RunService.Heartbeat:Connect(function()
        if not LockPosition.Enabled then return end

        local c = player.Character
        if not c then return end
        
        local hrp2 = c:FindFirstChild("HumanoidRootPart")
        if not hrp2 then return end

        -- Selalu kembalikan ke posisi yang dikunci
        hrp2.CFrame = LockPosition.LockedPos
    
    end)
end

-- Nonaktifkan Lock Position
function LockPosition.Stop()
    LockPosition.Enabled = false

    if LockPosition.Connection then
        LockPosition.Connection:Disconnect()
        LockPosition.Connection = nil
    end
end

return LockPosition
end)()

-- Module SkinSwapAnimation
CombinedModules.SkinSwapAnimation = (function()
-- 🔗 Menggunakan shared services (Players, RunService, localPlayer sudah didefinisikan di atas)

local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")

local Animator = humanoid:FindFirstChildOfClass("Animator")
if not Animator then
    Animator = Instance.new("Animator", humanoid)
end

local SkinAnimation = {}
SkinAnimation.Connections = {} -- Store connections for proper cleanup

local SkinDatabase = {
    ["Eclipse"] = "rbxassetid://107940819382815",
    ["HolyTrident"] = "rbxassetid://128167068291703",
    ["SoulScythe"] = "rbxassetid://82259219343456",
    ["OceanicHarpoon"] = "rbxassetid://76325124055693",
    ["BinaryEdge"] = "rbxassetid://109653945741202",
    ["Vanquisher"] = "rbxassetid://93884986836266",
    ["KrampusScythe"] = "rbxassetid://134934781977605",
    ["BanHammer"] = "rbxassetid://96285280763544",
    ["CorruptionEdge"] = "rbxassetid://126613975718573",
    ["PrincessParasol"] = "rbxassetid://99143072029495"
}

local CurrentSkin = nil
local AnimationPool = {}
local IsEnabled = false
local POOL_SIZE = 3

local killedTracks = {}
local replaceCount = 0
local currentPoolIndex = 1

local function LoadAnimationPool(skinId)
    local animId = SkinDatabase[skinId]
    if not animId then
        return false
    end
    
    -- Clear old pool
    for _, track in ipairs(AnimationPool) do
        pcall(function()
            track:Stop(0)
            track:Destroy()
        end)
    end
    AnimationPool = {}
    
    -- Create animation
    local anim = Instance.new("Animation")
    anim.AnimationId = animId
    anim.Name = "CUSTOM_SKIN_ANIM"
    
    -- Load pool of tracks
    for i = 1, POOL_SIZE do
        local track = Animator:LoadAnimation(anim)
        track.Priority = Enum.AnimationPriority.Action4
        track.Looped = false
        track.Name = "SKIN_POOL_" .. i
        
        -- Pre-cache
        task.spawn(function()
            pcall(function()
                track:Play(0, 1, 0)
                task.wait(0.05)
                track:Stop(0)
            end)
        end)
        
        table.insert(AnimationPool, track)
    end
    
    currentPoolIndex = 1
    return true
end

local function GetNextTrack()
    for i = 1, POOL_SIZE do
        local track = AnimationPool[i]
        if track and not track.IsPlaying then
            return track
        end
    end
    
    currentPoolIndex = currentPoolIndex % POOL_SIZE + 1
    return AnimationPool[currentPoolIndex]
end

local function IsFishCaughtAnimation(track)
    if not track or not track.Animation then return false end
    
    local trackName = string.lower(track.Name or "")
    local animName = string.lower(track.Animation.Name or "")
    
    if string.find(trackName, "fishcaught") or 
       string.find(animName, "fishcaught") or
       string.find(trackName, "caught") or 
       string.find(animName, "caught") then
        return true
    end
    
    return false
end

local function InstantReplace(originalTrack)
    local nextTrack = GetNextTrack()
    if not nextTrack then return end
    
    replaceCount = replaceCount + 1
    killedTracks[originalTrack] = tick()
    
    -- Kill original
    task.spawn(function()
        for i = 1, 10 do
            pcall(function()
                if originalTrack.IsPlaying then
                    originalTrack:Stop(0)
                    originalTrack:AdjustSpeed(0)
                    originalTrack.TimePosition = 0
                end
            end)
            task.wait()
        end
    end)
    
    -- Play custom
    pcall(function()
        if nextTrack.IsPlaying then
            nextTrack:Stop(0)
        end
        nextTrack:Play(0, 1, 1)
        nextTrack:AdjustSpeed(1)
    end)
    
    -- Cleanup
    task.delay(1, function()
        killedTracks[originalTrack] = nil
    end)
end

-- CharacterAdded connection (this one is okay to keep always-on as it's for respawn handling)
player.CharacterAdded:Connect(function(newChar)
    task.wait(1.5)
    
    char = newChar
    humanoid = char:WaitForChild("Humanoid")
    Animator = humanoid:FindFirstChildOfClass("Animator")
    if not Animator then
        Animator = Instance.new("Animator", humanoid)
    end
    
    killedTracks = {}
    replaceCount = 0
    
    if IsEnabled and CurrentSkin then
        task.wait(0.5)
        LoadAnimationPool(CurrentSkin)
        
        -- Reconnect animations listener for new humanoid
        if SkinAnimation.Connections.AnimationPlayed then
            SkinAnimation.Connections.AnimationPlayed:Disconnect()
        end
        SkinAnimation.Connections.AnimationPlayed = humanoid.AnimationPlayed:Connect(function(track)
            if not IsEnabled then return end
            if IsFishCaughtAnimation(track) then
                task.spawn(function()
                    InstantReplace(track)
                end)
            end
        end)
    end
end)

function SkinAnimation.SwitchSkin(skinId)
    if not SkinDatabase[skinId] then
        return false
    end
    
    CurrentSkin = skinId
    
    if IsEnabled then
        return LoadAnimationPool(skinId)
    end
    
    return true
end

function SkinAnimation.Enable()
    if IsEnabled then
        return false
    end
    
    if not CurrentSkin then
        return false
    end
    
    local success = LoadAnimationPool(CurrentSkin)
    if success then
        IsEnabled = true
        killedTracks = {}
        replaceCount = 0
        
        -- Connect AnimationPlayed ONLY when enabled
        SkinAnimation.Connections.AnimationPlayed = humanoid.AnimationPlayed:Connect(function(track)
            if not IsEnabled then return end
            if IsFishCaughtAnimation(track) then
                task.spawn(function()
                    InstantReplace(track)
                end)
            end
        end)
        
        -- Connect RenderStepped ONLY when enabled
        SkinAnimation.Connections.RenderStepped = RunService.RenderStepped:Connect(function()
            if not IsEnabled then return end
            
            local tracks = humanoid:GetPlayingAnimationTracks()
            
            for _, track in ipairs(tracks) do
                if string.find(string.lower(track.Name or ""), "skin_pool") then
                    continue
                end
                
                if killedTracks[track] then
                    if track.IsPlaying then
                        pcall(function()
                            track:Stop(0)
                            track:AdjustSpeed(0)
                        end)
                    end
                    continue
                end
                
                if track.IsPlaying and IsFishCaughtAnimation(track) then
                    task.spawn(function()
                        InstantReplace(track)
                    end)
                end
            end
        end)
        
        -- Connect Heartbeat ONLY when enabled
        SkinAnimation.Connections.Heartbeat = RunService.Heartbeat:Connect(function()
            if not IsEnabled then return end
            
            local tracks = humanoid:GetPlayingAnimationTracks()
            
            for _, track in ipairs(tracks) do
                if string.find(string.lower(track.Name or ""), "skin_pool") then
                    continue
                end
                
                if killedTracks[track] and track.IsPlaying then
                    pcall(function()
                        track:Stop(0)
                        track:AdjustSpeed(0)
                    end)
                end
            end
        end)
        
        -- Connect Stepped ONLY when enabled
        SkinAnimation.Connections.Stepped = RunService.Stepped:Connect(function()
            if not IsEnabled then return end
            
            for track, _ in pairs(killedTracks) do
                if track and track.IsPlaying then
                    pcall(function()
                        track:Stop(0)
                        track:AdjustSpeed(0)
                    end)
                end
            end
        end)
        
        return true
    end
    
    return false
end

function SkinAnimation.Disable()
    if not IsEnabled then
        return false
    end
    
    IsEnabled = false
    killedTracks = {}
    replaceCount = 0
    
    -- Disconnect ALL connections to prevent lag when disabled
    for name, conn in pairs(SkinAnimation.Connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    SkinAnimation.Connections = {}
    
    for _, track in ipairs(AnimationPool) do
        pcall(function()
            track:Stop(0)
        end)
    end
    
    return true
end

function SkinAnimation.IsEnabled()
    return IsEnabled
end

function SkinAnimation.GetCurrentSkin()
    return CurrentSkin
end

function SkinAnimation.GetReplaceCount()
    return replaceCount
end

return SkinAnimation
end)()

-- Module NotificationModule
CombinedModules.NotificationModule = (function()
local Notification = {}

function Notification.Send(title, text, duration)
    duration = duration or 4
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration
        })
    end)
end

return Notification
end)()

CombinedModules.StableResult = (function()
    -- 🔗 Menggunakan shared services (Players, ReplicatedStorage, LocalPlayer sudah didefinisikan di atas)
    
    local StableResult = {}

    StableResult.Enabled = false

    local RF_UpdateAutoFishingMiniGame = nil

    local function InitializeRemote()
        if RF_UpdateAutoFishingMiniGame then return true end
        
        local success = pcall(function()
            local Net = ReplicatedStorage:WaitForChild("Packages", 3)
                :WaitForChild("_Index", 3)
                :WaitForChild("sleitnick_net@0.2.0", 3)
                :WaitForChild("net", 3)
            
            RF_UpdateAutoFishingMiniGame = Net:WaitForChild("RF/UpdateAutoFishingState", 3)
        end)
        
        return success and RF_UpdateAutoFishingMiniGame ~= nil
    end
    
    function StableResult.Start()
        if StableResult.Enabled then
            return false
        end
        
        if not InitializeRemote() then
            return false
        end
        
        StableResult.Enabled = true

        local success = pcall(function()
            RF_UpdateAutoFishingMiniGame:InvokeServer(true)
        end)
        
        if not success then
            StableResult.Enabled = false
            return false
        end

        pcall(function()
            LocalPlayer:SetAttribute("Loading", nil)
        end)
        
        return true
    end
    
    function StableResult.Stop()
        if not StableResult.Enabled then
            return false
        end
        
        StableResult.Enabled = false

        if RF_UpdateAutoFishingMiniGame then
            pcall(function()
                RF_UpdateAutoFishingMiniGame:InvokeServer(false)
            end)
        end

        pcall(function()
            LocalPlayer:SetAttribute("Loading", false)
        end)
        
        return true
    end
    
    function StableResult.IsEnabled()
        return StableResult.Enabled
    end
    
    return StableResult
end)()

CombinedModules.MerchantSystem = (function()


    -- 🔗 Using shared services
    local LocalPlayer = localPlayer
    local PlayerGui = localPlayer:WaitForChild("PlayerGui", 5)

local MerchantUI = nil
pcall(function()
    MerchantUI = PlayerGui:FindFirstChild("Merchant") or PlayerGui:WaitForChild("Merchant", 3)
end)

local function OpenMerchant()
    if MerchantUI then
        MerchantUI.Enabled = true
    end
end

local function CloseMerchant()
    if MerchantUI then
        MerchantUI.Enabled = false
    end
end

return {
    Open = OpenMerchant,
    Close = CloseMerchant
}
end)()

CombinedModules.Auto9xTotem = (function()

    local Auto9xTotem = {}

    -- 🔗 Using shared services

    local SpawnTotemRemote = nil
    local clientData = nil
    local RF_EquipOxygenTank = nil
    local RF_UnequipOxygenTank = nil
    
    local function InitializeRemotes()
        local success = pcall(function()
            local Net = ReplicatedStorage:WaitForChild("Packages", 5)
                :WaitForChild("_Index", 5)
                :WaitForChild("sleitnick_net@0.2.0", 5)
                :WaitForChild("net", 5)
            SpawnTotemRemote = Net:WaitForChild("RE/SpawnTotem", 5)
            
            local Replion = require(ReplicatedStorage:WaitForChild("Packages", 5):WaitForChild("Replion", 5))
            clientData = Replion.Client:WaitReplion("Data")
            
            local Net = ReplicatedStorage:WaitForChild("Packages", 5)
                :WaitForChild("_Index", 5)
                :WaitForChild("sleitnick_net@0.2.0", 5)
                :WaitForChild("net", 5)

            RF_EquipOxygenTank = Net:WaitForChild("RF/EquipOxygenTank", 5)
            RF_UnequipOxygenTank = Net:WaitForChild("RF/UnequipOxygenTank", 5)
        end)
        
        return success
    end

    local TOTEM_DATA = {
        ["Luck Totem"] = {Id = 1, Duration = 3601}, 
        ["Mutation Totem"] = {Id = 2, Duration = 3601}, 
        ["Shiny Totem"] = {Id = 3, Duration = 3601}
    }
    
    local TOTEM_NAMES = {"Luck Totem", "Mutation Totem", "Shiny Totem"}

    Auto9xTotem.Settings = {
        SelectedTotem = "Luck Totem",
        IsRunning = false
    }
    
    local AUTO_9_TOTEM_THREAD = nil
    local stateConnection = nil
    local holdConnection = nil

    local REF_CENTER = Vector3.new(93.932, 9.532, 2684.134)
    local REF_SPOTS = {
        -- TENGAH (Y ~ 9.5)
        Vector3.new(45.0468979, 9.51625347, 2730.19067),
        Vector3.new(145.644608, 9.51625347, 2721.90747),
        Vector3.new(84.6406631, 10.2174253, 2636.05786),
        -- ATAS (Y ~ 109.5)
        Vector3.new(45.0468979, 110.516253, 2730.19067),
        Vector3.new(145.644608, 110.516253, 2721.90747),
        Vector3.new(84.6406631, 111.217425, 2636.05786),
        -- BAWAH (Y ~ -90.5)
        Vector3.new(45.0468979, -92.483747, 2730.19067),
        Vector3.new(145.644608, -92.483747, 2721.90747),
        Vector3.new(84.6406631, -93.782575, 2636.05786),
    }

    
    local function GetTotemUUIDsByName(totemName)
        if not clientData then return {} end
        
        local success, inv = pcall(function()
            return clientData:Get("Inventory")
        end)
        
        if not success or not inv or not inv.Totems then
            return {}
        end
        
        local targetId = TOTEM_DATA[totemName] and TOTEM_DATA[totemName].Id
        if not targetId then return {} end
        
        local list = {}
        for _, item in pairs(inv.Totems) do
            if item and item.UUID and tonumber(item.Id) == targetId then
                if (item.Count or 1) >= 1 then
                    table.insert(list, item.UUID)
                end
            end
        end
        
        return list
    end
    
    local function GetFlyPart()
        local char = Players.LocalPlayer.Character
        if not char then return nil end
        return char:FindFirstChild("HumanoidRootPart") or 
               char:FindFirstChild("Torso") or 
               char:FindFirstChild("UpperTorso")
    end

    local function MaintainAntiFallState(enable)
        local char = Players.LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if not hum then return end
        
        if enable then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Running, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
            end)
            
            if not stateConnection then
                stateConnection = RunService.Heartbeat:Connect(function()
                    if hum and hum.Parent and Auto9xTotem.Settings.IsRunning then
                        pcall(function()
                            hum:ChangeState(Enum.HumanoidStateType.Swimming)
                            hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                        end)
                    end
                end)
            end
        else
            if stateConnection then 
                stateConnection:Disconnect()
                stateConnection = nil 
            end
            
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
                hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
            end)
        end
    end
    
    local function EnableV3Physics()
        local char = Players.LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local mainPart = GetFlyPart()
        
        if not mainPart or not hum then return end
        
        pcall(function()
            if char:FindFirstChild("Animate") then 
                char.Animate.Disabled = true 
            end
        end)
        hum.PlatformStand = true 
        
        MaintainAntiFallState(true)
        
        local bg = mainPart:FindFirstChild("FlyGuiGyro") or Instance.new("BodyGyro", mainPart)
        bg.Name = "FlyGuiGyro"
        bg.P = 9e4 
        bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.CFrame = mainPart.CFrame
        
        local bv = mainPart:FindFirstChild("FlyGuiVelocity") or Instance.new("BodyVelocity", mainPart)
        bv.Name = "FlyGuiVelocity"
        bv.velocity = Vector3.new(0, 0.1, 0)
        bv.maxForce = Vector3.new(9e9, 9e9, 9e9)
        
        -- Disable collisions
        task.spawn(function()
            while Auto9xTotem.Settings.IsRunning and char do
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then 
                        part.CanCollide = false 
                    end
                end
                task.wait(0.1)
            end
        end)
        
        -- Maintain health
        task.spawn(function()
            while Auto9xTotem.Settings.IsRunning and hum do
                hum.Health = hum.MaxHealth
                task.wait(1)
            end
        end)
    end

    local function DisableV3Physics()
        local char = Players.LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local mainPart = GetFlyPart()
        
        if mainPart then
            pcall(function()
                if mainPart:FindFirstChild("FlyGuiGyro") then 
                    mainPart.FlyGuiGyro:Destroy() 
                end
                if mainPart:FindFirstChild("FlyGuiVelocity") then 
                    mainPart.FlyGuiVelocity:Destroy() 
                end
                
                mainPart.Velocity = Vector3.zero
                mainPart.RotVelocity = Vector3.zero
                mainPart.AssemblyLinearVelocity = Vector3.zero 
                mainPart.AssemblyAngularVelocity = Vector3.zero
                
                local x, y, z = mainPart.CFrame:ToEulerAnglesYXZ()
                mainPart.CFrame = CFrame.new(mainPart.Position) * CFrame.fromEulerAnglesYXZ(0, y, 0)
            end)
        end
        
        if hum then 
            hum.PlatformStand = false 
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
        
        MaintainAntiFallState(false) 
        
        pcall(function()
            if char and char:FindFirstChild("Animate") then 
                char.Animate.Disabled = false 
            end
        end)
        
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then 
                    part.CanCollide = true 
                end
            end
        end
    end

    local function HoldPosition(targetCFrame)
        local mainPart = GetFlyPart()
        if not mainPart then return end
        
        if holdConnection then
            holdConnection:Disconnect()
            holdConnection = nil
        end
        
        holdConnection = RunService.Heartbeat:Connect(function()
            if mainPart and mainPart.Parent then
                mainPart.CFrame = targetCFrame
                mainPart.Velocity = Vector3.new(0, 0, 0)
                mainPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end)
    end
    
    local function StopHold()
        if holdConnection then
            holdConnection:Disconnect()
            holdConnection = nil
        end
    end

    local function FlyPhysicsTo(targetPos)
        local mainPart = GetFlyPart()
        if not mainPart then return end
        
        local bv = mainPart:FindFirstChild("FlyGuiVelocity")
        local bg = mainPart:FindFirstChild("FlyGuiGyro")
        
        if not bv or not bg then 
            EnableV3Physics()
            bv = mainPart:FindFirstChild("FlyGuiVelocity")
            bg = mainPart:FindFirstChild("FlyGuiGyro")
        end
        
        if not bv or not bg then return end
        
        local SPEED = 80 
        
        while Auto9xTotem.Settings.IsRunning do
            local currentPos = mainPart.Position
            local diff = targetPos - currentPos
            local dist = diff.Magnitude
            
            bg.CFrame = CFrame.lookAt(currentPos, targetPos)
            
            if dist < 1.0 then 
                bv.velocity = Vector3.new(0, 0.1, 0)
                break
            else
                bv.velocity = diff.Unit * SPEED
            end
            RunService.Heartbeat:Wait()
        end
    end

    local function Run9TotemLoop()
        if AUTO_9_TOTEM_THREAD then 
            pcall(function() task.cancel(AUTO_9_TOTEM_THREAD) end)
        end
        
        AUTO_9_TOTEM_THREAD = task.spawn(function()
            local selectedTotemName = Auto9xTotem.Settings.SelectedTotem
            
            -- GET TOTEM UUIDs
            local totemUUIDs = GetTotemUUIDsByName(selectedTotemName)
            if #totemUUIDs < 9 then 
                warn(string.format("[Auto9xTotem] Need 9x %s! Found: %d", selectedTotemName, #totemUUIDs))
                Auto9xTotem.Settings.IsRunning = false
                return 
            end
            
            local char = Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            
            if not hrp then 
                Auto9xTotem.Settings.IsRunning = false
                return 
            end
            
            local startPosition = hrp.CFrame
            
            -- Equip oxygen tank
            if RF_EquipOxygenTank then
                pcall(function() 
                    local args = {180}
                    RE_UpdateHealth:FireServer(unpack(args))
                end)
            end
            
            -- Full health
            if hum then hum.Health = hum.MaxHealth end
            
            EnableV3Physics()
            task.wait(0.5)
            
            -- Loop through all 9 spots
            for i, refSpot in ipairs(REF_SPOTS) do
                if not Auto9xTotem.Settings.IsRunning then break end
                
                local relativePos = refSpot - REF_CENTER
                local targetPos = startPosition.Position + relativePos
                local targetCFrame = CFrame.new(targetPos)
                
                FlyPhysicsTo(targetPos) 
                HoldPosition(targetCFrame)
                task.wait(1.5)
                
                local uuid = totemUUIDs[i]
                if uuid and SpawnTotemRemote then
                    pcall(function() SpawnTotemRemote:FireServer(uuid) end)
                    task.wait(2.5)
                end
                
                StopHold()
                task.wait(0.3)
            end
            
            -- Return to start
            if Auto9xTotem.Settings.IsRunning then
                FlyPhysicsTo(startPosition.Position)
                HoldPosition(startPosition)
                task.wait(1)
            end
            
            -- Cleanup
            StopHold()
            
           if RF_UnequipOxygenTank then
                pcall(function() 
                    RF_UnequipOxygenTank:InvokeServer()
                end)
            end
            
            DisableV3Physics() 
            Auto9xTotem.Settings.IsRunning = false
        end)
    end
    
    function Auto9xTotem.SetTotem(totemName)
        if TOTEM_DATA[totemName] then
            Auto9xTotem.Settings.SelectedTotem = totemName
            return true
        end
        return false
    end
    
    function Auto9xTotem.GetTotemNames()
        return TOTEM_NAMES
    end
    
    function Auto9xTotem.Start()
        if Auto9xTotem.Settings.IsRunning then return false end
        
        -- Initialize remotes if not done
        if not SpawnTotemRemote then
            if not InitializeRemotes() then
                warn("[Auto9xTotem] Failed to initialize remotes")
                return false
            end
        end
        
        Auto9xTotem.Settings.IsRunning = true
        Run9TotemLoop()
        return true
    end
    
    function Auto9xTotem.Stop()
        if not Auto9xTotem.Settings.IsRunning then return false end
        
        Auto9xTotem.Settings.IsRunning = false
        
        if AUTO_9_TOTEM_THREAD then
            pcall(function() task.cancel(AUTO_9_TOTEM_THREAD) end)
        end
        
        DisableV3Physics()
        StopHold()
        
        return true
    end
    
    function Auto9xTotem.IsRunning()
        return Auto9xTotem.Settings.IsRunning
    end
    
    function Auto9xTotem.GetCurrentTotem()
        return Auto9xTotem.Settings.SelectedTotem
    end

    task.spawn(function()
        task.wait(1)
        InitializeRemotes()
    end)
    
    return Auto9xTotem

end)()

-- Anti Staff Module
CombinedModules.AntiStaff = (function()
    -- 🔗 Menggunakan shared services (Players, localPlayer sudah didefinisikan di atas)
    
    local AntiStaff = {}
    AntiStaff.Active = false
    
    local GROUP_ID = 35102746
    local STAFF_RANKS = {
        [2] = "OG",
        [3] = "Tester",
        [4] = "Moderator",
        [75] = "Community Staff",
        [79] = "Analytics",
        [145] = "Divers / Artist",
        [250] = "Devs",
        [252] = "Partner",
        [254] = "Talon",
        [255] = "Wildes",
        [55] = "Swimmer",
        [30] = "Contrib",
        [35] = "Contrib 2",
        [100] = "Scuba",
        [76] = "CC"
    }
    
    local function checkPlayers()
        while AntiStaff.Active do
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer then
                    local rank = player:GetRankInGroup(GROUP_ID)
                    if STAFF_RANKS[rank] then
                        localPlayer:Kick("Staff Detected! Auto Kicked for Safety.")
                        return
                    end
                end
            end
            task.wait(1)
        end
    end
    
    function AntiStaff.Start()
        if AntiStaff.Active then
            return
        end
        
        AntiStaff.Active = true
        task.spawn(checkPlayers)
    end
    
    function AntiStaff.Stop()
        AntiStaff.Active = false
    end
    
    return AntiStaff
end)()

CombinedModules.AutoEquipRod = (function()
    local AutoEquipRod = {}

    -- 🔗 Menggunakan shared services (Players, ReplicatedStorage sudah didefinisikan di atas)
    local v0 = {
        Players = Players,
        RS = ReplicatedStorage
    }

    -- localPlayer sudah didefinisikan di shared definitions

    -- Wrap dalam pcall untuk cek kompatibilitas
    local success, v5 = pcall(function()
        return {
            Net = v0.RS.Packages._Index["sleitnick_net@0.2.0"].net,
            PlayerStatsUtility = require(v0.RS.Shared.PlayerStatsUtility),
            ItemUtility = require(v0.RS.Shared.ItemUtility)
        }
    end)

    if not success then
        -- Return module kosong jika tidak support
        AutoEquipRod.isSupported = false
        AutoEquipRod.Start = function() end
        AutoEquipRod.Stop = function() end
        return AutoEquipRod
    end

    local v6Success, v6 = pcall(function()
        return {
            Events = {
                REEquip = v5.Net["RE/EquipToolFromHotbar"]
            }
        }
    end)

    if not v6Success then
        AutoEquipRod.isSupported = false
        AutoEquipRod.Start = function() end
        AutoEquipRod.Stop = function() end
        return AutoEquipRod
    end

    local v7Success, v7 = pcall(function()
        return {
            Data = require(v0.RS.Packages.Replion).Client:WaitReplion("Data")
        }
    end)

    if not v7Success then
        AutoEquipRod.isSupported = false
        AutoEquipRod.Start = function() end
        AutoEquipRod.Stop = function() end
        return AutoEquipRod
    end

    -- Tandai bahwa module ini support
    AutoEquipRod.isSupported = true

    local v8 = {
        autoEquipRod = false,
        loopConnection = nil
    }

    -- Functions
    local function isRodEquipped()
        local success, result = pcall(function()
            local v217 = v7.Data:Get("EquippedId")
            if not v217 then
                return false
            end
            
            local equippedItem = v5.PlayerStatsUtility:GetItemFromInventory(v7.Data, function(v218)
                return v218.UUID == v217
            end)
            
            if not equippedItem then
                return false
            end
            
            local itemData = v5.ItemUtility:GetItemData(equippedItem.Id)
            return itemData and itemData.Data.Type == "Fishing Rods"
        end)
        
        return success and result or false
    end

    local function equipRod()
        pcall(function()
            if not isRodEquipped() then
                v6.Events.REEquip:FireServer(1)
            end
        end)
    end

    -- Start Function
    function AutoEquipRod.Start()
        v8.autoEquipRod = true
        
        if v8.loopConnection then
            v8.loopConnection:Disconnect()
        end
        
        v8.loopConnection = task.spawn(function()
            while v8.autoEquipRod do
                equipRod()
                task.wait(1)
            end
        end)
    end

    -- Stop Function
    function AutoEquipRod.Stop()
        v8.autoEquipRod = false
        
        if v8.loopConnection then
            task.cancel(v8.loopConnection)
            v8.loopConnection = nil
        end
    end

    return AutoEquipRod
end)()   

CombinedModules.AutoSpawnTotem = (function()

    local AutoSpawnTotem = {}

    -- Services
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")

    -- Remote & Data
    local SpawnTotemRemote = nil
    local clientData = nil
    
    local function InitializeRemotes()
        local success = pcall(function()
            local Net = ReplicatedStorage:WaitForChild("Packages", 5)
                :WaitForChild("_Index", 5)
                :WaitForChild("sleitnick_net@0.2.0", 5)
                :WaitForChild("net", 5)
            SpawnTotemRemote = Net:WaitForChild("RE/SpawnTotem", 5)
            
            local Replion = require(ReplicatedStorage:WaitForChild("Packages", 5):WaitForChild("Replion", 5))
            clientData = Replion.Client:WaitReplion("Data")
        end)
        
        return success
    end

    local TOTEM_DATA = {
        ["Luck Totem"] = {Id = 1, Duration = 3600}, 
        ["Mutation Totem"] = {Id = 2, Duration = 3600}, 
        ["Shiny Totem"] = {Id = 3, Duration = 3600}
    }
    
    local TOTEM_NAMES = {"Luck Totem", "Mutation Totem", "Shiny Totem"}

    AutoSpawnTotem.Settings = {
        SelectedTotem = "Luck Totem",
        IsRunning = false,
        SpawnInterval = 3605 -- 60 minutes 5 seconds (5 seconds after expiry)
    }
    
    local AUTO_SPAWN_THREAD = nil

    -- Function to get ONE totem UUID by name
    local function GetTotemUUIDByName(totemName)
        if not clientData then return nil end
        
        local success, inv = pcall(function()
            return clientData:Get("Inventory")
        end)
        
        if not success or not inv or not inv.Totems then
            return nil
        end
        
        local targetId = TOTEM_DATA[totemName] and TOTEM_DATA[totemName].Id
        if not targetId then return nil end
        
        -- Find first available totem with count >= 1
        for _, item in pairs(inv.Totems) do
            if item and item.UUID and tonumber(item.Id) == targetId then
                if (item.Count or 1) >= 1 then
                    return item.UUID
                end
            end
        end
        
        return nil
    end

    -- Function to spawn totem
    local function SpawnSingleTotem()
        local selectedTotemName = AutoSpawnTotem.Settings.SelectedTotem
        
        -- Get one totem UUID
        local totemUUID = GetTotemUUIDByName(selectedTotemName)
        
        if not totemUUID then 
            warn(string.format("[AutoSpawnTotem] No %s available in inventory!", selectedTotemName))
            return false
        end
        
        if not SpawnTotemRemote then
            warn("[AutoSpawnTotem] SpawnTotemRemote not initialized!")
            return false
        end
        
        -- Spawn the totem
        local success = pcall(function()
            SpawnTotemRemote:FireServer(totemUUID)
        end)
        
        if success then
            print(string.format("[AutoSpawnTotem] ✓ Spawned %s", selectedTotemName))
            return true
        else
            warn(string.format("[AutoSpawnTotem] Failed to spawn %s", selectedTotemName))
            return false
        end
    end

    -- Main loop function
    local function RunAutoSpawnLoop()
        if AUTO_SPAWN_THREAD then 
            pcall(function() task.cancel(AUTO_SPAWN_THREAD) end)
        end
        
        AUTO_SPAWN_THREAD = task.spawn(function()
            print("[AutoSpawnTotem] Started! Spawning every ~60m 5s...")
            
            -- Spawn immediately on start
            SpawnSingleTotem()
            
            -- Then spawn every 60m 5s (5 seconds after previous totem expires)
            while AutoSpawnTotem.Settings.IsRunning do
                task.wait(AutoSpawnTotem.Settings.SpawnInterval)
                
                if AutoSpawnTotem.Settings.IsRunning then
                    SpawnSingleTotem()
                end
            end
        end)
    end
    
    -- Public Functions
    function AutoSpawnTotem.SetTotem(totemName)
        if TOTEM_DATA[totemName] then
            AutoSpawnTotem.Settings.SelectedTotem = totemName
            print(string.format("[AutoSpawnTotem] Selected: %s", totemName))
            return true
        end
        return false
    end
    
    function AutoSpawnTotem.GetTotemNames()
        return TOTEM_NAMES
    end
    
    function AutoSpawnTotem.Start()
        if AutoSpawnTotem.Settings.IsRunning then 
            warn("[AutoSpawnTotem] Already running!")
            return false 
        end
        
        -- Initialize remotes if not done
        if not SpawnTotemRemote then
            if not InitializeRemotes() then
                warn("[AutoSpawnTotem] Failed to initialize remotes")
                return false
            end
        end
        
        AutoSpawnTotem.Settings.IsRunning = true
        RunAutoSpawnLoop()
        return true
    end
    
    function AutoSpawnTotem.Stop()
        if not AutoSpawnTotem.Settings.IsRunning then 
            warn("[AutoSpawnTotem] Not running!")
            return false 
        end
        
        AutoSpawnTotem.Settings.IsRunning = false
        
        if AUTO_SPAWN_THREAD then
            pcall(function() task.cancel(AUTO_SPAWN_THREAD) end)
            AUTO_SPAWN_THREAD = nil
        end
        
        print("[AutoSpawnTotem] Stopped!")
        return true
    end
    
    function AutoSpawnTotem.IsRunning()
        return AutoSpawnTotem.Settings.IsRunning
    end
    
    function AutoSpawnTotem.GetCurrentTotem()
        return AutoSpawnTotem.Settings.SelectedTotem
    end
    
    function AutoSpawnTotem.SetInterval(seconds)
        if seconds and seconds > 0 then
            AutoSpawnTotem.Settings.SpawnInterval = seconds
            print(string.format("[AutoSpawnTotem] Interval set to %d seconds", seconds))
            return true
        end
        return false
    end
    
    function AutoSpawnTotem.GetInterval()
        return AutoSpawnTotem.Settings.SpawnInterval
    end
    
    function AutoSpawnTotem.SpawnNow()
        if not AutoSpawnTotem.Settings.IsRunning then
            warn("[AutoSpawnTotem] Not running! Start the module first.")
            return false
        end
        return SpawnSingleTotem()
    end

    -- Auto-initialize remotes on load
    task.spawn(function()
        task.wait(1)
        InitializeRemotes()
    end)
    
    return AutoSpawnTotem

end)()


-- ═══════════════════════════════════════════════════════════════════════════
-- GUI BUILDER - Menggunakan Library Lynx (Complete Edition)
-- ═══════════════════════════════════════════════════════════════════════════
CombinedModules.BuildGUI = function(Lynx)
    if not Lynx then
        warn("[Lynx GUI] Library Lynx tidak ditemukan!")
        return nil
    end

    local Window = Lynx:Window({
        Title = "Lynx v2.5",
        Footer = "| Free Not For Sale",
        Color = Color3.fromRGB(255, 140, 0),
        ["Tab Width"] = 130,
        Version = 1,
        Image = "118176705805619"  -- Logo minimize dari ContohGui.lua
    })

    -- State variables
    local fishingDelayValue = 1.30
    local cancelDelayValue = 0.19
    local currentInstantMode = "Fast"
    local isInstantFishingEnabled = false

    -- ══════════════════════════════════════════
    -- TAB: MAIN DASHBOARD (Auto Fishing)
    -- ══════════════════════════════════════════
    local MainTab = Window:AddTab({Name = "Dashboard", Icon = "home"})

     -- Section: Support Features
    local SupportSection = MainTab:AddSection("Support Features", false)
    
    SupportSection:AddToggle({
        Title = "No Fishing Animation",
        Default = false,
        Callback = function(on)
            if CombinedModules.NoFishingAnimation then
                if on then CombinedModules.NoFishingAnimation.StartWithDelay() else CombinedModules.NoFishingAnimation.Stop() end
            end
        end
    })

    -- GUI Toggle dengan cek kompatibilitas
    SupportSection:AddToggle({
        Title = "Auto Equip Rod" .. (CombinedModules.AutoEquipRod.isSupported and "" or " (Not Supported)"),
        Default = false,
        Callback = function(on)
            if CombinedModules.AutoEquipRod and CombinedModules.AutoEquipRod.isSupported then
                if on then 
                    CombinedModules.AutoEquipRod.Start() 
                else 
                    CombinedModules.AutoEquipRod.Stop() 
                end
            elseif on then
                -- Optional: Berikan notifikasi ke user
                warn("Auto Equip Rod tidak support di executor ini")
            end
        end
    })
    
    SupportSection:AddToggle({
        Title = "Lock Position",
        Default = false,
        Callback = function(on)
            if CombinedModules.LockPosition then
                if on then CombinedModules.LockPosition.Start() else CombinedModules.LockPosition.Stop() end
            end
        end
    })
    
    SupportSection:AddToggle({
        Title = "Disable Cutscenes",
        Default = false,
        Callback = function(on)
            if CombinedModules.DisableCutscenes then
                if on then 
                    CombinedModules.DisableCutscenes.Start()
                else 
                    CombinedModules.DisableCutscenes.Stop()
                end
            end
        end
    })
        
    SupportSection:AddToggle({
        Title = "Show Real Ping Panel",
        Default = false,
        Callback = function(on)
            if CombinedModules.PingPanel then
                if on then CombinedModules.PingPanel:Show() else CombinedModules.PingPanel:Hide() end
            end
        end
    })
    
    SupportSection:AddToggle({
        Title = "Disable Obtained Fish Notification",
        Default = false,
        Callback = function(on)
            if CombinedModules.DisableExtras then
                if on then CombinedModules.DisableExtras.StartSmallNotification() else CombinedModules.DisableExtras.StopSmallNotification() end
            end
        end
    })
    
    SupportSection:AddToggle({
        Title = "Disable Skin Effect",
        Default = false,
        Callback = function(on)
            if CombinedModules.DisableExtras then
                if on then CombinedModules.DisableExtras.StartSkinEffect() else CombinedModules.DisableExtras.StopSkinEffect() end
            end
        end
    })
    
    SupportSection:AddToggle({
        Title = "Walk On Water",
        Default = false,
        Callback = function(on)
            if CombinedModules.WalkOnWater then
                if on then CombinedModules.WalkOnWater.Start() else CombinedModules.WalkOnWater.Stop() end
            end
        end
    })
    
    -- Section: Auto Fishing
    local AutoFishingSection = MainTab:AddSection("Auto Fishing")
    
    AutoFishingSection:AddDropdown({
        Title = "Instant Fishing Mode",
        Options = {"Fast", "Perfect"},
        Default = "Fast",
        Callback = function(mode)
            currentInstantMode = mode
            if CombinedModules.instant then CombinedModules.instant.Stop() end
            if CombinedModules.instant2 then CombinedModules.instant2.Stop() end
            if isInstantFishingEnabled then
                if mode == "Fast" and CombinedModules.instant then
                    CombinedModules.instant.Settings.MaxWaitTime = fishingDelayValue
                    CombinedModules.instant.Settings.CancelDelay = cancelDelayValue
                    CombinedModules.instant.Start()
                elseif mode == "Perfect" and CombinedModules.instant2 then
                    CombinedModules.instant2.Settings.MaxWaitTime = fishingDelayValue
                    CombinedModules.instant2.Settings.CancelDelay = cancelDelayValue
                    CombinedModules.instant2.Start()
                end
            end
        end
    })
    
    AutoFishingSection:AddToggle({
        Title = "Enable Instant Fishing",
        Default = false,
        Callback = function(on)
            isInstantFishingEnabled = on
            if on then
                if currentInstantMode == "Fast" and CombinedModules.instant then
                    CombinedModules.instant.Start()
                elseif currentInstantMode == "Perfect" and CombinedModules.instant2 then
                    CombinedModules.instant2.Start()
                end
            else
                if CombinedModules.instant then CombinedModules.instant.Stop() end
                if CombinedModules.instant2 then CombinedModules.instant2.Stop() end
            end
        end
    })
    
    AutoFishingSection:AddInput({
        Title = "Fishing Delay",
        Default = "1.30",
        Callback = function(value)
            local v = tonumber(value)
            if v then
                fishingDelayValue = v
                if CombinedModules.instant then CombinedModules.instant.Settings.MaxWaitTime = v end
                if CombinedModules.instant2 then CombinedModules.instant2.Settings.MaxWaitTime = v end
            end
        end
    })
    
    AutoFishingSection:AddInput({
        Title = "Cancel Delay",
        Default = "0.19",
        Callback = function(value)
            local v = tonumber(value)
            if v then
                cancelDelayValue = v
                if CombinedModules.instant then CombinedModules.instant.Settings.CancelDelay = v end
                if CombinedModules.instant2 then CombinedModules.instant2.Settings.CancelDelay = v end
            end
        end
    })

    -- Section: Stable Result
    local StableSection = MainTab:AddSection("Stable Result", false)
    StableSection:AddToggle({
        Title = "Enable Auto Good/Perfection",
        Default = false,
        Callback = function(on)
            if CombinedModules.StableResult then
                if on then CombinedModules.StableResult.Start() else CombinedModules.StableResult.Stop() end
            end
        end
    })

    -- Section: Blatant BETA
    local BlatantBETASection = MainTab:AddSection("Blatant BETA Version", false)
    BlatantBETASection:AddToggle({
        Title = "Enable Blatant BETA",
        Default = false,
        Callback = function(on)
            if CombinedModules.blatantBETA then
                if on then CombinedModules.blatantBETA.Start() else CombinedModules.blatantBETA.Stop() end
            end
        end
    })
    BlatantBETASection:AddInput({
        Title = "Beta Complete Delay",
        Default = "0.001",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.blatantBETA and CombinedModules.blatantBETA.UpdateSettings then
                CombinedModules.blatantBETA.UpdateSettings(v, nil)
            end
        end
    })
    BlatantBETASection:AddInput({
        Title = "Beta Cancel Delay",
        Default = "0.001",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.blatantBETA and CombinedModules.blatantBETA.UpdateSettings then
                CombinedModules.blatantBETA.UpdateSettings(nil, v)
            end
        end
    })

    -- Section: Blatant V1
    local BlatantV1Section = MainTab:AddSection("Blatant V1", false)
    BlatantV1Section:AddToggle({
        Title = "Enable Blatant V1",
        Default = false,
        Callback = function(on)
            if CombinedModules.blatantv1 then
                if on then CombinedModules.blatantv1.Start() else CombinedModules.blatantv1.Stop() end
            end
        end
    })
    BlatantV1Section:AddInput({
        Title = "V1 Complete Delay",
        Default = "0.05",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.blatantv1 then CombinedModules.blatantv1.Settings.CompleteDelay = v end
        end
    })
    BlatantV1Section:AddInput({
        Title = "V1 Cancel Delay",
        Default = "0.1",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.blatantv1 then CombinedModules.blatantv1.Settings.CancelDelay = v end
        end
    })

    -- Section: Ultra Blatant (V2)
    local UltraBlatantSection = MainTab:AddSection("Blatant V2", false)
    UltraBlatantSection:AddToggle({
        Title = "Enable Ultra Blatant",
        Default = false,
        Callback = function(on)
            if CombinedModules.UltraBlatant then
                if on then CombinedModules.UltraBlatant.Start() else CombinedModules.UltraBlatant.Stop() end
            end
        end
    })
    UltraBlatantSection:AddInput({
        Title = "V2 Complete Delay",
        Default = "0.05",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.UltraBlatant and CombinedModules.UltraBlatant.UpdateSettings then
                CombinedModules.UltraBlatant.UpdateSettings(v, nil, nil)
            end
        end
    })
    UltraBlatantSection:AddInput({
        Title = "V2 Cancel Delay",
        Default = "0.1",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.UltraBlatant and CombinedModules.UltraBlatant.UpdateSettings then
                CombinedModules.UltraBlatant.UpdateSettings(nil, v, nil)
            end
        end
    })

    -- Section: Blatant V3
    local BlatantV3Section = MainTab:AddSection("Blatant V3", false)
    BlatantV3Section:AddToggle({
        Title = "Blatant Tester",
        Default = false,
        Callback = function(on)
            if CombinedModules.BlatantFixedV1 then
                if on then CombinedModules.BlatantFixedV1.Start() else CombinedModules.BlatantFixedV1.Stop() end
            end
        end
    })
    BlatantV3Section:AddInput({
        Title = "V3 Complete Delay",
        Default = "0.5",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.BlatantFixedV1 then CombinedModules.BlatantFixedV1.Settings.CompleteDelay = v end
        end
    })
    BlatantV3Section:AddInput({
        Title = "V3 Cancel Delay",
        Default = "0.1",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.BlatantFixedV1 then CombinedModules.BlatantFixedV1.Settings.CancelDelay = v end
        end
    })

    -- Section: Skin Animation
    local SkinSection = MainTab:AddSection("Skin Animation", false)
    
    local skinNames = {"Eclipse Katana", "Holy Trident", "Soul Scythe", "Oceanic Harpoon", "Binary Edge", "The Vanquisher", "Frozen Krampus Scythe", "1x1x1x1 Ban Hammer", "Corruption Edge", "Princess Parasol"}
    local skinInfo = {
        ["Eclipse Katana"] = "Eclipse",
        ["Holy Trident"] = "HolyTrident",
        ["Soul Scythe"] = "SoulScythe",
        ["Oceanic Harpoon"] = "OceanicHarpoon",
        ["Binary Edge"] = "BinaryEdge",
        ["The Vanquisher"] = "Vanquisher",
        ["Frozen Krampus Scythe"] = "KrampusScythe",
        ["1x1x1x1 Ban Hammer"] = "BanHammer",
        ["Corruption Edge"] = "CorruptionEdge",
        ["Princess Parasol"] = "PrincessParasol"
    }
    local selectedSkin = nil
    local skinAnimEnabled = false
    
    SkinSection:AddDropdown({
        Title = "Select Skin",
        Options = skinNames,
        Default = "Eclipse Katana",
        Callback = function(selected)
            selectedSkin = selected
            if skinAnimEnabled and CombinedModules.SkinSwapAnimation and skinInfo[selected] then
                CombinedModules.SkinSwapAnimation.SwitchSkin(skinInfo[selected])
            end
        end
    })
    
    SkinSection:AddToggle({
        Title = "Enable Skin Animation",
        Default = false,
        Callback = function(on)
            skinAnimEnabled = on
            if CombinedModules.SkinSwapAnimation then
                if on and selectedSkin and skinInfo[selectedSkin] then
                    CombinedModules.SkinSwapAnimation.SwitchSkin(skinInfo[selectedSkin])
                    CombinedModules.SkinSwapAnimation.Enable()
                else
                    CombinedModules.SkinSwapAnimation.Disable()
                end
            end
        end
    })
    local TotemSection = MainTab:AddSection("Auto Totem", false)
    
    TotemSection:AddButton({
        Title = "Auto Totem 3X",
        Callback = function()
            if CombinedModules.AutoTotem3X then
                if CombinedModules.AutoTotem3X.IsRunning() then
                    CombinedModules.AutoTotem3X.Stop()
                else
                    CombinedModules.AutoTotem3X.Start()
                end
            end
        end
    })
    
    if CombinedModules.Auto9xTotem then
        TotemSection:AddDropdown({
        Title = "9x Totem Type",
            Options = CombinedModules.Auto9xTotem.GetTotemNames and CombinedModules.Auto9xTotem.GetTotemNames() or {"Luck Totem"},
            Default = CombinedModules.Auto9xTotem.GetCurrentTotem and CombinedModules.Auto9xTotem.GetCurrentTotem() or "Luck Totem",
            Callback = function(selected)
                if CombinedModules.Auto9xTotem.SetTotem then
                    CombinedModules.Auto9xTotem.SetTotem(selected)
                end
            end
        })
        
        TotemSection:AddToggle({
            Title = "Enable 9x Totem",
            Default = false,
            Callback = function(on)
                if on then
                    CombinedModules.Auto9xTotem.Start()
                else
                    CombinedModules.Auto9xTotem.Stop()
                end
            end
        })
    end

    local FavoriteTab = Window:AddTab({Name = "Favorite", Icon = "star"})
    local AutoFavSection = FavoriteTab:AddSection("Auto Favorite", false)

    if CombinedModules.AutoFavorite then
        
        -- Info Label (optional - untuk menjelaskan mode)
        AutoFavSection:AddParagraph({
            Title = "How it works",
            Content = "• Name + Variant = Specific fish with specific variant\n• Variant Only = All fish with that variant\n• Name Only = All variants of that fish\n• Rarity Only = All fish of that rarity"
        })
        
        -- Fish Names Dropdown
        AutoFavSection:AddDropdown({
            Title = "Name",
            Content = "Select specific fish names",
            Multi = true,
            Options = CombinedModules.AutoFavorite.GetAllFishNames(),
            Default = {},
            Callback = function(selected)
                CombinedModules.AutoFavorite.SetSelectedNames(selected)
            end
        })
        
        -- Variants Dropdown (HYBRID MODE)
        AutoFavSection:AddDropdown({
            Title = "Variant",
            Content = "Works alone OR with Name",
            Multi = true,
            Options = CombinedModules.AutoFavorite.GetAllVariants(),
            Default = {},
            Callback = function(selected)
                CombinedModules.AutoFavorite.SetSelectedVariants(selected)
            end
        })
        
        -- Rarity Dropdown
        AutoFavSection:AddDropdown({
            Title = "Rarity",
            Content = "Filter by rarity (Optional)",
            Multi = true,
            Options = CombinedModules.AutoFavorite.GetAllTiers(),
            Default = {},
            Callback = function(selected)
                CombinedModules.AutoFavorite.SetSelectedRarity(selected)
            end
        })
        
        -- Toggle Auto Favorite
        AutoFavSection:AddToggle({
            Title = "Auto Favorite",
            Default = false,
            Callback = function(on)
                if on then
                    CombinedModules.AutoFavorite.Start()
                else
                    CombinedModules.AutoFavorite.Stop()
                end
            end
        })
        
        -- Refresh Lists Button
        AutoFavSection:AddButton({
            Title = "Refresh Lists",
            Callback = function()
                CombinedModules.AutoFavorite.RefreshLists()
            end
        })
        
        -- Unfavorite All Button
        AutoFavSection:AddButton({
            Title = "Unfavorite Fish",
            Callback = function()
                CombinedModules.AutoFavorite.UnfavoriteAll()
            end
        })
    end

    -- ══════════════════════════════════════════
    -- TAB: AUTOMATION
    -- ══════════════════════════════════════════
    local AutomationTab = Window:AddTab({Name = "Automation", Icon = "clock"})
    
    -- Auto Spawn Totem Section
    if CombinedModules.AutoSpawnTotem then
        local AutoSpawnSection = AutomationTab:AddSection("Auto Spawn Totem", false)
        
        -- Info Paragraph
        AutoSpawnSection:AddParagraph({
            Title = "How it works",
            Content = "Automatically spawns selected totem every ~60 minutes.\n• Spawns immediately when enabled\n• Waits 60m 5s for next spawn\n• Prevents overlapping totems"
        })
        
        -- Totem Type Dropdown
        AutoSpawnSection:AddDropdown({
            Title = "Totem Type",
            Content = "Select which totem to auto-spawn",
            Options = CombinedModules.AutoSpawnTotem.GetTotemNames(),
            Default = CombinedModules.AutoSpawnTotem.GetCurrentTotem(),
            Callback = function(selected)
                CombinedModules.AutoSpawnTotem.SetTotem(selected)
            end
        })
        
        -- Toggle Auto Spawn
        AutoSpawnSection:AddToggle({
            Title = "Enable Auto Spawn",
            Default = false,
            Callback = function(on)
                if on then
                    CombinedModules.AutoSpawnTotem.Start()
                else
                    CombinedModules.AutoSpawnTotem.Stop()
                end
            end
        })
    end

    -- ══════════════════════════════════════════
    -- TAB: TELEPORT
    -- ══════════════════════════════════════════
    local TeleportTab = Window:AddTab({Name = "Teleport", Icon = "gps"})
    
    -- Section: Location Teleport
    local LocationSection = TeleportTab:AddSection("Teleport to Location")
    
    if CombinedModules.TeleportModule then
        local locationItems = {}
        for name, _ in pairs(CombinedModules.TeleportModule.Locations or {}) do
            table.insert(locationItems, name)
        end
        table.sort(locationItems)
        
        -- Variable untuk menyimpan lokasi yang dipilih
        local selectedLocation = nil
        
        LocationSection:AddDropdown({
        Title = "Select Location",
            Options = locationItems,
            Default = nil,
            Callback = function(selected)
                selectedLocation = selected
            end
        })
        
        LocationSection:AddButton({
            Title = "Teleport Now",
            Callback = function()
                if selectedLocation then
                    CombinedModules.TeleportModule.TeleportTo(selectedLocation)
                else
                    warn("[Teleport] Please select a location first!")
                end
            end
        })
    end

    -- Section: Saved Location
    local SavedLocSection = TeleportTab:AddSection("Saved Location", false)
    
    SavedLocSection:AddButton({
        Title = "Save Current Location",
        Callback = function()
            if CombinedModules.SavedLocation then CombinedModules.SavedLocation.Save() end
        end
    })
    
    SavedLocSection:AddButton({
        Title = "Teleport to Saved",
        Callback = function()
            if CombinedModules.SavedLocation then CombinedModules.SavedLocation.Teleport() end
        end
    })
    
    SavedLocSection:AddButton({
        Title = "Reset Saved Location",
        Callback = function()
            if CombinedModules.SavedLocation then CombinedModules.SavedLocation.Reset() end
        end
    })

    -- Section: Teleport to Player
    local PlayerTPSection = TeleportTab:AddSection("Teleport to Player", false)
    
    local playerItems = {}
    local selectedPlayer = nil
    local playerDropdown = nil
    
    local function updatePlayerList()
        table.clear(playerItems)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                table.insert(playerItems, player.Name)
            end
        end
        table.sort(playerItems)
    end
    updatePlayerList()
    
    playerDropdown = PlayerTPSection:AddDropdown({
        Title = "Select Player",
        Options = playerItems,
        Default = nil,
        Callback = function(selected)
            selectedPlayer = selected
        end
    })
    
    PlayerTPSection:AddButton({
        Title = "Teleport Now",
        Callback = function()
            if selectedPlayer then
                if CombinedModules.TeleportToPlayer then
                    CombinedModules.TeleportToPlayer.TeleportTo(selectedPlayer)
                end
            else
                warn("[Teleport] Please select a player first!")
            end
        end
    })
    
    PlayerTPSection:AddButton({
        Title = "Refresh Player List",
        Callback = function()
            updatePlayerList()
            if playerDropdown and playerDropdown.SetValues then
                playerDropdown:SetValues(playerItems, nil)
            end
        end
    })

   local EventTPSection = TeleportTab:AddSection("Event Teleport", false)

    local selectedEventName = nil
    local eventNames = {}
    local autoEventToggle = nil

    if CombinedModules.AutoEvent and CombinedModules.AutoEvent.GetEventNames then
        eventNames = CombinedModules.AutoEvent.GetEventNames()
    end

    EventTPSection:AddDropdown({
        Title = "Select Event",
        Options = eventNames,
        Default = nil,
        Callback = function(selected)
            selectedEventName = selected
            
            -- Jika toggle sedang aktif, langsung restart dengan event baru
            if autoEventToggle and autoEventToggle.Value then
                if CombinedModules.AutoEvent then
                    -- Stop dulu event yang lama
                    CombinedModules.AutoEvent.Stop()
                    
                    -- Delay kecil agar stop selesai
                    task.wait(0.1)
                    
                    -- Start dengan event baru jika valid
                    if selected and CombinedModules.AutoEvent.HasEventPattern(selected) then
                        CombinedModules.AutoEvent.Start(selected)
                    end
                end
            end
        end
    })

    autoEventToggle = EventTPSection:AddToggle({
        Title = "Enable Auto Teleport",
        Default = false,
        Callback = function(on)
            if CombinedModules.AutoEvent then
                if on then
                    if selectedEventName and CombinedModules.AutoEvent.HasEventPattern(selectedEventName) then
                        CombinedModules.AutoEvent.Start(selectedEventName)
                    else
                        -- Matikan toggle jika tidak ada event yang dipilih
                        if autoEventToggle then
                            autoEventToggle.Value = false
                        end
                    end
                else
                    CombinedModules.AutoEvent.Stop()
                end
            end
        end
    })

    EventTPSection:AddButton({
        Title = "Teleport Once",
        Callback = function()
            if selectedEventName and CombinedModules.AutoEvent then
                CombinedModules.AutoEvent.TeleportNow(selectedEventName)
            end
        end
    })

    -- ══════════════════════════════════════════
    -- TAB: SHOP
    -- ══════════════════════════════════════════
    local ShopTab = Window:AddTab({Name = "Shop", Icon = "cart"})
    
    -- Section: Sell
    local SellSection = ShopTab:AddSection("Auto Sell")
    
    SellSection:AddButton({
        Title = "Sell All Now",
        Callback = function()
            if CombinedModules.AutoSellSystem then CombinedModules.AutoSellSystem.SellOnce() end
        end
    })
    
    -- Auto Sell Mode Selection
    local autoSellMode = "Timer" -- Default mode
    local autoSellToggle = nil
    local autoSellInputLabel = nil
    
    SellSection:AddDropdown({
        Title = "Auto Sell Mode",
        Options = {"Timer", "By Count"},
        Default = "Timer",
        Callback = function(selected)
            local previousMode = autoSellMode
            autoSellMode = selected
            
            -- Jika toggle aktif, restart dengan mode baru
            if autoSellToggle and autoSellToggle.Value then
                if CombinedModules.AutoSellSystem then
                    -- Stop mode lama
                    if previousMode == "Timer" then
                        if CombinedModules.AutoSellSystem.Timer then
                            CombinedModules.AutoSellSystem.Timer.Stop()
                        end
                    else
                        if CombinedModules.AutoSellSystem.Count then
                            CombinedModules.AutoSellSystem.Count.Stop()
                        end
                    end
                    
                    task.wait(0.1)
                    
                    -- Start mode baru
                    if selected == "Timer" then
                        if CombinedModules.AutoSellSystem.Timer then
                            CombinedModules.AutoSellSystem.Timer.Start()
                        end
                    else
                        if CombinedModules.AutoSellSystem.Count then
                            CombinedModules.AutoSellSystem.Count.Start()
                        end
                    end
                end
            end
        end
    })
    
    SellSection:AddInput({
        Title = "Value (Seconds / Fish Count)",
        Default = "5",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.AutoSellSystem then
                -- Update kedua system
                if CombinedModules.AutoSellSystem.Timer then
                    CombinedModules.AutoSellSystem.Timer.SetInterval(v)
                end
                if CombinedModules.AutoSellSystem.Count then
                    CombinedModules.AutoSellSystem.Count.SetTarget(v)
                end
            end
        end
    })
    
    autoSellToggle = SellSection:AddToggle({
        Title = "Enable Auto Sell",
        Default = false,
        Callback = function(on)
            if CombinedModules.AutoSellSystem then
                if on then
                    if autoSellMode == "Timer" then
                        if CombinedModules.AutoSellSystem.Timer then
                            CombinedModules.AutoSellSystem.Timer.Start()
                        end
                    else
                        if CombinedModules.AutoSellSystem.Count then
                            CombinedModules.AutoSellSystem.Count.Start()
                        end
                    end
                else
                    -- Stop keduanya untuk memastikan
                    if CombinedModules.AutoSellSystem.Timer then
                        CombinedModules.AutoSellSystem.Timer.Stop()
                    end
                    if CombinedModules.AutoSellSystem.Count then
                        CombinedModules.AutoSellSystem.Count.Stop()
                    end
                end
            end
        end
    })

    -- Section: Merchant
    local MerchantSection = ShopTab:AddSection("Remote Merchant", false)
    
    MerchantSection:AddButton({
        Title = "Open Merchant",
        Callback = function()
            if CombinedModules.MerchantSystem then CombinedModules.MerchantSystem.Open() end
        end
    })
    
    MerchantSection:AddButton({
        Title = "Close Merchant",
        Callback = function()
            if CombinedModules.MerchantSystem then CombinedModules.MerchantSystem.Close() end
        end
    })

    -- Section: Auto Buy Weather
    local WeatherSection = ShopTab:AddSection("Auto Buy Weather", false)

    if CombinedModules.AutoBuyWeather then
        local selectedWeathers = {}
        local autoWeatherToggle = nil
        
        WeatherSection:AddDropdown({
            Title = "Select Weather Types",
            Multi = true,
            Options = CombinedModules.AutoBuyWeather.AllWeathers,
            Default = {},
            Callback = function(selected)
                selectedWeathers = selected
                
                if CombinedModules.AutoBuyWeather.SetSelected then
                    CombinedModules.AutoBuyWeather.SetSelected(selectedWeathers)
                end
            end
        })
        
        autoWeatherToggle = WeatherSection:AddToggle({
            Title = "Enable Auto Weather",
            Default = false,
            Callback = function(on)
                if CombinedModules.AutoBuyWeather then
                    if on then
                        if not CombinedModules.AutoBuyWeather.IsAvailable() then
                            print("Weather remote not available")
                            if autoWeatherToggle and autoWeatherToggle.SetValue then
                                autoWeatherToggle:SetValue(false)
                            end
                            return
                        end
                        
                        if #selectedWeathers == 0 then
                            print("Please select at least one weather type")
                            if autoWeatherToggle and autoWeatherToggle.SetValue then
                                autoWeatherToggle:SetValue(false)
                            end
                            return
                        end
                        
                        local success = CombinedModules.AutoBuyWeather.Start()
                        if success then
                            print("Auto Buy Weather started")
                        else
                            print("Failed to start Auto Buy Weather")
                            if autoWeatherToggle and autoWeatherToggle.SetValue then
                                autoWeatherToggle:SetValue(false)
                            end
                        end
                    else
                        CombinedModules.AutoBuyWeather.Stop()
                        print("Auto Buy Weather stopped")
                    end
                end
            end
        })
        
        WeatherSection:AddButton({
            Title = "Buy Selected Once",
            Callback = function()
                if not CombinedModules.AutoBuyWeather.IsAvailable() then
                    print("Weather remote not available")
                    return
                end
                
                if #selectedWeathers == 0 then
                    print("Please select at least one weather type")
                    return
                end
                
                local NetPackage = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"]
                local RFPurchaseWeatherEvent = NetPackage.net["RF/PurchaseWeatherEvent"]
                
                for _, weather in ipairs(selectedWeathers) do
                    pcall(function()
                        RFPurchaseWeatherEvent:InvokeServer(weather)
                    end)
                    task.wait(0.1)
                end
                
                print("Purchased selected weathers once")
            end
        })
    end
    -- Section: Buy Rod
    local BuyRodSection = ShopTab:AddSection("Buy Rod", false)
    
    local RodData = {
        ["Chrome Rod"] = {id = 7, price = 437000}, ["Lucky Rod"] = {id = 4, price = 15000},
        ["Starter Rod"] = {id = 1, price = 50}, ["Steampunk Rod"] = {id = 6, price = 215000},
        ["Carbon Rod"] = {id = 76, price = 750}, ["Ice Rod"] = {id = 78, price = 5000},
        ["Luck Rod"] = {id = 79, price = 325}, ["Midnight Rod"] = {id = 80, price = 50000},
        ["Grass Rod"] = {id = 85, price = 1500}, ["Demascus Rod"] = {id = 77, price = 3000},
        ["Astral Rod"] = {id = 5, price = 1000000}, ["Ares Rod"] = {id = 126, price = 3000000},
        ["Angler Rod"] = {id = 168, price = 8000000}, ["Fluorescent Rod"] = {id = 255, price = 715000},
        ["Bamboo Rod"] = {id = 258, price = 12000000}
    }
    local RodList, RodMap = {}, {}
    for rodName, info in pairs(RodData) do
        local display = rodName .. " (" .. tostring(info.price) .. ")"
        table.insert(RodList, display)
        RodMap[display] = rodName
    end
    local SelectedRod = nil
    
    BuyRodSection:AddDropdown({
        Title = "Select Rod",
        Options = RodList,
        Default = nil,
        Callback = function(displayName)
            SelectedRod = RodMap[displayName]
        end
    })
    
    BuyRodSection:AddButton({
        Title = "BUY SELECTED ROD",
        Callback = function()
            if SelectedRod and CombinedModules.RemoteBuyer and RodData[SelectedRod] then
                CombinedModules.RemoteBuyer.BuyRod(RodData[SelectedRod].id)
            end
        end
    })

    -- Section: Buy Bait
    local BuyBaitSection = ShopTab:AddSection("Buy Bait", false)
    
    local BaitData = {
        ["Chroma Bait"] = {id = 6, price = 290000}, ["Luck Bait"] = {id = 2, price = 1000},
        ["Midnight Bait"] = {id = 3, price = 3000}, ["Topwater Bait"] = {id = 10, price = 100},
        ["Dark Matter Bait"] = {id = 8, price = 630000}, ["Nature Bait"] = {id = 17, price = 83500},
        ["Aether Bait"] = {id = 16, price = 3700000}, ["Corrupt Bait"] = {id = 15, price = 1148484},
        ["Floral Bait"] = {id = 20, price = 4000000}
    }
    local BaitList, BaitMap = {}, {}
    for baitName, info in pairs(BaitData) do
        local display = baitName .. " (" .. tostring(info.price) .. ")"
        table.insert(BaitList, display)
        BaitMap[display] = baitName
    end
    local SelectedBait = nil
    
    BuyBaitSection:AddDropdown({
        Title = "Select Bait",
        Options = BaitList,
        Default = nil,
        Callback = function(displayName)
            SelectedBait = BaitMap[displayName]
        end
    })
    
    BuyBaitSection:AddButton({
        Title = "BUY SELECTED BAIT",
        Callback = function()
            if SelectedBait and CombinedModules.RemoteBuyer and BaitData[SelectedBait] then
                CombinedModules.RemoteBuyer.BuyBait(BaitData[SelectedBait].id)
            end
        end
    })

    -- ══════════════════════════════════════════
    -- TAB: CAMERA
    -- ══════════════════════════════════════════
    local CameraTab = Window:AddTab({Name = "Camera", Icon = "eyes"})
    
    -- Section: Unlimited Zoom
    local ZoomSection = CameraTab:AddSection("Unlimited Zoom")
    
    ZoomSection:AddToggle({
        Title = "Enable Unlimited Zoom",
        Default = false,
        Callback = function(on)
            if CombinedModules.UnlimitedZoom then
                if on then CombinedModules.UnlimitedZoom.Enable() else CombinedModules.UnlimitedZoom.Disable() end
            end
        end
    })

    -- Section: Freecam
    local FreecamSection = CameraTab:AddSection("Freecam", false)
    
    FreecamSection:AddToggle({
        Title = "Enable Freecam (F3 Toggle)",
        Default = false,
        Callback = function(on)
            if CombinedModules.FreecamModule then
                CombinedModules.FreecamModule.EnableF3Keybind(on)
                if not on and CombinedModules.FreecamModule.IsActive() then
                    CombinedModules.FreecamModule.Stop()
                end
            end
        end
    })
    
    FreecamSection:AddInput({
        Title = "Movement Speed",
        Default = "50",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.FreecamModule and CombinedModules.FreecamModule.SetSpeed then
                CombinedModules.FreecamModule.SetSpeed(v)
            end
        end
    })
    
    FreecamSection:AddInput({
        Title = "Mouse Sensitivity",
        Default = "0.5",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.FreecamModule and CombinedModules.FreecamModule.SetSensitivity then
                CombinedModules.FreecamModule.SetSensitivity(v)
            end
        end
    })

    -- ══════════════════════════════════════════
    -- TAB: WEBHOOK
    -- ══════════════════════════════════════════
    local WebhookTab = Window:AddTab({Name = "Webhook", Icon = "send"})
    
    -- ══════════════════════════════════════════
    -- Section: Fish Caught Webhook
    -- ══════════════════════════════════════════
    local FishCaughtSection = WebhookTab:AddSection("Fish Caught Webhook")
    
    local currentWebhookURL = ""
    local currentDiscordID = ""
    local fishWebhookToggle = nil
    
    FishCaughtSection:AddInput({
        Title = "Webhook URL",
        Default = "",
        Callback = function(value)
            currentWebhookURL = value:gsub("^%s*(.-)%s*$", "%1")
            if CombinedModules.Webhook and CombinedModules.Webhook.SetFishWebhookURL then
                pcall(function()
                    CombinedModules.Webhook:SetFishWebhookURL(currentWebhookURL)
                end)
            end
        end
    })
    
    FishCaughtSection:AddInput({
        Title = "Discord User ID (for mention)",
        Default = "",
        Callback = function(value)
            currentDiscordID = value:gsub("^%s*(.-)%s*$", "%1")
            if CombinedModules.Webhook and CombinedModules.Webhook.SetFishDiscordUserID then
                pcall(function()
                    CombinedModules.Webhook:SetFishDiscordUserID(currentDiscordID)
                end)
            end
        end
    })
    
    FishCaughtSection:AddDropdown({
        Title = "Rarity Filter",
        Options = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET"},
        Multi = true,
        Default = {},
        Callback = function(selected)
            if CombinedModules.Webhook then
                -- Update rarity filter immediately
                if CombinedModules.Webhook.SetFishEnabledRarities then
                    pcall(function()
                        CombinedModules.Webhook:SetFishEnabledRarities(selected)
                    end)
                end
                
                -- Auto-start webhook if URL is set and not already running
                if currentWebhookURL ~= "" then
                    local isRunning = false
                    pcall(function()
                        if CombinedModules.Webhook.IsFishRunning then
                            isRunning = CombinedModules.Webhook:IsFishRunning()
                        end
                    end)
                    
                    if not isRunning then
                        pcall(function()
                            if CombinedModules.Webhook.SetFishWebhookURL then
                                CombinedModules.Webhook:SetFishWebhookURL(currentWebhookURL)
                            end
                            if CombinedModules.Webhook.SetFishDiscordUserID and currentDiscordID ~= "" then
                                CombinedModules.Webhook:SetFishDiscordUserID(currentDiscordID)
                            end
                            if CombinedModules.Webhook.StartFishWebhook then
                                CombinedModules.Webhook:StartFishWebhook()
                            end
                        end)
                        
                        -- Update toggle state
                        if fishWebhookToggle and fishWebhookToggle.SetValue then
                            fishWebhookToggle:SetValue(true)
                        end
                    end
                end
            end
        end
    })
    
    fishWebhookToggle = FishCaughtSection:AddToggle({
        Title = "Enable Fish Webhook",
        Default = false,
        Callback = function(on)
            if CombinedModules.Webhook then
                if on then
                    if currentWebhookURL == "" then
                        if fishWebhookToggle and fishWebhookToggle.SetValue then
                            fishWebhookToggle:SetValue(false)
                        end
                        return
                    end
                    
                    pcall(function()
                        if CombinedModules.Webhook.SetFishWebhookURL then
                            CombinedModules.Webhook:SetFishWebhookURL(currentWebhookURL)
                        end
                        if CombinedModules.Webhook.SetFishDiscordUserID and currentDiscordID ~= "" then
                            CombinedModules.Webhook:SetFishDiscordUserID(currentDiscordID)
                        end
                        if CombinedModules.Webhook.StartFishWebhook then
                            CombinedModules.Webhook:StartFishWebhook()
                        end
                    end)
                else
                    pcall(function()
                        if CombinedModules.Webhook.StopFishWebhook then
                            CombinedModules.Webhook:StopFishWebhook()
                        end
                    end)
                end
            end
        end
    })
    
    FishCaughtSection:AddButton({
        Title = "Test Webhook",
        Callback = function()
            if currentWebhookURL == "" then return end

            local requestFunc = nil
            pcall(function()
                requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
            end)
            
            if requestFunc then
                pcall(function()
                    requestFunc({
                        Url = currentWebhookURL,
                        Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        Body = HttpService:JSONEncode({
                            embeds = {{
                                title = "✅ Webhook Test Successful!",
                                description = "Lynx GUI is ready to send fish notifications.",
                                color = 65280,
                                footer = {
                                    text = "Lynx Fish Webhook Test",
                                    icon_url = "https://i.imgur.com/shnNZuT.png"
                                },
                                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                            }}
                        })
                    })
                end)
            end
        end
    })

    -- ══════════════════════════════════════════
    -- Section: Disconnect Webhook
    -- ══════════════════════════════════════════
    local DisconnectWebhookSection = WebhookTab:AddSection("Disconnect Webhook", false)
    
    local disconnectWebhookURL = ""
    local disconnectDiscordID = ""
    local disconnectHideIdentity = ""
    
    DisconnectWebhookSection:AddParagraph({
        Title = "Info",
        Content = "Kirim notifikasi ke Discord saat Roblox disconnect, dan otomatis rejoin."
    })
    
    DisconnectWebhookSection:AddInput({
        Title = "Disconnect Webhook URL",
        Default = "",
        Callback = function(value)
            disconnectWebhookURL = value:gsub("^%s*(.-)%s*$", "%1")
            if CombinedModules.Webhook and CombinedModules.Webhook.SetDisconnectWebhookURL then
                pcall(function()
                    CombinedModules.Webhook:SetDisconnectWebhookURL(disconnectWebhookURL)
                end)
            end
        end
    })
    
    DisconnectWebhookSection:AddInput({
        Title = "Discord User ID (for mention)",
        Default = "",
        Callback = function(value)
            disconnectDiscordID = value:gsub("^%s*(.-)%s*$", "%1")
            if CombinedModules.Webhook and CombinedModules.Webhook.SetDisconnectDiscordUserID then
                pcall(function()
                    CombinedModules.Webhook:SetDisconnectDiscordUserID(disconnectDiscordID)
                end)
            end
        end
    })
    
    DisconnectWebhookSection:AddInput({
        Title = "Hide Identity (Custom Name)",
        Default = "",
        Callback = function(value)
            disconnectHideIdentity = value:gsub("^%s*(.-)%s*$", "%1")
            if CombinedModules.Webhook and CombinedModules.Webhook.SetDisconnectHideIdentity then
                pcall(function()
                    CombinedModules.Webhook:SetDisconnectHideIdentity(disconnectHideIdentity)
                end)
            end
        end
    })
    
    DisconnectWebhookSection:AddToggle({
        Title = "Enable Disconnect Alert",
        Default = false,
        Callback = function(on)
            if CombinedModules.Webhook and CombinedModules.Webhook.EnableDisconnectWebhook then
                pcall(function()
                    CombinedModules.Webhook:EnableDisconnectWebhook(on)
                end)
            end
        end
    })
    
    DisconnectWebhookSection:AddButton({
        Title = "Test Disconnect Webhook",
        Callback = function()
            if disconnectWebhookURL == "" then return end
            
            if CombinedModules.Webhook and CombinedModules.Webhook.TestDisconnectWebhook then
                pcall(function()
                    CombinedModules.Webhook:TestDisconnectWebhook()
                end)
            end
        end
    })

    -- ══════════════════════════════════════════
    -- TAB: SETTINGS
    -- ══════════════════════════════════════════
    local SettingsTab = Window:AddTab({Name = "Settings", Icon = "settings"})
    
    -- Section: Protection
    local ProtectionSection = SettingsTab:AddSection("Protection")
    
    ProtectionSection:AddToggle({
        Title = "Anti-AFK",
        Default = false,
        Callback = function(on)
            if CombinedModules.AntiAFK then
                if on then CombinedModules.AntiAFK.Start() else CombinedModules.AntiAFK.Stop() end
            end
        end
    })
    
    ProtectionSection:AddToggle({
        Title = "Anti Staff (Auto Kick)",
        Default = false,
        Callback = function(on)
            if CombinedModules.AntiStaff then
                if on then CombinedModules.AntiStaff.Start() else CombinedModules.AntiStaff.Stop() end
            end
        end
    })

    -- Section: Performance
    local PerformanceSection = SettingsTab:AddSection("Performance", false)
    
    PerformanceSection:AddToggle({
        Title = "FPS Booster",
        Default = false,
        Callback = function(on)
            if CombinedModules.FPSBooster then
                if on then CombinedModules.FPSBooster.Enable() else CombinedModules.FPSBooster.Disable() end
            end
        end
    })
    
    PerformanceSection:AddToggle({
        Title = "Disable 3D Rendering",
        Default = false,
        Callback = function(on)
            if CombinedModules.DisableRendering then
                if on then CombinedModules.DisableRendering.Start() else CombinedModules.DisableRendering.Stop() end
            end
        end
    })

    -- Section: Hide Stats
    local HideStatsSection = SettingsTab:AddSection("Hide Stats", false)
    
    HideStatsSection:AddToggle({
        Title = "Enable Hide Stats",
        Default = false,
        Callback = function(on)
            if CombinedModules.HideStats then
                if on then CombinedModules.HideStats.Enable() else CombinedModules.HideStats.Disable() end
            end
        end
    })
    
    HideStatsSection:AddInput({
        Title = "Fake Name",
        Default = "Guest",
        Callback = function(value)
            if CombinedModules.HideStats and CombinedModules.HideStats.SetFakeName then
                CombinedModules.HideStats.SetFakeName(value)
            end
        end
    })
    
    HideStatsSection:AddInput({
        Title = "Fake Level",
        Default = "1",
        Callback = function(value)
            if CombinedModules.HideStats and CombinedModules.HideStats.SetFakeLevel then
                CombinedModules.HideStats.SetFakeLevel(value)
            end
        end
    })

    -- Section: Server
    local ServerSection = SettingsTab:AddSection("Server", false)
    
    ServerSection:AddButton({
        Title = "Rejoin Server",
        Callback = function()
            pcall(function()
                TeleportService:Teleport(game.PlaceId, localPlayer)
            end)
        end
    })

    -- Section: Player Utility
    local UtilitySection = SettingsTab:AddSection("Player Utility", false)
    
    UtilitySection:AddInput({
        Title = "Sprint Speed",
        Default = "50",
        Callback = function(value)
            local v = tonumber(value)
            if v and CombinedModules.MovementModule then
                CombinedModules.MovementModule.SetSprintSpeed(v)
            end
        end
    })
    
    UtilitySection:AddToggle({
        Title = "Enable Sprint",
        Default = false,
        Callback = function(on)
            if CombinedModules.MovementModule then
                if on then CombinedModules.MovementModule.EnableSprint() else CombinedModules.MovementModule.DisableSprint() end
            end
        end
    })
    
    UtilitySection:AddToggle({
        Title = "Enable Infinite Jump",
        Default = false,
        Callback = function(on)
            if CombinedModules.MovementModule then
                if on then CombinedModules.MovementModule.EnableInfiniteJump() else CombinedModules.MovementModule.DisableInfiniteJump() end
            end
        end
    })

    -- ══════════════════════════════════════════
    -- Section: Config Management
    -- ══════════════════════════════════════════
    local ConfigSection = SettingsTab:AddSection("Config Management", false)
    
    -- Get game name for config folder
    local gameName = tostring(game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name)
    gameName = gameName:gsub("[^%w_ ]", "")
    gameName = gameName:gsub("%s+", "_")
    local configFolder = "Lynx/Configs/" .. gameName
    
    -- Ensure config folder exists
    pcall(function()
        if not isfolder("Lynx") then makefolder("Lynx") end
        if not isfolder("Lynx/Configs") then makefolder("Lynx/Configs") end
        if not isfolder(configFolder) then makefolder(configFolder) end
    end)
    
    -- Function to get list of saved configs
    local function GetSavedConfigs()
        local configs = {}
        pcall(function()
            if isfolder and listfiles and isfolder(configFolder) then
                local files = listfiles(configFolder)
                for _, file in ipairs(files) do
                    local name = file:match("([^/\\]+)%.json$")
                    if name then
                        table.insert(configs, name)
                    end
                end
            end
        end)
        if #configs == 0 then
            table.insert(configs, "No configs saved")
        end
        return configs
    end
    
    -- Variables for config management
    local customConfigName = ""
    local selectedConfig = ""
    local configDropdown = nil
    
    -- Auto-save control
    if _G.AutoSaveEnabled == nil then
        _G.AutoSaveEnabled = true
    end
    
    ConfigSection:AddToggle({
        Title = "Auto Save Enabled",
        Default = true,
        NoSave = true,
        Callback = function(on)
            _G.AutoSaveEnabled = on
            if Lynx and Lynx.MakeNotify then
                Lynx:MakeNotify({
                    Title = "Config",
                    Description = on and "Auto-save enabled" or "Auto-save disabled",
                    Content = on and "Settings akan disimpan otomatis." or "Settings TIDAK akan disimpan otomatis.",
                    Color = on and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 165, 0),
                    Delay = 3
                })
            end
        end
    })
    
    -- Input for custom config name
    ConfigSection:AddInput({
        Title = "Config Name",
        Default = "",
        Placeholder = "Enter config name...",
        Callback = function(value)
            customConfigName = value:gsub("[^%w_ ]", ""):gsub("%s+", "_")
        end
    })
    
    -- Save config with custom name
    ConfigSection:AddButton({
        Title = "Save Config",
        Callback = function()
            if customConfigName == "" then
                if Lynx and Lynx.MakeNotify then
                    Lynx:MakeNotify({
                        Title = "Config",
                        Description = "Error",
                        Content = "Masukkan nama config terlebih dahulu!",
                        Color = Color3.fromRGB(255, 100, 100),
                        Delay = 3
                    })
                end
                return
            end
            
            pcall(function()
                if writefile and ConfigData then
                    local filePath = configFolder .. "/" .. customConfigName .. ".json"
                    ConfigData._version = CURRENT_VERSION
                    writefile(filePath, HttpService:JSONEncode(ConfigData))
                    
                    if Lynx and Lynx.MakeNotify then
                        Lynx:MakeNotify({
                            Title = "Config",
                            Description = "Saved!",
                            Content = "Config '" .. customConfigName .. "' berhasil disimpan!",
                            Color = Color3.fromRGB(0, 255, 100),
                            Delay = 3
                        })
                    end
                    
                    -- Update dropdown options
                    if configDropdown and configDropdown.SetOptions then
                        configDropdown:SetOptions(GetSavedConfigs())
                    end
                end
            end)
        end
    })
    
    -- Divider/Separator
    ConfigSection:AddParagraph({
        Title = "Load/Delete Config",
        Content = "Pilih config dari dropdown lalu klik Load atau Delete"
    })
    
    -- Dropdown to select config
    configDropdown = ConfigSection:AddDropdown({
        Title = "Select Config",
        Options = GetSavedConfigs(),
        Default = "",
        NoSave = true,
        Callback = function(value)
            if value ~= "No configs saved" then
                selectedConfig = value
            else
                selectedConfig = ""
            end
        end
    })
    
    -- Load selected config
    ConfigSection:AddButton({
        Title = "Load Config",
        Callback = function()
            if selectedConfig == "" then
                if Lynx and Lynx.MakeNotify then
                    Lynx:MakeNotify({
                        Title = "Config",
                        Description = "Error",
                        Content = "Pilih config dari dropdown terlebih dahulu!",
                        Color = Color3.fromRGB(255, 100, 100),
                        Delay = 3
                    })
                end
                return
            end
            
            pcall(function()
                local filePath = configFolder .. "/" .. selectedConfig .. ".json"
                if isfile and readfile and isfile(filePath) then
                    local success, data = pcall(function()
                        return HttpService:JSONDecode(readfile(filePath))
                    end)
                    
                    if success and type(data) == "table" then
                        -- Update ConfigData
                        for k, v in pairs(data) do
                            ConfigData[k] = v
                        end
                        
                        -- Apply loaded config to UI elements
                        if LoadConfigElements then
                            LoadConfigElements()
                        end
                        
                        if Lynx and Lynx.MakeNotify then
                            Lynx:MakeNotify({
                                Title = "Config",
                                Description = "Loaded!",
                                Content = "Config '" .. selectedConfig .. "' berhasil dimuat! Beberapa setting mungkin perlu rejoin.",
                                Color = Color3.fromRGB(0, 200, 255),
                                Delay = 4
                            })
                        end
                    else
                        if Lynx and Lynx.MakeNotify then
                            Lynx:MakeNotify({
                                Title = "Config",
                                Description = "Error",
                                Content = "Gagal memuat config. File mungkin corrupt.",
                                Color = Color3.fromRGB(255, 100, 100),
                                Delay = 3
                            })
                        end
                    end
                else
                    if Lynx and Lynx.MakeNotify then
                        Lynx:MakeNotify({
                            Title = "Config",
                            Description = "Error",
                            Content = "Config file tidak ditemukan!",
                            Color = Color3.fromRGB(255, 100, 100),
                            Delay = 3
                        })
                    end
                end
            end)
        end
    })
    
    -- Delete selected config
    ConfigSection:AddButton({
        Title = "Delete Config",
        Callback = function()
            if selectedConfig == "" then
                if Lynx and Lynx.MakeNotify then
                    Lynx:MakeNotify({
                        Title = "Config",
                        Description = "Error",
                        Content = "Pilih config dari dropdown terlebih dahulu!",
                        Color = Color3.fromRGB(255, 100, 100),
                        Delay = 3
                    })
                end
                return
            end
            
            pcall(function()
                local filePath = configFolder .. "/" .. selectedConfig .. ".json"
                if isfile and delfile and isfile(filePath) then
                    delfile(filePath)
                    
                    if Lynx and Lynx.MakeNotify then
                        Lynx:MakeNotify({
                            Title = "Config",
                            Description = "Deleted!",
                            Content = "Config '" .. selectedConfig .. "' berhasil dihapus!",
                            Color = Color3.fromRGB(255, 200, 0),
                            Delay = 3
                        })
                    end
                    
                    selectedConfig = ""
                    
                    -- Update dropdown options
                    if configDropdown and configDropdown.SetOptions then
                        configDropdown:SetOptions(GetSavedConfigs())
                    end
                else
                    if Lynx and Lynx.MakeNotify then
                        Lynx:MakeNotify({
                            Title = "Config",
                            Description = "Error",
                            Content = "Config file tidak ditemukan!",
                            Color = Color3.fromRGB(255, 100, 100),
                            Delay = 3
                        })
                    end
                end
            end)
        end
    })
    
    -- Refresh configs list button
    ConfigSection:AddButton({
        Title = "Refresh List",
        Callback = function()
            if configDropdown and configDropdown.SetOptions then
                configDropdown:SetOptions(GetSavedConfigs())
                if Lynx and Lynx.MakeNotify then
                    Lynx:MakeNotify({
                        Title = "Config",
                        Description = "Refreshed!",
                        Content = "Daftar config berhasil di-refresh.",
                        Color = Color3.fromRGB(100, 200, 255),
                        Delay = 2
                    })
                end
            end
        end
    })
    
    -- Reset current settings to default
    ConfigSection:AddButton({
        Title = "Reset Current Settings",
        Callback = function()
            pcall(function()
                -- Use the global ResetToDefaults function from Library
                if ResetToDefaults then
                    ResetToDefaults()
                end
                
                -- Stop all active modules
                if CombinedModules and CombinedModules.CleanupAllModules then
                    pcall(function()
                        CombinedModules.CleanupAllModules()
                    end)
                end
                
                if Lynx and Lynx.MakeNotify then
                    Lynx:MakeNotify({
                        Title = "Config",
                        Description = "Reset!",
                        Content = "Semua setting telah direset ke default.",
                        Color = Color3.fromRGB(255, 200, 0),
                        Delay = 4
                    })
                end
            end)
        end
    })

    -- ══════════════════════════════════════════
    -- TAB: ABOUT
    -- ══════════════════════════════════════════
    local AboutTab = Window:AddTab({Name = "About", Icon = "player"})
    
    local InfoSection = AboutTab:AddSection("About Lynx", true)
    
    InfoSection:AddParagraph({
        Title = "Lynx Discord",
        Content = "Official link discord Lynx!"
    })
    
    InfoSection:AddButton({
        Title = "COPY LINK DISCORD",
        Callback = function()
            pcall(function()
                if setclipboard then
                    setclipboard("https://discord.gg/lynxx")
                end
            end)
        end
    })

    -- GUI Built
    
    -- ═══════════════════════════════════════════════════════════════════════════
    -- CLEANUP HOOK - Monitor GUI destroy using AncestryChanged
    -- ═══════════════════════════════════════════════════════════════════════════
    task.spawn(function()
        local LynxGui = CoreGui:WaitForChild("LynxGui", 5)
        if LynxGui then
            LynxGui.AncestryChanged:Connect(function(_, parent)
                if parent == nil then
                    -- GUI sedang di-destroy, jalankan cleanup
                    CombinedModules.CleanupAllModules()
                end
            end)
        end
    end)
    
    return Window
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CLEANUP ALL MODULES - Menghentikan semua module yang aktif
-- ═══════════════════════════════════════════════════════════════════════════
CombinedModules.CleanupAllModules = function()
    -- List semua module dengan fungsi Stop/Disable
    local modulesWithStop = {
        "instant",
        "instant2",
        "blatantv1",
        "blatantBETA",
        "UltraBlatant",
        "blatantv2",
        "blatantv3",
        "AntiAFK",
        "AntiStaff",
        "StableResult",
        "Auto9xTotem",
        "AutoEquipRod",
        "AutoEvent",
        "AutoSellSystem",
        "AutoBuyWeather",
        "AutoFavorite",
        "Webhook",
        "NoFishingAnimation",
        "LockPosition",
        "DisableCutscenes",
        "WalkOnWater",
        "MovementModule",
        "HideStats",
        "DisableRendering",
    }
    
    local modulesWithDisable = {
        "FPSBooster",
        "UnlimitedZoom",
        "FreecamModule",
        "HideStats",
        "DisableRendering",
    }
    
    -- Stop semua module dengan .Stop()
    for _, moduleName in ipairs(modulesWithStop) do
        pcall(function()
            local mod = CombinedModules[moduleName]
            if mod and type(mod.Stop) == "function" then
                mod.Stop()
            end
            -- Untuk nested modules (seperti AutoSellSystem.Timer, AutoSellSystem.Count)
            if mod and type(mod) == "table" then
                if mod.Timer and type(mod.Timer.Stop) == "function" then
                    mod.Timer.Stop()
                end
                if mod.Count and type(mod.Count.Stop) == "function" then
                    mod.Count.Stop()
                end
            end
        end)
    end
    
    -- Disable semua module dengan .Disable()
    for _, moduleName in ipairs(modulesWithDisable) do
        pcall(function()
            local mod = CombinedModules[moduleName]
            if mod and type(mod.Disable) == "function" then
                mod.Disable()
            end
        end)
    end
    
    -- Cleanup global fishing scripts
    pcall(function()
        if _G.FishingScriptFast then
            _G.FishingScriptFast.Stop()
            _G.FishingScriptFast = nil
        end
    end)
    
    pcall(function()
        if _G.FishingScript then
            _G.FishingScript.Stop()
            _G.FishingScript = nil
        end
    end)
    
    -- Stop FreecamModule jika aktif
    pcall(function()
        if CombinedModules.FreecamModule then
            if CombinedModules.FreecamModule.IsActive and CombinedModules.FreecamModule.IsActive() then
                CombinedModules.FreecamModule.Stop()
            end
            if CombinedModules.FreecamModule.EnableF3Keybind then
                CombinedModules.FreecamModule.EnableF3Keybind(false)
            end
        end
    end)
    
    -- Clear NetEvents
    pcall(function()
        _G.NetEvents = nil
        _G.SharedCharacter = nil
        _G.SharedHumanoid = nil
    end)

end

-- ═══════════════════════════════════════════════════════════════════════════
-- BUILD GUI OTOMATIS
-- ═══════════════════════════════════════════════════════════════════════════
if Lynx then
    CombinedModules.BuildGUI(Lynx)
end

return CombinedModules
