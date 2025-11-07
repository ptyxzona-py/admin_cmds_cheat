-- AdminCombined.server.lua
-- Single server script that:
--  - Registers safe, predefined admin commands (server-side)
--  - Handles a RemoteEvent for owner-only command execution
--  - Attempts to auto-deploy a client LocalScript (GUI) into owners' PlayerGui
--  - Falls back to printing the client source so you can manually add it to StarterGui if runtime Source assignment is restricted
--
-- Place this Script in ServerScriptService.
-- Make sure to add any additional owner userIds to the `owners` table below.
-- You told me your owner id is 5653893300; I've added it to the owners table.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Create or get RemoteEvent
local remote = ReplicatedStorage:FindFirstChild("AdminCommandEvent")
if not remote then
    remote = Instance.new("RemoteEvent")
    remote.Name = "AdminCommandEvent"
    remote.Parent = ReplicatedStorage
end

-- CommandRegistry: each entry contains description and callback(invoker, argsTable)
local CommandRegistry = {}

local function toNumberOrNil(s)
    if not s then return nil end
    local n = tonumber(s)
    return n
end

-- Example commands
CommandRegistry.teleport = {
    description = "Teleport player(s) to coordinates. Usage: teleport <player|all> <x> <y> <z>",
    callback = function(invoker, args)
        if not args[1] or not args[2] or not args[3] or not args[4] then
            return false, "missing arguments"
        end
        local target = args[1]
        local x = toNumberOrNil(args[2])
        local y = toNumberOrNil(args[3])
        local z = toNumberOrNil(args[4])
        if not x or not y or not z then
            return false, "invalid coordinates"
        end
        local pos = Vector3.new(x, y, z)
        if target:lower() == "all" then
            for _, pl in pairs(Players:GetPlayers()) do
                local char = pl.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = CFrame.new(pos)
                end
            end
            return true, "teleported all players"
        else
            local pl = Players:FindFirstChild(target)
            if not pl then
                -- try partial match
                for _, p in pairs(Players:GetPlayers()) do
                    if p.Name:lower():find(target:lower(), 1, true) then
                        pl = p
                        break
                    end
                end
            end
            if not pl then return false, "target player not found" end
            local char = pl.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                return false, "target has no character"
            end
            char.HumanoidRootPart.CFrame = CFrame.new(pos)
            return true, "teleported "..pl.Name
        end
    end,
}

CommandRegistry.kick = {
    description = "Kick a player. Usage: kick <player|all> [reason]",
    callback = function(invoker, args)
        local target = args[1]
        if not target then return false, "missing target" end
        local reason = args[2] or "Kicked by admin"
        if target:lower() == "all" then
            for _, pl in pairs(Players:GetPlayers()) do
                if pl ~= invoker then
                    pl:Kick(reason)
                end
            end
            return true, "kicked all players"
        else
            local pl = Players:FindFirstChild(target)
            if not pl then
                for _, p in pairs(Players:GetPlayers()) do
                    if p.Name:lower():find(target:lower(), 1, true) then
                        pl = p
                        break
                    end
                end
            end
            if not pl then return false, "target player not found" end
            pl:Kick(reason)
            return true, "kicked "..pl.Name
        end
    end,
}

CommandRegistry.speed = {
    description = "Set walk speed. Usage: speed <player|all> <walkSpeed>",
    callback = function(invoker, args)
        local target = args[1]
        local speed = toNumberOrNil(args[2])
        if not target or not speed then return false, "missing args" end
        if target:lower() == "all" then
            for _, pl in pairs(Players:GetPlayers()) do
                local char = pl.Character
                if char and char:FindFirstChild("Humanoid") then
                    char.Humanoid.WalkSpeed = speed
                end
            end
            return true, "set speed for all to "..tostring(speed)
        else
            local pl = Players:FindFirstChild(target)
            if not pl then
                for _, p in pairs(Players:GetPlayers()) do
                    if p.Name:lower():find(target:lower(), 1, true) then
                        pl = p
                        break
                    end
                end
            end
            if not pl then return false, "target player not found" end
            local char = pl.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid.WalkSpeed = speed
                return true, "set walk speed for "..pl.Name.." to "..tostring(speed)
            end
            return false, "target has no humanoid"
        end
    end,
}

