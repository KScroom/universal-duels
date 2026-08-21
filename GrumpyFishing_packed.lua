-- Grumpy Fishing (PTDE)
-- Casts via CharacterHandler.LeftClick. Server GetMouse must hit a part named Water within 35 studs.
-- Bobber lives in Workspace.Thrown. Bite is RippleHolder.ring (Bite/Reel sounds are debris).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local genv = (type(getgenv) == "function" and getgenv()) or _G
local SCRIPT_URL = "https://raw.githubusercontent.com/KScroom/universal-duels/master/GrumpyFishing_packed.lua"
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
local camera = workspace.CurrentCamera

local fishing = false
local fishingGeneration = 0
local reelClicks = 40
local clickDelay = 0.04
local biteTimeout = 35
local totalCaught = tonumber(genv.GrumpyFishingCaught) or 0
local lastCatch = "None"
local lastCatchAt = 0
local connections = {}
local restoreGetMouseHook
local hopping = false
local proximityEnabled = genv.GrumpyFishingProximity ~= false
local rangeStuds = tonumber(genv.GrumpyFishingRange) or 80
local lastHopAt = 0

local function track(conn)
	connections[#connections + 1] = conn
	return conn
end

local function disconnectAll()
	for _, conn in ipairs(connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(connections)
end

local function bindCharacter(newCharacter)
	character = newCharacter
	humanoid = newCharacter and newCharacter:FindFirstChildOfClass("Humanoid")
	if humanoid then
		track(humanoid.Died:Connect(function()
			if fishing then
				fishing = false
			end
		end))
	end
end

bindCharacter(character)
track(player.CharacterAdded:Connect(function(newCharacter)
	bindCharacter(newCharacter)
end))
track(player.CharacterRemoving:Connect(function()
	if not hopping and fishing then
		fishing = false
	end
	character = nil
	humanoid = nil
end))

local playerGui = player:WaitForChild("PlayerGui")
local guiParent = playerGui
pcall(function()
	if gethui then
		guiParent = gethui()
	end
end)

pcall(function()
	for _, parent in ipairs({ guiParent, playerGui, game:GetService("CoreGui") }) do
		local old = parent:FindFirstChild("GrumpyFishing")
		if old then
			old:Destroy()
		end
	end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrumpyFishing"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = guiParent

local function shutdown()
	fishing = false
	if restoreGetMouseHook then
		restoreGetMouseHook()
	end
	disconnectAll()
	if screenGui then
		screenGui:Destroy()
	end
end

local FRAME_H = 430
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, FRAME_H)
mainFrame.Position = UDim2.new(0, 20, 0.5, -140)
mainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local frameStroke = Instance.new("UIStroke", mainFrame)
frameStroke.Color = Color3.fromRGB(0, 150, 200)
frameStroke.Thickness = 1.5
frameStroke.Transparency = 0.3

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = Color3.fromRGB(0, 130, 180)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local titleBarFill = Instance.new("Frame")
titleBarFill.Size = UDim2.new(1, 0, 0.5, 0)
titleBarFill.Position = UDim2.new(0, 0, 0.5, 0)
titleBarFill.BackgroundColor3 = Color3.fromRGB(0, 130, 180)
titleBarFill.BorderSizePixel = 0
titleBarFill.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🎣  Grumpy Fishing"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 24, 0, 20)
closeButton.Position = UDim2.new(1, -28, 0.5, -10)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.BackgroundTransparency = 0.2
closeButton.Text = "✕"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 12
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.BorderSizePixel = 0
closeButton.Parent = titleBar
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 4)

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 24, 0, 20)
minimizeButton.Position = UDim2.new(1, -56, 0.5, -10)
minimizeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.BackgroundTransparency = 0.7
minimizeButton.Text = "—"
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 12
minimizeButton.TextColor3 = Color3.new(1, 1, 1)
minimizeButton.BorderSizePixel = 0
minimizeButton.Parent = titleBar
Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(0, 4)

closeButton.MouseButton1Click:Connect(shutdown)

local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
	end
end)

track(UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end))

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -44)
content.Position = UDim2.new(0, 10, 0, 40)
content.BackgroundTransparency = 1
content.Parent = mainFrame

