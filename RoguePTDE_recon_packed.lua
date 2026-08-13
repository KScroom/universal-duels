-- PTDE structure recon — run after you're in-game with a character
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game.Workspace
local req = (syn and syn.request) or (http and http.request) or http_request or request
local function log(msg)
	msg = tostring(msg)
	print("[PTDE-RECON]", msg)
	pcall(function()
		if not req then return end
		req({
			Url = "http://127.0.0.1:3000/log",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({ level = "info", message = msg }),
		})
	end)
end
local function kids(o, n)
	n = n or 40
	if not o then return "nil" end
	local t, c = {}, 0
	for _, x in ipairs(o:GetChildren()) do
		c += 1
		if c <= n then table.insert(t, x.ClassName .. ":" .. x.Name) end
	end
	if c > n then table.insert(t, "...+" .. (c - n)) end
	return table.concat(t, ", ")
end

local lp = Players.LocalPlayer
log("PlaceId=" .. game.PlaceId .. " Name=" .. tostring(game.Name))
log("WS=" .. kids(WS, 60))
log("Live=" .. tostring(WS:FindFirstChild("Live") ~= nil) .. " AreaMarkers=" .. tostring(WS:FindFirstChild("AreaMarkers") ~= nil))
log("RS=" .. kids(RS, 60))
local info, requests = RS:FindFirstChild("Info"), RS:FindFirstChild("Requests")
log("Info=" .. kids(info, 40))
log("Requests=" .. kids(requests, 80))
local char = lp.Character
log("CharParent=" .. tostring(char and char.Parent and char.Parent.Name))
log("Char=" .. kids(char, 50))
local ch = char and char:FindFirstChild("CharacterHandler")
log("CH=" .. kids(ch, 40))
log("Remotes=" .. kids(ch and ch:FindFirstChild("Remotes"), 80))
log("Backpack=" .. kids(lp:FindFirstChild("Backpack"), 40))
log("PlayerGui=" .. kids(lp:FindFirstChild("PlayerGui"), 40))
log("DONE")
pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "PTDE recon",
		Text = "Printed PlaceId " .. tostring(game.PlaceId) .. " — check F9",
		Duration = 6,
	})
end)
