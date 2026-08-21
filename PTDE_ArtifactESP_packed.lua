-- PTDE Artifact ESP (standalone)
-- End = toggle ESP. AutoExecute writes to executor autoexec folder (IY-style).
-- Off fully disconnects and destroys drawings so nothing runs in the background.

if getgenv and getgenv().PTDEArtESPLoaded then
	return
end
if getgenv then
	getgenv().PTDEArtESPLoaded = true
end

local TOGGLE_KEY = Enum.KeyCode.End
local SCRIPT_URL = "https://raw.githubusercontent.com/KScroom/universal-duels/master/PTDE_ArtifactESP_packed.lua"
local CFG_FILE = "PTDEArtESP.cfg"
local AUTOEXEC_NAME = "PTDEArtESP.lua"

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local COLORS = {
	mythic = Color3.fromRGB(255, 0, 80),
	artifact = Color3.fromRGB(160, 100, 160),
	event = Color3.fromRGB(0, 255, 0),
	common = Color3.fromRGB(189, 97, 29),
	rare = Color3.fromRGB(60, 150, 150),
	none = Color3.fromRGB(40, 40, 40),
}

local SHOW = { mythic = true, artifact = true, event = true }

local NAME_TIER = {
	["Rift Gem"] = "mythic",
	["Mysterious Artifact"] = "mythic",
	["Azael Horn"] = "mythic",
	["Phoenix Flower"] = "mythic",
	["Amulet of the White King"] = "artifact",
	["Lannis Amulet"] = "artifact",
	["Lannis's Amulet"] = "artifact",
	["Lannis / White King"] = "artifact",
	["Phoenix Down"] = "artifact",
	["Night Stone"] = "artifact",
	["Nightstone"] = "artifact",
	["Howler Friend"] = "artifact",
	["Spider Cloak"] = "artifact",
	["Philosophers Stone"] = "artifact",
	["Fairfrozen"] = "artifact",
	["Eternal Ember"] = "artifact",
	["Ember"] = "artifact",
	["Astral Shard"] = "artifact",
	["Seraph Soul"] = "artifact",
	["Ornament"] = "event",
	["Present"] = "event",
	["Candy"] = "event",
	["Scary Mask"] = "event",
	["Pumpkin Centerpiece"] = "event",
	["Idol of the Forgotten"] = "common",
	["Old Ring"] = "common",
	["Ring"] = "common",
	["Goblet"] = "common",
	["Old Amulet"] = "common",
	["Amulet"] = "common",
	["Opal"] = "common",
	["Diamond"] = "rare",
	["Emerald"] = "rare",
	["Ruby"] = "rare",
	["Sapphire"] = "rare",
	["Ice Essence"] = "rare",
	["Bound Book"] = "rare",
	["Cursed Tag"] = "rare",
	["???"] = "rare",
}

local MESH_TRINKETS = {
	["5196782997"] = { "Old Ring", "common" },
	["5196776695"] = { "Ring", "common" },
	["5204003946"] = { "Goblet", "common" },
	["13116112"] = { "Goblet", "common" },
	["5196577540"] = { "Old Amulet", "common" },
	["5196551436"] = { "Amulet", "common" },
	["5197099782"] = { "Amulet of the White King", "artifact" },
	["5197111525"] = { "Amulet of the White King", "artifact" },
	["5196963069"] = { "Lannis Amulet", "artifact" },
	["5196975152"] = { "Lannis Amulet", "artifact" },
	["4103271893"] = { "Candy", "event" },
	["4027112893"] = { "Bound Book", "rare" },
	["2520762076"] = { "Howler Friend", "artifact" },
	["2877143560"] = { "Gem", "rare" },
	["7030942623"] = { "Astral Shard", "artifact" },
}

local ASSET_TRINKETS = {
	["2765613127"] = { "Idol of the Forgotten", "common" },
	["15583017412"] = { "Ornament", "event" },
	["15611175305"] = { "Present", "event" },
	["4117970107"] = { "Pumpkin Centerpiece", "event" },
}

local MASK_ASSETS = {
	["135210454467508"] = true,
	["130937394581985"] = true,
	["110718109649132"] = true,
	["78990214596147"] = true,
	["77406341502228"] = true,
	["118090092039844"] = true,
}