local minimized = false
minimizeButton.MouseButton1Click:Connect(function()
	minimized = not minimized
	content.Visible = not minimized
	mainFrame.Size = minimized and UDim2.new(0, 260, 0, 36) or UDim2.new(0, 260, 0, FRAME_H)
	minimizeButton.Text = minimized and "+" or "—"
end)

local listLayout = Instance.new("UIListLayout", content)
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function createLabel(text, color, order)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = color or Color3.fromRGB(180, 180, 180)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = order or 0
	label.Parent = content
	return label
end

local statusLabel = createLabel("Status: Idle", Color3.fromRGB(150, 150, 160), 1)
local catchLabel = createLabel("Last Catch: None", Color3.fromRGB(100, 200, 255), 2)
local totalLabel = createLabel("Total Caught: " .. totalCaught, Color3.fromRGB(100, 220, 100), 3)

local divider1 = Instance.new("Frame")
divider1.Size = UDim2.new(1, 0, 0, 1)
divider1.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
divider1.BorderSizePixel = 0
divider1.LayoutOrder = 4
divider1.Parent = content

local reelLabel = createLabel("Max Reel Clicks: " .. reelClicks, Color3.fromRGB(180, 180, 180), 5)

local sliderArea = Instance.new("Frame")
sliderArea.Size = UDim2.new(1, 0, 0, 16)
sliderArea.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
sliderArea.BorderSizePixel = 0
sliderArea.LayoutOrder = 6
sliderArea.Parent = content
Instance.new("UICorner", sliderArea).CornerRadius = UDim.new(0, 4)

local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(1, -10, 0, 6)
sliderTrack.Position = UDim2.new(0, 5, 0.5, -3)
sliderTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
sliderTrack.BorderSizePixel = 0
sliderTrack.Parent = sliderArea
Instance.new("UICorner", sliderTrack).CornerRadius = UDim.new(1, 0)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(reelClicks / 80, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(0, 130, 180)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderTrack
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

local function applySliderFromX(x)
	local pct = (x - sliderTrack.AbsolutePosition.X) / math.max(sliderTrack.AbsoluteSize.X, 1)
	pct = math.clamp(pct, 0, 1)
	reelClicks = math.floor(pct * 79) + 1
	sliderFill.Size = UDim2.new(pct, 0, 1, 0)
	reelLabel.Text = "Max Reel Clicks: " .. reelClicks
end

local draggingSlider = false
sliderArea.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingSlider = true
		applySliderFromX(input.Position.X)
	end
end)

track(UserInputService.InputChanged:Connect(function(input)
	if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
		applySliderFromX(input.Position.X)
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingSlider = false
	end
end))

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, 0, 0, 34)
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 130, 180)
toggleButton.Text = "▶  Start Fishing"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 13
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.BorderSizePixel = 0
toggleButton.LayoutOrder = 7
toggleButton.Parent = content
Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 6)

toggleButton.MouseEnter:Connect(function()
	TweenService:Create(toggleButton, TweenInfo.new(0.1), {
		BackgroundColor3 = fishing and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(0, 160, 220)
	}):Play()
end)

toggleButton.MouseLeave:Connect(function()
	TweenService:Create(toggleButton, TweenInfo.new(0.1), {
		BackgroundColor3 = fishing and Color3.fromRGB(150, 40, 40) or Color3.fromRGB(0, 130, 180)
	}):Play()
end)

local hintLabel = createLabel("Start equipped — auto-casts if no bobber", Color3.fromRGB(100, 100, 110), 8)
hintLabel.TextSize = 10

local dividerProx = Instance.new("Frame")
dividerProx.Size = UDim2.new(1, 0, 0, 1)
dividerProx.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
dividerProx.BorderSizePixel = 0
dividerProx.LayoutOrder = 9
dividerProx.Parent = content

local proximityButton = Instance.new("TextButton")
proximityButton.Size = UDim2.new(1, 0, 0, 28)
proximityButton.BackgroundColor3 = proximityEnabled and Color3.fromRGB(120, 50, 140) or Color3.fromRGB(60, 60, 75)
proximityButton.Text = proximityEnabled and "Auto Menu Hop: ON" or "Auto Menu Hop: OFF"
proximityButton.Font = Enum.Font.GothamBold
proximityButton.TextSize = 12
proximityButton.TextColor3 = Color3.new(1, 1, 1)
proximityButton.BorderSizePixel = 0
proximityButton.LayoutOrder = 10
proximityButton.Parent = content
Instance.new("UICorner", proximityButton).CornerRadius = UDim.new(0, 6)