CommandRegistry.help = {
    description = "List available commands",
    callback = function(invoker, args)
        local lines = {}
        for name, cmd in pairs(CommandRegistry) do
            if type(cmd) == "table" and cmd.description then
                table.insert(lines, name .. " - " .. cmd.description)
            end
        end
        return true, table.concat(lines, "\n")
    end,
}

-- Owners list: userIds allowed to run commands
local owners = {
    [game.CreatorId] = true,       -- keep the game's creator by default
    [5653893300] = true,          -- your provided owner id (added as requested)
    -- Add more userIds here, e.g. [12345678] = true
}

local function isOwner(player)
    if not player then return false end
    return owners[player.UserId] == true
end

-- Client LocalScript source (string). This builds the admin GUI and fires the RemoteEvent.
local clientSource = [[
-- AdminClient (auto-deployed)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("AdminCommandEvent")

-- Build UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminConsoleGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 50
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 480, 0, 140)
frame.Position = UDim2.new(0, 12, 0, 50)
frame.BackgroundTransparency = 0.25
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Text = "Admin Console"
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.new(0, 8, 0, 4)
title.Parent = frame

local input = Instance.new("TextBox")
input.PlaceholderText = "Enter command: e.g. help  OR teleport PlayerName 0 5 0"
input.Size = UDim2.new(1, -100, 0, 32)
input.Position = UDim2.new(0, 8, 0, 36)
input.ClearTextOnFocus = false
input.BackgroundColor3 = Color3.fromRGB(50,50,50)
input.TextColor3 = Color3.new(1,1,1)
input.TextSize = 16
input.Parent = frame

local runBtn = Instance.new("TextButton")
runBtn.Text = "Run"
runBtn.Size = UDim2.new(0, 72, 0, 32)
runBtn.Position = UDim2.new(1, -82, 0, 36)
runBtn.BackgroundColor3 = Color3.fromRGB(70,70,70)
runBtn.TextColor3 = Color3.new(1,1,1)
runBtn.Parent = frame

local output = Instance.new("TextLabel")
output.Text = ""
output.Size = UDim2.new(1, -16, 0, 64)
output.Position = UDim2.new(0, 8, 0, 76)
output.BackgroundTransparency = 1
output.TextWrapped = true
output.TextColor3 = Color3.new(1,1,1)
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.Font = Enum.Font.SourceSans
output.TextSize = 14
output.Parent = frame

local function parseAndSend(text)
    if not text or text:match("^%s*$") then
        output.Text = "no command"
        return
    end
    local parts = {}
    for token in text:gmatch("%S+") do
        table.insert(parts, token)
    end
    local cmd = parts[1]
    table.remove(parts, 1)
    if not cmd then
        output.Text = "no command"
        return
    end
    -- Fire server: (command, arg1, arg2, ...)
    remote:FireServer(cmd, table.unpack(parts))
    output.Text = "sent: "..cmd
end

runBtn.MouseButton1Click:Connect(function()
    parseAndSend(input.Text)
end)

input.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        parseAndSend(input.Text)
    end
end)

remote.OnClientEvent:Connect(function(success, message)
    if success then
        output.Text = "OK: "..tostring(message)
    else
        output.Text = "ERR: "..tostring(message)
    end
end)
]]

-- Attempt to create a LocalScript template in ReplicatedStorage so we can clone it into each owner's PlayerGui
local templateName = "AdminClientTemplate"
local successCreateTemplate, templateObj = pcall(function()
    local existing = ReplicatedStorage:FindFirstChild(templateName)
    if existing and existing:IsA("LocalScript") then
        return existing
    end
    local ls = Instance.new("LocalScript")
    ls.Name = templateName
    -- Setting Source may be restricted in live games; this will work in Studio/play-mode.
    ls.Source = clientSource
    ls.Parent = ReplicatedStorage
    return ls
end)

