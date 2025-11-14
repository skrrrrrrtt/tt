--!strict
-- Kohana Volcano Teleport + Equip Rod + LegitFishing (no UI)

local Players           = game:GetService("Players")
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player   = Players.LocalPlayer
local Character, Humanoid

----------------------------------------------------------------
-- 1. Wait for character + teleport
----------------------------------------------------------------
local function waitForCharacter()
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        Character = Player.Character
        Humanoid  = Character:FindFirstChildOfClass("Humanoid")
        return
    end
    Player.CharacterAdded:Wait()
    Character = Player.Character
    Humanoid  = Character:WaitForChild("Humanoid")
end

waitForCharacter()

-- Teleport to Kohana Volcano
local volcanoCFrame = CFrame.new(
    -628.758911, 35.710186, 104.373764,
    0.482912123, 1.81591773e-08, 0.875668824,
    3.01732896e-08, 1, -3.73774007e-08,
    -0.875668824, 4.44718076e-08, 0.482912123
)

Character:WaitForChild("HumanoidRootPart").CFrame = volcanoCFrame
print("Teleported to Kohana Volcano")

----------------------------------------------------------------
-- 2. Equip rod from hotbar (change slot if needed)
----------------------------------------------------------------
task.delay(0.5, function()  -- tiny delay so the character fully loads
    local Net = ReplicatedStorage
        :WaitForChild("Packages")
        :WaitForChild("_Index")
        :WaitForChild("sleitnick_net@0.2.0")
        :WaitForChild("net")

    local REEquipToolFromHotbar = Net:WaitForChild("RE/EquipToolFromHotbar")

    -- Slot 1 = first hotbar slot (change to 2,3,… if you store rod elsewhere)
    pcall(function()
        REEquipToolFromHotbar:FireServer(1)
    end)
    print("Rod equipped from hotbar slot 1")
end)

----------------------------------------------------------------
-- 3. LegitFishing automation (your original code, unchanged)
----------------------------------------------------------------
task.spawn(function()
    repeat task.wait() until game:IsLoaded()

    local Net = ReplicatedStorage
        :WaitForChild("Packages")
        :WaitForChild("_Index")
        :WaitForChild("sleitnick_net@0.2.0")
        :WaitForChild("net")

    local RfCancel = Net:WaitForChild("RF/CancelFishingInputs")
    local FishingController = require(ReplicatedStorage.Controllers.FishingController)
    local Constants = require(ReplicatedStorage.Shared.Constants)

    -- Instant recast
    Constants.FishingCooldownTime = 0

    local States = {
        Idle      = "Idle",
        Casting   = "Casting",
        Waiting   = "Waiting",
        Minigame  = "Minigame",
        Reeling   = "Reeling",
        Completed = "Completed",
    }

    local CurrentState = States.Idle
    local CurrentGuid  = nil
    local MinigameCompleted = false
    local StateChangeTime = os.clock()

    local function DetectState()
        local Guid = FishingController:GetCurrentGUID()
        if Guid then
            if CurrentState ~= States.Minigame then
                CurrentGuid = Guid
                MinigameCompleted = false
            end
            return States.Minigame
        end

        if CurrentGuid and not Guid then
            local IsBusy = (FishingController.FishingLine and FishingController.FishingLine.Parent)
                or (FishingController.FishingBobber and FishingController.FishingBobber.Parent)
                or FishingController._isFishing
                or FishingController._isReeling

            if IsBusy then
                return States.Reeling
            else
                if MinigameCompleted then
                    return States.Completed
                else
                    CurrentGuid = nil
                    return States.Idle
                end
            end
        end

        return (FishingController.OnCooldown and FishingController:OnCooldown() or false)
            and States.Waiting or States.Idle
    end

    while true do
        if not (Character and Character:FindFirstChild("HumanoidRootPart")) then
            task.wait(1)
            continue
        end

        local NewState = DetectState()
        if NewState ~= CurrentState then
            CurrentState = NewState
            StateChangeTime = os.clock()
        end

        -- Timeout stuck casting/waiting
        if (CurrentState == States.Casting or CurrentState == States.Waiting)
            and (os.clock() - StateChangeTime) > 8 then
            pcall(RfCancel.InvokeServer, RfCancel)
            CurrentState = States.Idle
            StateChangeTime = os.clock()
        end

        -- Idle → Cast
        if CurrentState == States.Idle then
            if not FishingController:OnCooldown() then
                pcall(RfCancel.InvokeServer, RfCancel)
                pcall(FishingController.RequestChargeFishingRod, FishingController, nil, true)
                CurrentState = States.Casting
            end
        end

        -- Minigame → Spam clicks
        if CurrentState == States.Minigame then
            local ClickConnection
            local ClickCount = 0
            ClickConnection = RunService.Heartbeat:Connect(function()
                if not FishingController:GetCurrentGUID() then
                    if ClickConnection then ClickConnection:Disconnect() end
                    return
                end
                for i = 1, 5 do
                    pcall(FishingController.FishingMinigameClick, FishingController)
                end
                ClickCount += 5
            end)

            while FishingController:GetCurrentGUID() do task.wait() end
            if ClickConnection then ClickConnection:Disconnect() end

            MinigameCompleted = true
            CurrentState = States.Completed
        end

        -- Completed → Reset
        if CurrentState == States.Completed then
            CurrentGuid = nil
            MinigameCompleted = false
            CurrentState = States.Idle
        end

        task.wait()
    end
end)

print("LegitFishing loaded – running silently.")