local nearLabel = createLabel("Nearest: —", Color3.fromRGB(180, 180, 180), 11)
local rangeLabel = createLabel("Hop range: " .. rangeStuds .. " studs", Color3.fromRGB(180, 180, 180), 12)

local rangeArea = Instance.new("Frame")
rangeArea.Size = UDim2.new(1, 0, 0, 16)
rangeArea.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
rangeArea.BorderSizePixel = 0
rangeArea.LayoutOrder = 13
rangeArea.Parent = content
Instance.new("UICorner", rangeArea).CornerRadius = UDim.new(0, 4)

local rangeTrack = Instance.new("Frame")
rangeTrack.Size = UDim2.new(1, -10, 0, 6)
rangeTrack.Position = UDim2.new(0, 5, 0.5, -3)
rangeTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
rangeTrack.BorderSizePixel = 0
rangeTrack.Parent = rangeArea
Instance.new("UICorner", rangeTrack).CornerRadius = UDim.new(1, 0)

local rangeFill = Instance.new("Frame")
rangeFill.Size = UDim2.new((rangeStuds - 10) / 290, 0, 1, 0)
rangeFill.BackgroundColor3 = Color3.fromRGB(160, 80, 180)
rangeFill.BorderSizePixel = 0
rangeFill.Parent = rangeTrack
Instance.new("UICorner", rangeFill).CornerRadius = UDim.new(1, 0)

local function applyRangeFromX(x)
	local pct = (x - rangeTrack.AbsolutePosition.X) / math.max(rangeTrack.AbsoluteSize.X, 1)
	pct = math.clamp(pct, 0, 1)
	rangeStuds = math.floor(pct * 290) + 10
	rangeFill.Size = UDim2.new(pct, 0, 1, 0)
	rangeLabel.Text = "Hop range: " .. rangeStuds .. " studs"
	getgenv().GrumpyFishingRange = rangeStuds
end

local draggingRange = false
rangeArea.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingRange = true
		applyRangeFromX(input.Position.X)
	end
end)

track(UserInputService.InputChanged:Connect(function(input)
	if draggingRange and input.UserInputType == Enum.UserInputType.MouseMovement then
		applyRangeFromX(input.Position.X)
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingRange = false
	end
end))

local function updateProximityButton()
	proximityButton.Text = proximityEnabled and "Auto Menu Hop: ON" or "Auto Menu Hop: OFF"
	TweenService:Create(proximityButton, TweenInfo.new(0.15), {
		BackgroundColor3 = proximityEnabled and Color3.fromRGB(120, 50, 140) or Color3.fromRGB(60, 60, 75),
	}):Play()
end

proximityButton.MouseButton1Click:Connect(function()
	proximityEnabled = not proximityEnabled
	getgenv().GrumpyFishingProximity = proximityEnabled
	updateProximityButton()
end)

local divider2 = Instance.new("Frame")
divider2.Size = UDim2.new(1, 0, 0, 1)
divider2.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
divider2.BorderSizePixel = 0
divider2.LayoutOrder = 14
divider2.Parent = content

local hopButton = Instance.new("TextButton")
hopButton.Size = UDim2.new(1, 0, 0, 28)
hopButton.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
hopButton.Text = "🔀  Server Hop"
hopButton.Font = Enum.Font.GothamBold
hopButton.TextSize = 12
hopButton.TextColor3 = Color3.new(1, 1, 1)
hopButton.BorderSizePixel = 0
hopButton.LayoutOrder = 15
hopButton.Parent = content
Instance.new("UICorner", hopButton).CornerRadius = UDim.new(0, 6)

local lowPopButton = Instance.new("TextButton")
lowPopButton.Size = UDim2.new(1, 0, 0, 28)
lowPopButton.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
lowPopButton.Text = "👤  Low Pop Server Hop"
lowPopButton.Font = Enum.Font.GothamBold
lowPopButton.TextSize = 12
lowPopButton.TextColor3 = Color3.new(1, 1, 1)
lowPopButton.BorderSizePixel = 0
lowPopButton.LayoutOrder = 16
lowPopButton.Parent = content
Instance.new("UICorner", lowPopButton).CornerRadius = UDim.new(0, 6)