if not successCreateTemplate then
    warn("Could not create LocalScript template in ReplicatedStorage automatically. If you see this warning in a live server, copy the client code and place it into a LocalScript in StarterGui.")
    warn("Client code snippet (copy into a LocalScript under StarterGui named 'AdminClient'):\n"..clientSource)
else
    templateObj = templateObj -- template LocalScript in ReplicatedStorage
end

-- Utility: log admin use
local function logAdminUse(player, commandName, args)
    local argStr = ""
    if args and #args > 0 then
        argStr = table.concat(args, " ")
    end
    print(string.format("[Admin] %s (%d) ran: %s %s", player.Name, player.UserId, tostring(commandName), argStr))
end

-- Combined RemoteEvent handler: authorizes, logs, executes commands, and sends result back to client
remote.OnServerEvent:Connect(function(player, commandName, ...)
    -- Validate caller
    if not isOwner(player) then
        warn(player.Name .. " attempted to run admin command: " .. tostring(commandName))
        -- Do not provide command details back to non-owners
        return
    end

    local args = {...}
    logAdminUse(player, commandName, args)

    local cmdKey = tostring(commandName or ""):lower()
    local cmd = CommandRegistry[cmdKey]
    if not cmd or type(cmd.callback) ~= "function" then
        remote:FireClient(player, false, "unknown command: "..cmdKey)
        return
    end

    local ok, res1, res2 = pcall(function()
        return cmd.callback(player, args)
    end)
    if not ok then
        remote:FireClient(player, false, "command error: " .. tostring(res1))
        warn("Admin command error from "..player.Name..": "..tostring(res1))
        return
    end

    -- Interpret returned values
    if type(res1) == "boolean" then
        remote:FireClient(player, res1, res2 or (res1 and "success" or "failed"))
    elseif type(res1) == "string" then
        remote:FireClient(player, true, res1)
    else
        remote:FireClient(player, true, "command executed")
    end
end)

-- When an owner joins, deploy the client LocalScript into their PlayerGui (clone from template if possible)
Players.PlayerAdded:Connect(function(pl)
    -- wait for PlayerGui to exist
    local playerGui = pl:WaitForChild("PlayerGui", 10)
    if not playerGui then
        warn("PlayerGui not available for "..pl.Name.." - cannot deploy admin UI")
        return
    end

    -- Only deploy UI to owners
    if not isOwner(pl) then return end

    -- Try cloning the template LocalScript into the player's PlayerGui
    local template = ReplicatedStorage:FindFirstChild(templateName)
    if template and template:IsA("LocalScript") then
        local ok, clone = pcall(function()
            local cloned = template:Clone()
            cloned.Parent = playerGui
            return cloned
        end)
        if not ok then
            warn("Failed to clone Admin client LocalScript into "..pl.Name.."'s PlayerGui.")
            local sg = Instance.new("ScreenGui")
            sg.Name = "AdminConsoleNotice"
            sg.ResetOnSpawn = false
            sg.Parent = playerGui
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1,0,0,40)
            label.Position = UDim2.new(0,0,0,0)
            label.BackgroundTransparency = 0.5
            label.Text = "Admin console failed to auto-deploy. Please add a LocalScript named 'AdminClient' to StarterGui with the provided client source."
            label.TextWrapped = true
            label.Parent = sg
        end
    else
        -- No template available; inform owner with ScreenGui and provide instructions
        local sg = Instance.new("ScreenGui")
        sg.Name = "AdminConsoleNotice"
        sg.ResetOnSpawn = false
        sg.Parent = playerGui
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,0,0,60)
        label.Position = UDim2.new(0,0,0,0)
        label.BackgroundTransparency = 0.5
        label.Text = "Admin console client not found. In Studio, run this script once to create the client template, or copy the client LocalScript source and place it under StarterGui as a LocalScript named 'AdminClient'."
        label.TextWrapped = true
        label.Parent = sg
        warn("Admin client template missing; manual setup required for owner "..pl.Name)
    end
end)

-- End of AdminCombined.server.lua