local enabled = false
local gen = 0
local objects = {}
local connections = {}
local queued = {}
local holder
local toastGui
local renderConn

pcall(function()
	for _, parent in ipairs({
		(gethui and gethui()) or player:WaitForChild("PlayerGui"),
		player:FindFirstChild("PlayerGui"),
		game:GetService("CoreGui"),
	}) do
		local old = parent and parent:FindFirstChild("PTDEArtESP")
		if old then
			old:Destroy()
		end
		local oldToast = parent and parent:FindFirstChild("PTDEArtESPToast")
		if oldToast then
			oldToast:Destroy()
		end
		local oldPanel = parent and parent:FindFirstChild("PTDEArtESPPanel")
		if oldPanel then
			oldPanel:Destroy()
		end
	end
end)

local function guiParent()
	local ok, hui = pcall(function()
		return gethui and gethui()
	end)
	if ok and hui then
		return hui
	end
	return player:WaitForChild("PlayerGui")
end

local AUTOEXEC_PATHS = {
	"autoexec/" .. AUTOEXEC_NAME,
	"Autoexec/" .. AUTOEXEC_NAME,
	"autoexecute/" .. AUTOEXEC_NAME,
}

local BOOT = [[
if getgenv and getgenv().PTDEArtESPLoaded then return end
loadstring(game:HttpGet("]] .. SCRIPT_URL .. [[?v=" .. tostring(tick())))()
]]

local function autoExecEnabled()
	local on = false
	pcall(function()
		if isfile and isfile(CFG_FILE) then
			on = readfile(CFG_FILE) == "1"
		end
	end)
	if not on then
		pcall(function()
			if isfile and isfile("autoexec/" .. AUTOEXEC_NAME) then
				on = true
			end
		end)
	end
	return on
end

local function setAutoExec(on)
	if on then
		pcall(function()
			if makefolder and isfolder and not isfolder("autoexec") then
				makefolder("autoexec")
			end
		end)
		pcall(function()
			if makefolder and isfolder and not isfolder("Autoexec") then
				makefolder("Autoexec")
			end
		end)
		local wrote = false
		for _, path in ipairs(AUTOEXEC_PATHS) do
			local ok = pcall(function()
				writefile(path, BOOT)
			end)
			if ok then
				wrote = true
			end
		end
		pcall(function()
			writefile(CFG_FILE, "1")
		end)
		return wrote
	end
	for _, path in ipairs(AUTOEXEC_PATHS) do
		pcall(function()
			if isfile and isfile(path) then
				delfile(path)
			end
		end)
	end
	pcall(function()
		writefile(CFG_FILE, "0")
	end)
	return true
end

local function notify(text, color)
	pcall(function()
		if toastGui then
			toastGui:Destroy()
			toastGui = nil
		end
		local sg = Instance.new("ScreenGui")
		sg.Name = "PTDEArtESPToast"
		sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		sg.Parent = guiParent()
		toastGui = sg
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0, 280, 0, 28)
		label.Position = UDim2.new(0.5, -140, 0, 18)
		label.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
		label.BackgroundTransparency = 0.15
		label.Text = text
		label.TextColor3 = color or Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.Parent = sg
		Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
		task.delay(1.6, function()
			if toastGui == sg then
				sg:Destroy()
				toastGui = nil
			end
		end)
	end)
	print("[PTDE Art ESP]", text)
end