for _, button in pairs({ hopButton, lowPopButton }) do
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(80, 80, 100)
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(60, 60, 75)
		}):Play()
	end)
end

local function setStatus(text, color)
	statusLabel.Text = "Status: " .. text
	statusLabel.TextColor3 = color or Color3.fromRGB(150, 150, 160)
end

local function updateToggleButton()
	if fishing then
		toggleButton.Text = "■  Stop Fishing"
		TweenService:Create(toggleButton, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(150, 40, 40)
		}):Play()
	else
		toggleButton.Text = "▶  Start Fishing"
		TweenService:Create(toggleButton, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(0, 130, 180)
		}):Play()
	end
end

local function getRoot()
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function closestPointOnPart(part, from)
	local localPoint = part.CFrame:PointToObjectSpace(from)
	local half = part.Size * 0.5
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	return part.CFrame:PointToWorldSpace(clamped)
end

local function findCastWater()
	local root = getRoot()
	if not root then
		return nil
	end

	local aim = root.Position + root.CFrame.LookVector * 16
	local bestPart, bestPos, bestDist = nil, nil, math.huge

	local function consider(part)
		if not part or part.Name ~= "Water" or not part:IsA("BasePart") then
			return
		end
		local hit = closestPointOnPart(part, aim)
		local dist = (hit - root.Position).Magnitude
		if dist > 34 then
			hit = closestPointOnPart(part, root.Position)
			dist = (hit - root.Position).Magnitude
		end
		if dist <= 34 and dist < bestDist then
			bestPart = part
			bestPos = hit
			bestDist = dist
		end
	end

	local ok, nearby = pcall(function()
		return workspace:GetPartBoundsInRadius(root.Position, 35)
	end)
	if ok and nearby then
		for _, part in ipairs(nearby) do
			consider(part)
		end
	end

	if not bestPart then
		local mouse = player:GetMouse()
		if mouse and mouse.Target and mouse.Target.Name == "Water" then
			consider(mouse.Target)
		end
	end

	return bestPart, bestPos
end

local getMouseRemote = ReplicatedStorage:FindFirstChild("Requests") and ReplicatedStorage.Requests:FindFirstChild("GetMouse")
local previousGetMouse = nil
local getMouseHooked = false

local function ensureGetMouseHook()
	if not getMouseRemote or getMouseHooked then
		return
	end
	pcall(function()
		if getcallbackvalue then
			previousGetMouse = getcallbackvalue(getMouseRemote, "OnClientInvoke")
		end
	end)
	getMouseHooked = true
	getMouseRemote.OnClientInvoke = function(...)
		if fishing then
			local water, pos = findCastWater()
			if water and pos then
				return { Target = water, Hit = CFrame.new(pos) }
			end
		end
		if type(previousGetMouse) == "function" then
			return previousGetMouse(...)
		end
		local mouse = player:GetMouse()
		return { Target = mouse.Target, Hit = mouse.Hit }
	end
end

function restoreGetMouseHook()
	if getMouseHooked and getMouseRemote and type(previousGetMouse) == "function" then
		pcall(function()
			getMouseRemote.OnClientInvoke = previousGetMouse
		end)
	end
	getMouseHooked = false
	previousGetMouse = nil
end

local function isUnderOtherCharacter(inst)
	local live = workspace:FindFirstChild("Live")
	if not live then
		return false
	end
	local current = inst
	while current and current ~= workspace do
		if current.Parent == live and current ~= character then
			return true
		end
		current = current.Parent
	end
	return false
end

