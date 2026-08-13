-- Rogue PTDE bootloader w/ on-screen status
local function uiParent()
	local ok, h = pcall(function()
		return gethui and gethui()
	end)
	if ok and h then return h end
	return game:GetService("CoreGui")
end
local gui = Instance.new("ScreenGui")
gui.Name = "PTDE_BootStatus"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.IgnoreGuiInset = true
pcall(function()
	if syn and syn.protect_gui then syn.protect_gui(gui) end
end)
gui.Parent = uiParent()
local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 40)
label.Position = UDim2.new(0, 0, 0, 40)
label.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
label.BackgroundTransparency = 0.25
label.TextColor3 = Color3.fromRGB(255, 80, 80)
label.Font = Enum.Font.GothamBold
label.TextSize = 18
label.Text = "[PTDE] Booting..."
label.Parent = gui
local function status(t)
	print("[PTDE]", t)
	label.Text = "[PTDE] " .. tostring(t)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "PTDE",
			Text = tostring(t):sub(1, 80),
			Duration = 4,
		})
	end)
end

status("Downloading script...")
local URL = "https://raw.githubusercontent.com/KScroom/universal-duels/master/RoguePTDE_packed.lua?v=ptde5"
local req = (syn and syn.request) or (http and http.request) or http_request or request
local function download(url)
	if req then
		local ok, res = pcall(req, { Url = url, Method = "GET", Headers = { ["Cache-Control"] = "no-cache" } })
		if ok and type(res) == "table" then
			local body = res.Body or res.body
			local code = res.StatusCode or res.statusCode or 0
			status("HTTP " .. tostring(code) .. " bytes=" .. tostring(body and #body or 0))
			if type(body) == "string" and #body > 10000 then
				return body
			end
		else
			status("request failed, HttpGet fallback")
		end
	end
	return game:HttpGet(url, true)
end

local okAll, errAll = pcall(function()
	local src = download(URL)
	assert(type(src) == "string" and #src > 10000, "bad download size " .. tostring(src and #src))
	status("Compiling " .. tostring(#src) .. " chars...")
	local fn, err = loadstring(src)
	assert(fn, tostring(err))
	status("Executing...")
	fn()
	status("Main returned - check menu / RightShift")
end)
if not okAll then
	status("ERROR: " .. tostring(errAll))
	label.TextColor3 = Color3.fromRGB(255, 220, 50)
else
	task.delay(10, function()
		pcall(function() gui:Destroy() end)
	end)
end