local function track(conn)
	connections[#connections + 1] = conn
	return conn
end

local function digits(raw)
	return tostring(raw or ""):gsub("%%20", ""):gsub("%s+", ""):match("%d+")
end

local function meshDigits(inst)
	if not inst then
		return nil
	end
	local ok, mid = pcall(function()
		if inst:IsA("MeshPart") then
			local id = digits(inst.MeshId)
			if id then
				return id
			end
		end
		local sm = inst:FindFirstChildWhichIsA("SpecialMesh") or inst:FindFirstChild("Mesh")
		if sm then
			return digits(sm.MeshId)
		end
		return nil
	end)
	return ok and mid or nil
end

local function assetDigits(inst)
	if not inst or not gethiddenproperty then
		return nil
	end
	local ok, aid = pcall(function()
		return digits(gethiddenproperty(inst, "AssetId"))
	end)
	return ok and aid or nil
end

local function firstAttachmentPe(part)
	for _, ch in ipairs(part:GetChildren()) do
		if ch:IsA("Attachment") then
			local pe = ch:FindFirstChildWhichIsA("ParticleEmitter")
			if pe then
				return pe
			end
		end
	end
	return nil
end

local function isGoldSequence(cs)
	cs = tostring(cs)
	if string.match(cs, "0%.97") or string.match(cs, "0%.74") or string.match(cs, "0%.062") or string.match(cs, "0%.715") then
		return true
	end
	if string.find(cs, "1 1 0", 1, true) or string.find(cs, "1, 1, 0", 1, true) then
		return true
	end
	return false
end

local function isYellowPart(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	local c = part.Color
	return tostring(c) == "1, 1, 0" or (c.R > 0.92 and c.G > 0.92 and c.B < 0.2)
end

local function detectEmber(root)
	if not root then
		return false
	end
	local yellow = isYellowPart(root)
	local function scan(inst)
		if inst:IsA("ParticleEmitter") then
			local gold = isGoldSequence(inst.Color)
			if inst.Name == "OrbParticle" and (inst.Rate == 200 or gold) then
				return true
			end
			if gold and inst.Rate and inst.Rate >= 50 then
				return true
			end
		elseif inst:IsA("BasePart") and isYellowPart(inst) then
			yellow = true
		end
		return false
	end
	if scan(root) then
		return true
	end
	local ok, desc = pcall(function()
		return root:GetDescendants()
	end)
	if ok then
		for _, d in ipairs(desc) do
			if scan(d) then
				return true
			end
		end
	end
	if yellow then
		local pe = root:FindFirstChildWhichIsA("ParticleEmitter", true)
		if pe then
			return true
		end
	end
	return false
end

local function dinketRoot(object)
	local p = object
	while p and p.Parent and p.Parent.Name ~= "Dinkets" do
		p = p.Parent
	end
	if p and p.Parent and p.Parent.Name == "Dinkets" then
		return p
	end
	return object
end

local function identifyPart(v)
	if not v or not v:IsA("BasePart") then
		return nil
	end

	local mid = meshDigits(v)
	local aid = assetDigits(v)

	if aid and ASSET_TRINKETS[aid] then
		local e = ASSET_TRINKETS[aid]
		return e[1], e[2]
	end
	if aid and MASK_ASSETS[aid] then
		return "Scary Mask", "event"
	end

	if v:IsA("UnionOperation") then
		local col = tostring(v.Color)
		if col == "0.113725, 0.180392, 0.227451" then
			return "Nightstone", "artifact"
		end
		if col == "0.972549, 0.972549, 0.972549" and v.Material == Enum.Material.Neon then
			local s = v.Size
			if s.Y > 1.4 and s.X < 0.4 then
				for _, d in ipairs(v:GetDescendants()) do
					local m = meshDigits(d)
					if m == "5197099782" or m == "5197111525" then
						return "Amulet of the White King", "artifact"
					elseif m == "5196963069" or m == "5196975152" then
						return "Lannis Amulet", "artifact"
					end
				end
				return "Lannis / White King", "artifact"
			end
		end
	end

	if mid and MESH_TRINKETS[mid] then
		local e = MESH_TRINKETS[mid]
		if e[1] == "Gem" then
			return "Opal", "rare"
		end
		return e[1], e[2]
	end

	do
		local pe = v:FindFirstChild("ParticleEmitter")
		if pe and pe:IsA("ParticleEmitter") and pe.Rate == 5 then
			local cs = tostring(pe.Color)
			if string.find(cs, "0.298039", 1, true) and string.find(cs, "0.384314", 1, true) then
				return "Astral Shard", "artifact"
			end
		end
		if tostring(v.Color) == "0.105882, 0.164706, 0.207843" and v.Material == Enum.Material.Neon then
			if v:FindFirstChild("PointLight") or v:FindFirstChild("ParticleEmitter") then
				return "Astral Shard", "artifact"
			end
		end
	end

	local peAtt = firstAttachmentPe(v)
	if peAtt then
		if peAtt.Rate == 3 then
			return "Mysterious Artifact", "mythic"
		elseif peAtt.Rate == 5 then
			local third = tostring(peAtt.Color):split(" ")[3]
			if third == "0.8" then
				return "Phoenix Down", "artifact"
			end
			return "Azael Horn", "mythic"
		end
	end

	if detectEmber(v) then
		return "Eternal Ember", "artifact"
	end

	local pe = v:FindFirstChild("ParticleEmitter")
	if pe and pe:IsA("ParticleEmitter") and not v:FindFirstChild("Mesh") then
		if not string.match(tostring(pe.Color), "0 1 1 1 0 1 1 1 1 0") then
			return "Rift Gem", "mythic"
		end
	end

	if v:IsA("MeshPart") and v.BrickColor and v.BrickColor.Name == "Black" and mid and mid ~= "2520762076" then
		return "Nightstone", "artifact"
	end

	return nil
end

local function tryName(inst)
	if not inst or inst == Workspace then
		return nil
	end
	local n = inst.Name
	if NAME_TIER[n] then
		return n, NAME_TIER[n]
	end
	return nil
end

local function collectParts(root)
	local parts, seen = {}, {}
	local function add(p)
		if p and p:IsA("BasePart") and not seen[p] then
			seen[p] = true
			parts[#parts + 1] = p
		end
	end
	if not root then
		return parts
	end
	add(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			add(d)
		elseif d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("ManualWeld") then
			pcall(function()
				add(d.Part0)
				add(d.Part1)
			end)
		end
	end
	return parts
end

local function identify(object)
	local root = dinketRoot(object)
	if detectEmber(root) or detectEmber(object) then
		return "Eternal Ember", "artifact"
	end

	local n, t = tryName(object)
	if n then
		return n, t
	end
	n, t = tryName(object.Parent)
	if n then
		return n, t
	end

	if object.Name == "ClickPart" and object.Parent and object.Parent.Name ~= "Dinkets" then
		n, t = identifyPart(object.Parent)
		if n then
			return n, t
		end
		for _, d in ipairs(collectParts(object.Parent)) do
			n, t = identifyPart(d)
			if n then
				return n, t
			end
		end
	end

	n, t = identifyPart(object)
	if n then
		return n, t
	end

	for _, d in ipairs(collectParts(object)) do
		if d ~= object then
			n, t = identifyPart(d)
			if n then
				return n, t
			end
			n, t = tryName(d)
			if n then
				return n, t
			end
		end
	end

	local p = object.Parent
	while p and p ~= Workspace do
		n, t = tryName(p)
		if n then
			return n, t
		end
		if p:IsA("BasePart") then
			n, t = identifyPart(p)
			if n then
				return n, t
			end
		end
		if p.Name == "Dinkets" then
			break
		end
		p = p.Parent
	end

	return nil, nil
end

local function underDinkets(object)
	local p = object
	while p and p ~= Workspace do
		if p.Name == "Dinkets" then
			return true
		end
		p = p.Parent
	end
	return false
end

local function getClickPart(object)
	if not object then
		return nil
	end
	if object.Name == "ClickPart" and object:IsA("BasePart") then
		return object
	end
	local cp = object:FindFirstChild("ClickPart", true)
	if cp and cp:IsA("BasePart") then
		return cp
	end
	local p = object
	while p and p.Parent and p.Parent.Name ~= "Dinkets" do
		p = p.Parent
	end
	if p and p.Parent and p.Parent.Name == "Dinkets" then
		cp = p:FindFirstChild("ClickPart", true)
		if cp and cp:IsA("BasePart") then
			return cp
		end
		if p:IsA("BasePart") then
			return p
		end
	end
	if object:IsA("BasePart") then
		return object
	end
	return nil
end

local function classify(object)
	local name, tier = identify(object)
	if name and (name == "Scroll" or string.find(tostring(name), "Scroll of", 1, true)) then
		return nil
	end
	if name and NAME_TIER[name] then
		tier = NAME_TIER[name]
	end
	if not name or not tier then
		local parent = object.Parent
		if parent and parent ~= Workspace and parent.Name ~= "Dinkets" and parent.Name ~= "Part" and parent.Name ~= "ClickPart" and parent.Name ~= "" then
			name = parent.Name
			tier = NAME_TIER[name] or "event"
		else
			name = "Unknown Extra"
			tier = "event"
		end
	end
	if not SHOW[tier] then
		return nil
	end
	return name, tier
end

local function destroyEsp(esp)
	if not esp then
		return
	end
	pcall(function()
		if esp.gui then
			esp.gui:Destroy()
		end
	end)
	pcall(function()
		if esp.highlight then
			esp.highlight:Destroy()
		end
	end)
end

local function countShown()
	local n = 0
	for _ in pairs(objects) do
		n += 1
	end
	return n
end

local function addEsp(click, name, tier)
	if not enabled or not click or not click.Parent then
		return
	end
	local existing = objects[click]
	if existing then
		if existing.name ~= name then
			existing.name = name
			existing.tier = tier
			if existing.label then
				existing.label.TextColor3 = COLORS[tier]
			end
		end
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "PTDEArtESP"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.new(0, 220, 0, 36)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.Adornee = click
	gui.Parent = holder

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextStrokeTransparency = 0.3
	label.TextColor3 = COLORS[tier] or COLORS.event
	label.Text = name
	label.Parent = gui

	local hl
	pcall(function()
		hl = Instance.new("Highlight")
		hl.Name = "PTDEArtESP"
		hl.Adornee = click.Parent ~= Workspace and click.Parent.Name ~= "Dinkets" and click.Parent or click
		hl.FillTransparency = 0.7
		hl.OutlineTransparency = 0
		hl.FillColor = COLORS[tier] or COLORS.event
		hl.OutlineColor = COLORS[tier] or COLORS.event
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = holder
	end)

	objects[click] = {
		gui = gui,
		label = label,
		highlight = hl,
		name = name,
		tier = tier,
		part = click,
	}
end

local function apply(object)
	if not enabled or not object then
		return
	end
	if not underDinkets(object) then
		return
	end
	local click = getClickPart(object)
	if not click then
		return
	end
	local name, tier = classify(click)
	if not name then
		if objects[click] then
			destroyEsp(objects[click])
			objects[click] = nil
		end
		return
	end
	addEsp(click, name, tier)
end

local function queue(object)
	if not enabled or not object then
		return
	end
	local click = getClickPart(object) or object
	if queued[click] then
		return
	end
	queued[click] = true
	task.defer(function()
		task.wait(0.12)
		if enabled and click and click.Parent then
			apply(click)
		end
	end)
	task.delay(0.7, function()
		queued[click] = nil
		if enabled and click and click.Parent then
			apply(click)
		end
	end)
end

local function hookFolder(folder)
	if not folder then
		return
	end
	track(folder.ChildAdded:Connect(function(child)
		if enabled then
			queue(child)
		end
	end))
	track(folder.DescendantAdded:Connect(function(desc)
		if not enabled then
			return
		end
		if desc:IsA("BasePart") or desc:IsA("ClickDetector") or desc:IsA("Attachment") or desc:IsA("ParticleEmitter") then
			queue(desc)
		end
	end))
end

local function scanAll(myGen)
	local dinkets = Workspace:FindFirstChild("Dinkets")
	if not dinkets then
		return
	end
	local n = 0
	for _, root in ipairs(dinkets:GetChildren()) do
		if not enabled or myGen ~= gen then
			return
		end
		apply(root:FindFirstChild("ClickPart", true) or root)
		n += 1
		if n % 40 == 0 then
			task.wait()
		end
	end
end

local function startRender()
	if renderConn then
		return
	end
	local acc = 0
	renderConn = RunService.Heartbeat:Connect(function(dt)
		if not enabled then
			return
		end
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		camera = Workspace.CurrentCamera
		local camPos = camera and camera.CFrame.Position
		for part, esp in pairs(objects) do
			if not part.Parent then
				destroyEsp(esp)
				objects[part] = nil
			elseif esp.label and camPos then
				local dist = math.floor((camPos - part.Position).Magnitude)
				esp.label.Text = esp.name .. "\n[" .. dist .. "]"
			end
		end
	end)
end

local function stopAll()
	enabled = false
	gen += 1
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	for _, conn in ipairs(connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(connections)
	table.clear(queued)
	for _, esp in pairs(objects) do
		destroyEsp(esp)
	end
	table.clear(objects)
	if holder then
		holder:Destroy()
		holder = nil
	end
end

local function startAll()
	stopAll()
	enabled = true
	gen += 1
	local myGen = gen

	holder = Instance.new("Folder")
	holder.Name = "PTDEArtESP"
	holder.Parent = guiParent()

	notify("Loading artifact ESP...", Color3.fromRGB(255, 220, 80))
	hookFolder(Workspace:FindFirstChild("Dinkets"))
	track(Workspace.ChildAdded:Connect(function(obj)
		if obj.Name == "Dinkets" then
			hookFolder(obj)
			task.spawn(scanAll, myGen)
		end
	end))
	startRender()
	task.spawn(function()
		scanAll(myGen)
		if enabled and myGen == gen then
			notify("Artifact ESP ON  (" .. countShown() .. ")", COLORS.mythic)
		end
	end)
end

local function toggle()
	if enabled then
		stopAll()
		notify("Artifact ESP OFF", Color3.fromRGB(180, 180, 180))
	else
		startAll()
	end
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end
	if input.KeyCode == TOGGLE_KEY then
		toggle()
	end
end)

pcall(function()
	for _, parent in ipairs({ guiParent(), player:FindFirstChild("PlayerGui"), game:GetService("CoreGui") }) do
		local old = parent and parent:FindFirstChild("PTDEArtESPPanel")
		if old then
			old:Destroy()
		end
	end
end)

local panelGui = Instance.new("ScreenGui")
panelGui.Name = "PTDEArtESPPanel"
panelGui.ResetOnSpawn = false
panelGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
panelGui.Parent = guiParent()

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 210, 0, 92)
panel.Position = UDim2.new(1, -230, 0, 80)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
panel.BorderSizePixel = 0
panel.Parent = panelGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local ps = Instance.new("UIStroke", panel)
ps.Color = Color3.fromRGB(160, 80, 180)
ps.Thickness = 1.5
ps.Transparency = 0.3

local pTitle = Instance.new("TextLabel")
pTitle.Size = UDim2.new(1, -12, 0, 22)
pTitle.Position = UDim2.new(0, 8, 0, 6)
pTitle.BackgroundTransparency = 1
pTitle.Text = "Artifact ESP"
pTitle.Font = Enum.Font.GothamBold
pTitle.TextSize = 13
pTitle.TextColor3 = Color3.new(1, 1, 1)
pTitle.TextXAlignment = Enum.TextXAlignment.Left
pTitle.Parent = panel

local pHint = Instance.new("TextLabel")
pHint.Size = UDim2.new(1, -12, 0, 16)
pHint.Position = UDim2.new(0, 8, 0, 28)
pHint.BackgroundTransparency = 1
pHint.Text = "END toggles ESP"
pHint.Font = Enum.Font.Gotham
pHint.TextSize = 11
pHint.TextColor3 = Color3.fromRGB(160, 160, 170)
pHint.TextXAlignment = Enum.TextXAlignment.Left
pHint.Parent = panel

local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -16, 0, 30)
autoBtn.Position = UDim2.new(0, 8, 0, 50)
autoBtn.BorderSizePixel = 0
autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 12
autoBtn.TextColor3 = Color3.new(1, 1, 1)
autoBtn.Parent = panel
Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 6)

local autoOn = autoExecEnabled()

local function paintAuto()
	if autoOn then
		autoBtn.Text = "AutoExecute: ON"
		autoBtn.BackgroundColor3 = Color3.fromRGB(120, 50, 140)
	else
		autoBtn.Text = "AutoExecute: OFF"
		autoBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	end
end

paintAuto()

autoBtn.MouseButton1Click:Connect(function()
	if not writefile then
		notify("Executor has no writefile", Color3.fromRGB(255, 120, 80))
		return
	end
	autoOn = not autoOn
	local ok = setAutoExec(autoOn)
	if autoOn and not ok then
		autoOn = false
		setAutoExec(false)
		notify("Could not write autoexec folder", Color3.fromRGB(255, 120, 80))
	elseif autoOn then
		notify("AutoExecute ON — runs on inject", Color3.fromRGB(180, 120, 220))
	else
		notify("AutoExecute OFF", Color3.fromRGB(180, 180, 180))
	end
	paintAuto()
end)

notify("Artifact ESP loaded  —  press END", Color3.fromRGB(160, 200, 255))