local function bobberPart(inst)
	if inst:IsA("BasePart") then
		return inst
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function considerBobber(inst, into)
	if not inst or inst.Name ~= "Bobber" then
		return
	end
	if isUnderOtherCharacter(inst) then
		return
	end
	into[#into + 1] = inst
end

local function collectBobbers()
	local found = {}
	local thrown = workspace:FindFirstChild("Thrown")
	if thrown then
		for _, d in ipairs(thrown:GetChildren()) do
			considerBobber(d, found)
		end
	end
	if #found == 0 then
		for _, child in ipairs(workspace:GetChildren()) do
			considerBobber(child, found)
		end
	end
	return found
end

local function pickOwnBobber(list)
	if #list == 0 then
		return nil
	end

	local root = getRoot()
	local best, bestScore = nil, math.huge
	for _, inst in ipairs(list) do
		local part = bobberPart(inst)
		local score = 1e9
		if part and root then
			score = (part.Position - root.Position).Magnitude
		end
		if score < bestScore then
			bestScore = score
			best = inst
		end
	end

	if best and bestScore > 40 then
		return nil
	end
	return best
end

local function findBobber()
	return pickOwnBobber(collectBobbers())
end

local function findFishingRod()
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") and string.find(string.lower(tool.Name), "fishing", 1, true) then
				return tool
			end
		end
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and string.find(string.lower(tool.Name), "fishing", 1, true) then
				return tool
			end
		end
	end
end

local function equipRod()
	local rod = findFishingRod()
	if not rod or not character then
		return rod
	end
	if character:FindFirstChild(rod.Name) then
		return rod
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:EquipTool(rod)
		task.wait(0.35)
	end
	return findFishingRod()
end

local function getLeftClick()
	local handler = character and character:FindFirstChild("CharacterHandler")
	local remotes = handler and handler:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild("LeftClick")
end

local function activateRod()
	local rod = findFishingRod()
	if not rod or not character or not character:FindFirstChild(rod.Name) then
		return false
	end

	ensureGetMouseHook()

	pcall(function()
		local remote = getLeftClick()
		if remote then
			remote:FireServer({
				math.random(1, 10),
				tonumber("0." .. math.random(1e15, 9e15)),
			})
		end
	end)
	pcall(function()
		rod:Activate()
	end)
	pcall(function()
		local center = camera.ViewportSize / 2
		VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
		task.wait(0.03)
		VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
	end)
	return true
end

local function waitForBobber(timeout)
	local existing = findBobber()
	if existing then
		return existing
	end

	local found = nil
	local thrown = workspace:FindFirstChild("Thrown")
	local function onAdded(descendant)
		if descendant.Name == "Bobber" and not isUnderOtherCharacter(descendant) then
			local part = bobberPart(descendant)
			local root = getRoot()
			if part and root and (part.Position - root.Position).Magnitude > 40 then
				return
			end
			found = descendant
		end
	end

	local conns = {}
	if thrown then
		conns[#conns + 1] = thrown.ChildAdded:Connect(onAdded)
	end
	conns[#conns + 1] = workspace.DescendantAdded:Connect(onAdded)

	local elapsed = 0
	while not found and elapsed < timeout and fishing do
		task.wait(0.08)
		elapsed += 0.08
		if not found then
			found = findBobber()
		end
	end

	for _, conn in ipairs(conns) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	return found
end

local function bobberHasBite(bobber)
	if not bobber or not bobber.Parent then
		return false
	end
	local holder = bobber:FindFirstChild("RippleHolder")
	local ring = holder and holder:FindFirstChild("ring")
	if ring and ring.Enabled then
		return true
	end
	if bobber:FindFirstChild("Bite") or bobber:FindFirstChild("Reel") then
		return true
	end
	return false
end

local function waitForBite(bobber, timeout)
	if not bobber or not bobber.Parent then
		return false
	end
	if bobberHasBite(bobber) then
		return true
	end

	local gotBite = false
	local connection = bobber.DescendantAdded:Connect(function(child)
		if child.Name == "Bite" or child.Name == "Reel" or child.Name == "ring" then
			gotBite = true
		end
	end)

	local elapsed = 0
	while not gotBite and elapsed < timeout and fishing do
		if not bobber.Parent then
			break
		end
		if bobberHasBite(bobber) then
			gotBite = true
			break
		end
		task.wait(0.08)
		elapsed += 0.08
	end

	connection:Disconnect()
	return gotBite
end

local function reelIn(bobber)
	local clicks = 0
	local delay = math.max(clickDelay, 0.06)
	while fishing and clicks < reelClicks do
		if not bobber or not bobber.Parent then
			break
		end
		if tick() - lastCatchAt < 0.35 then
			break
		end
		activateRod()
		clicks += 1
		task.wait(delay + math.random() * 0.012)
	end
end

local function cancelAndRecast()
	local existing = findBobber()
	if existing then
		activateRod()
		local elapsed = 0
		while existing.Parent and elapsed < 1.2 and fishing do
			task.wait(0.08)
			elapsed += 0.08
		end
		task.wait(0.2)
	end
	if not fishing then
		return nil
	end
	activateRod()
	return waitForBobber(6)
end

local requests = ReplicatedStorage:FindFirstChild("Requests")
local clientMessage = requests and requests:FindFirstChild("ClientMessage")
if clientMessage then
	track(clientMessage.OnClientEvent:Connect(function(message)
		if not fishing then
			return
		end
		local text = tostring(message)
		if not string.find(string.lower(text), "caught", 1, true) then
			return
		end
		if tick() - lastCatchAt < 1.2 then
			return
		end
		lastCatchAt = tick()
		lastCatch = text:gsub("[Cc]aught a:? ?", ""):gsub("!", ""):gsub("^ ", "")
		totalCaught += 1
		catchLabel.Text = "Last Catch: " .. lastCatch
		totalLabel.Text = "Total Caught: " .. totalCaught
		setStatus("Caught " .. lastCatch .. "!", Color3.fromRGB(100, 220, 100))
	end))
end

local function fishingLoop(generation)
	setStatus("Starting...", Color3.fromRGB(200, 200, 100))
	ensureGetMouseHook()

	local rod = equipRod()
	if not rod then
		setStatus("No fishing rod!", Color3.fromRGB(255, 80, 80))
		fishing = false
		updateToggleButton()
		return
	end

	local bobber = findBobber()
	if not bobber then
		while fishing and generation == fishingGeneration and not findCastWater() do
			setStatus("Stand by Water (35 studs)", Color3.fromRGB(255, 180, 80))
			task.wait(0.4)
		end
		if not fishing or generation ~= fishingGeneration then
			return
		end
		setStatus("Casting...", Color3.fromRGB(200, 200, 100))
		bobber = cancelAndRecast()
	end

	if bobber then
		print("[AutoFish] Bobber found")
	end

	while fishing and generation == fishingGeneration do
		if not character or not character.Parent then
			setStatus("Character gone", Color3.fromRGB(255, 80, 80))
			break
		end

		rod = equipRod()
		if not rod then
			setStatus("No fishing rod!", Color3.fromRGB(255, 80, 80))
			task.wait(1.5)
		elseif not findCastWater() then
			setStatus("Stand by Water (35 studs)", Color3.fromRGB(255, 180, 80))
			task.wait(0.4)
		else
			if not bobber or not bobber.Parent then
				bobber = findBobber()
			end

			if bobber and bobber.Parent then
				setStatus("Waiting for bite...", Color3.fromRGB(100, 180, 255))
				local gotBite = waitForBite(bobber, biteTimeout)
				if not fishing or generation ~= fishingGeneration then
					break
				end

				if gotBite then
					setStatus("Reeling in...", Color3.fromRGB(255, 220, 50))
					reelIn(bobber)
					task.wait(0.4)
				else
					setStatus("No bite, recasting...", Color3.fromRGB(200, 150, 50))
				end
			end

			if not fishing or generation ~= fishingGeneration then
				break
			end

			setStatus("Casting...", Color3.fromRGB(200, 200, 100))
			bobber = cancelAndRecast()
			if not bobber then
				setStatus("Cast failed, retrying...", Color3.fromRGB(255, 150, 50))
				task.wait(0.35)
			end
		end
	end

	if generation == fishingGeneration then
		fishing = false
		restoreGetMouseHook()
		setStatus("Idle", Color3.fromRGB(150, 150, 160))
		updateToggleButton()
	end
end

local function queueSelf()
	local q = (syn and syn.queue_on_teleport)
		or queue_on_teleport
		or (fluxus and fluxus.queue_on_teleport)
		or queueonteleport
	if not q then
		return false
	end
	getgenv().GrumpyFishingResume = true
	getgenv().GrumpyFishingProximity = proximityEnabled
	getgenv().GrumpyFishingRange = rangeStuds
	getgenv().GrumpyFishingCaught = totalCaught
	local boot = [[
getgenv().GrumpyFishingResume = true
getgenv().GrumpyFishingProximity = true
getgenv().GrumpyFishingRange = ]] .. tostring(rangeStuds) .. [[

getgenv().GrumpyFishingCaught = ]] .. tostring(totalCaught) .. [[

local ran = false
pcall(function()
	if isfile and isfile("GrumpyFishing.lua") then
		loadstring(readfile("GrumpyFishing.lua"))()
		ran = true
	end
end)
if not ran then
	loadstring(game:HttpGet("https://raw.githubusercontent.com/KScroom/universal-duels/master/GrumpyFishing_packed.lua?v=" .. tostring(math.random(1, 1e9))))()
end
]]
	pcall(q, boot)
	return true
end

pcall(function()
	if writefile then
		task.spawn(function()
			pcall(function()
				writefile("GrumpyFishing.lua", game:HttpGet(SCRIPT_URL .. "?v=" .. tostring(tick())))
			end)
		end)
	end
end)

local function pressMenu()
	local pg = player:FindFirstChild("PlayerGui")
	local gui = pg and pg:FindFirstChild("MenuReturnGui")
	local btn = gui and gui:FindFirstChild("Menu", true)
	if btn and btn:IsA("GuiButton") then
		pcall(function()
			if firesignal then
				firesignal(btn.MouseButton1Click)
			end
		end)
		pcall(function()
			if getconnections then
				for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
					if conn.Fire then
						conn:Fire()
					elseif conn.Function then
						conn.Function()
					end
				end
			end
		end)
	end
	pcall(function()
		local requests = ReplicatedStorage:FindFirstChild("Requests")
		local remote = requests and requests:FindFirstChild("ReturnToMenu")
		if remote then
			if remote:IsA("RemoteFunction") then
				remote:InvokeServer()
			else
				remote:FireServer()
			end
		end
	end)
end

local function clickPlayIfNeeded()
	local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 20)
	if not pg then
		return
	end
	local startMenu = pg:FindFirstChild("StartMenu") or pg:WaitForChild("StartMenu", 15)
	if not startMenu then
		return
	end
	local choices = startMenu:FindFirstChild("Choices")
	local play = choices and choices:FindFirstChild("Play")
	if not play then
		return
	end
	pcall(function()
		if firesignal then
			firesignal(play.MouseButton1Click)
		end
	end)
	pcall(function()
		if getconnections then
			for _, conn in ipairs(getconnections(play.MouseButton1Click)) do
				if conn.Fire then
					conn:Fire()
				elseif conn.Function then
					conn.Function()
				end
			end
		end
	end)
end

local function waitForLiveCharacter(timeout)
	local deadline = tick() + (timeout or 25)
	while tick() < deadline do
		local char = player.Character
		if char and char.Parent and char.Parent.Name == "Live" then
			bindCharacter(char)
			return char
		end
		task.wait(0.2)
	end
	if player.Character then
		bindCharacter(player.Character)
		return player.Character
	end
	return nil
end

local function nearestPlayer()
	local root = getRoot()
	if not root then
		return nil, nil
	end
	local dead = workspace:FindFirstChild("Dead")
	local bestPlayer, bestDist = nil, math.huge
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local char = other.Character
			if char and char.Parent and char.Parent ~= dead then
				local otherRoot = char:FindFirstChild("HumanoidRootPart")
				if otherRoot then
					local dist = (otherRoot.Position - root.Position).Magnitude
					if dist < bestDist then
						bestDist = dist
						bestPlayer = other
					end
				end
			end
		end
	end
	return bestPlayer, bestDist
end

local function pickLowPopServer()
	local ok, result = pcall(function()
		return HttpService:JSONDecode(
			game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=25")
		)
	end)
	if ok and result and result.data then
		local bestServerId, lowestCount = nil, math.huge
		for _, server in pairs(result.data) do
			if server.id ~= game.JobId and typeof(server.playing) == "number" and server.playing < lowestCount then
				lowestCount = server.playing
				bestServerId = server.id
			end
		end
		return bestServerId, lowestCount
	end
	return nil
end

local function hopAway(reason)
	if hopping or tick() - lastHopAt < 4 then
		return
	end
	hopping = true
	lastHopAt = tick()
	fishing = false
	if restoreGetMouseHook then
		restoreGetMouseHook()
	end
	updateToggleButton()
	setStatus(reason or "Player close — hopping", Color3.fromRGB(255, 120, 80))
	queueSelf()
	pcall(pressMenu)
	task.wait(0.45)
	local serverId = pickLowPopServer()
	if serverId then
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, player)
		end)
	else
		pcall(function()
			TeleportService:Teleport(game.PlaceId, player)
		end)
	end
