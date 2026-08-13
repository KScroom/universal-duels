-- PTDE hello test — must show a red panel if UI works
print("[PTDE-HELLO] start")
local parent = (gethui and gethui()) or game:GetService("CoreGui")
local gui = Instance.new("ScreenGui")
gui.Name = "PTDE_Hello"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Parent = parent
local f = Instance.new("Frame")
f.Size = UDim2.fromOffset(420, 120)
f.Position = UDim2.new(0.5, -210, 0.2, 0)
f.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
f.Parent = gui
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
local t = Instance.new("TextLabel")
t.BackgroundTransparency = 1
t.Size = UDim2.fromScale(1, 1)
t.Font = Enum.Font.GothamBold
t.TextSize = 22
t.TextColor3 = Color3.new(1, 1, 1)
t.Text = "PTDE HELLO OK\nPlaceId=" .. tostring(game.PlaceId) .. "\nIf you see this, UI works"
t.Parent = f
pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "PTDE HELLO",
		Text = "UI works — PlaceId " .. tostring(game.PlaceId),
		Duration = 8,
	})
end)
print("[PTDE-HELLO] shown PlaceId=", game.PlaceId)