end

local function startFishing()
	if fishing then
		return
	end
	fishing = true
	fishingGeneration += 1
	local generation = fishingGeneration
	updateToggleButton()
	task.spawn(fishingLoop, generation)
end

hopButton.MouseButton1Click:Connect(function()
	queueSelf()
	fishing = false
	updateToggleButton()
	setStatus("Server hopping...", Color3.fromRGB(200, 200, 100))
	pcall(function()
		TeleportService:Teleport(game.PlaceId, player)
	end)
end)

lowPopButton.MouseButton1Click:Connect(function()
	queueSelf()
	fishing = false
	updateToggleButton()
	setStatus("Finding low pop server...", Color3.fromRGB(200, 200, 100))

	task.spawn(function()
		local ok, result = pcall(function()
			return game:GetService("HttpService"):JSONDecode(
				game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=25")
			)
		end)

		if ok and result and result.data then
			local bestServerId, lowestCount = nil, math.huge
			for _, server in pairs(result.data) do
				if server.id ~= game.JobId and server.playing < lowestCount then
					lowestCount = server.playing
					bestServerId = server.id
				end
			end

			if bestServerId then
				setStatus("Joining (" .. lowestCount .. " players)...", Color3.fromRGB(100, 220, 100))
				task.wait(0.5)
				pcall(function()
					TeleportService:TeleportToPlaceInstance(game.PlaceId, bestServerId, player)
				end)
			else
				pcall(function()
					TeleportService:Teleport(game.PlaceId, player)
				end)
			end
		else
			pcall(function()
				TeleportService:Teleport(game.PlaceId, player)
			end)
		end
	end)
end)

toggleButton.MouseButton1Click:Connect(function()
	if fishing then
		fishing = false
		restoreGetMouseHook()
		updateToggleButton()
		setStatus("Stopped", Color3.fromRGB(255, 80, 80))
		return
	end
	startFishing()
end)

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q and fishing then
		fishing = false
		restoreGetMouseHook()
		updateToggleButton()
		setStatus("Stopped", Color3.fromRGB(255, 80, 80))
	end
end))

track(player.Idled:Connect(function()
	VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	task.wait(1)
	VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end))

track(RunService.Heartbeat:Connect(function()
	if hopping or not proximityEnabled then
		return
	end
	local other, dist = nearestPlayer()
	if not other then
		nearLabel.Text = "Nearest: none"
		nearLabel.TextColor3 = Color3.fromRGB(140, 180, 140)
		return
	end
	nearLabel.Text = string.format("Nearest: %s  (%.0f)", other.Name, dist)
	if dist <= rangeStuds then
		nearLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		task.spawn(hopAway, "Menu hop — " .. other.Name)
	else
		nearLabel.TextColor3 = Color3.fromRGB(200, 200, 120)
	end
end))

local function resumeAfterHop()
	setStatus("Resuming after hop...", Color3.fromRGB(200, 200, 100))
	clickPlayIfNeeded()
	task.wait(0.4)
	clickPlayIfNeeded()
	local char = waitForLiveCharacter(30)
	if not char then
		setStatus("Waiting for character...", Color3.fromRGB(255, 180, 80))
		char = waitForLiveCharacter(20)
	end
	if getgenv().GrumpyFishingCaught then
		totalCaught = tonumber(getgenv().GrumpyFishingCaught) or totalCaught
		totalLabel.Text = "Total Caught: " .. totalCaught
	end
	startFishing()
end

if getgenv().GrumpyFishingResume then
	getgenv().GrumpyFishingResume = false
	proximityEnabled = getgenv().GrumpyFishingProximity ~= false
	updateProximityButton()
	task.delay(1.2, resumeAfterHop)
end

print("[Grumpy Fishing] Loaded (menu hop + auto-execute)")
